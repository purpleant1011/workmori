#!/usr/bin/env ruby
# verify_todo8.rb — todo #8: 채널 어댑터 (Instagram/Naver/Mastodon mock) 12 검증
require "json"
$LOAD_PATH.unshift(File.expand_path("../config", __dir__))

results = []
def check(label, ok, detail = "")
  status = ok ? "✅" : "❌"
  puts "  [#{status}] #{label} #{detail}"
  $stdout.flush
  ok
end

puts "=== todo #8 verify ==="

# 1. Adapter factory
puts "[1] Channels::Adapter factory 분기"
acct = Account.first
ch_ig = acct.channel_connections.find_by(kind: "instagram")
ch_masto = acct.channel_connections.find_by(kind: "mastodon")
ch_naver = acct.channel_connections.find_by(kind: "naver_place")
ch_kakao = acct.channel_connections.find_or_create_by!(kind: "kakao_channel", account: acct) do |c|
  c.handle = "kakao_1"
  c.connected_by_kind = "owner"
  c.connected_by_user_id = User.first.id
end
ch_email = acct.channel_connections.find_or_create_by!(kind: "email", account: acct) do |c|
  c.handle = "support@myshop.kr"
  c.connected_by_kind = "owner"
  c.connected_by_user_id = User.first.id
end
[ch_ig, ch_masto, ch_naver, ch_kakao, ch_email].compact.each do |c|
  c.update!(status: "active")
end

a_ig   = Channels::Adapter.for("instagram")
a_na   = Channels::Adapter.for("naver_place")
a_mas  = Channels::Adapter.for("mastodon")
a_kak  = Channels::Adapter.for("kakao_channel")
a_em   = Channels::Adapter.for("email")
a_gen  = Channels::Adapter.for("threads")
results << check("Instagram adapter class",    a_ig.is_a?(Channels::InstagramAdapter))
results << check("Naver adapter class",        a_na.is_a?(Channels::NaverAdapter))
results << check("Mastodon adapter class",     a_mas.is_a?(Channels::MastodonAdapter))
results << check("Kakao adapter class",        a_kak.is_a?(Channels::KakaoAdapter))
results << check("Email adapter class",        a_em.is_a?(Channels::EmailAdapter))
results << check("Generic fallback for threads", a_gen.is_a?(Channels::GenericAdapter))

# 2. Mock publish — Instagram
puts "[2] Instagram publish (2200자 제한)"
content = acct.content_items.where(state: "generated").first || acct.content_items.create!(
  title: "여름 신제품 출시",
  body: "신제품 출시 안내입니다. 7월 한정 20% 할인!",
  caption: "여름 한정 20% 할인!",
  state: "generated",
  safety_state: "passed",
  scheduled_at: 1.hour.from_now,
  account: acct,
  ai_employee: acct.ai_employees.first
)
short_body = "짧은 테스트 본문입니다."
r1 = Channels::Publisher.call(channel: ch_ig, content_item: content, idempotency_key: "verify-ig-#{SecureRandom.hex(4)}")
r1_ok = r1.ok
results << check("Instagram publish ok",       r1_ok, "(pub_id=#{r1.publication&.id})")
# external URL 확인은 PublicationAttempt.result_payload로
ext_url = r1.publication&.response_payload.is_a?(Hash) ? r1.publication.response_payload["external_url"] : nil
results << check("Instagram external_url 형식", ext_url.to_s.start_with?("https://instagram.com/"))

# 3. Instagram 길이 제한
puts "[3] Instagram 2200자 초과 거부"
long = acct.content_items.create!(
  title: "긴 글", body: "가" * 2500, caption: "테스트",
  state: "generated", safety_state: "passed", account: acct, ai_employee: acct.ai_employees.first
)
r1b = Channels::Publisher.call(channel: ch_ig, content_item: long, idempotency_key: "verify-ig-long-#{SecureRandom.hex(4)}")
results << check("Instagram 2200자 초과 거부",  !r1b.ok, "(reason=#{r1b.error})")
long.destroy

# 4. Mastodon publish
puts "[4] Mastodon publish (500자 제한)"
r2 = Channels::Publisher.call(channel: ch_masto, content_item: content, idempotency_key: "verify-mas-#{SecureRandom.hex(4)}")
results << check("Mastodon publish ok",        r2.ok, "(pub_id=#{r2.publication&.id})")

# 5. Naver publish
puts "[5] Naver publish"
r3 = Channels::Publisher.call(channel: ch_naver, content_item: content, idempotency_key: "verify-nav-#{SecureRandom.hex(4)}")
results << check("Naver publish ok",           r3.ok, "(pub_id=#{r3.publication&.id})")

# 6. Idempotency
puts "[6] Idempotency key 중복 차단"
key = "verify-idem-#{SecureRandom.hex(8)}"
r4a = Channels::Publisher.call(channel: ch_ig, content_item: content, idempotency_key: key)
r4b = Channels::Publisher.call(channel: ch_ig, content_item: content, idempotency_key: key)
results << check("동일 key → 첫 번째 OK",       r4a.ok)
results << check("동일 key → 두 번째 차단(in_flight 중복시 false 또는 동일 외부 id)", !r4b.ok || r4a.publication&.external_id == r4b.publication&.external_id)

# 7. PublicationAttempt & DeliveryLog & AuditEvent
puts "[7] PublicationAttempt/DeliveryLog/AuditEvent 카운트"
pub_count = PublicationAttempt.where(account: acct, state: "succeeded").count
log_count = DeliveryLog.where(account: acct, kind: "channel_publish").count
aud_count = AuditEvent.where(account: acct, action: "channel.published").count
results << check("PublicationAttempt >= 1",     pub_count >= 1, "(#{pub_count}건)")
results << check("DeliveryLog channel_publish >= 1", log_count >= 1, "(#{log_count}건)")
results << check("AuditEvent channel.published >= 1", aud_count >= 1, "(#{aud_count}건)")

# 8. ContentScheduler.enqueue_publisher
puts "[8] ContentScheduler.enqueue_publisher → PublisherJob"
begin
  cs_method = ContentScheduler.method(:enqueue_publisher)
  job_path = Rails.root.join("app/jobs/publisher_job.rb")
  results << check("ContentScheduler.enqueue_publisher 메서드 존재", cs_method.is_a?(Method), "")
  results << check("PublisherJob 파일 존재",                            job_path.exist?, job_path.to_s)
  results << check("PublisherJob < ApplicationJob",                   defined?(PublisherJob) && PublisherJob < ApplicationJob, "")
  results << check("PublisherJob.perform 정의됨",                     PublisherJob.instance_method(:perform).arity == 2, "")
rescue => e
  results << check("ContentScheduler.enqueue_publisher 메서드 존재", false, "(err=#{e.message[0..80]})")
end

# 9. PublisherJob.perform_now
puts "[9] PublisherJob.perform_now (인라인)"
before = DeliveryLog.where(account: acct, kind: "channel_publish").count
acct2 = Account.first
acct2.channel_connections.where(status: "active").each do |c|
  ci = c.account.content_items.where.not(state: "published").first || c.account.content_items.first
  PublisherJob.new.perform(ci.id, c.account_id)
end
after  = DeliveryLog.where(account: acct, kind: "channel_publish").count
delta  = after - before
results << check("PublisherJob.perform_now → DeliveryLog 증가", delta >= 1, "(delta=#{delta})")

# 10. Adapter.verify → active 채널 검증
puts "[10] Channels::Adapter.verify"
v_ig = Channels::Adapter.verify(channel: ch_ig)
v_kakao = Channels::Adapter.verify(channel: ch_kakao)
results << check("Instagram verify ok",         v_ig.ok)
results << check("Kakao verify ok",            v_kakao.ok)

# 11. Kinds list (9종)
puts "[11] KINDS 9종"
expected = %w[discord instagram threads blog naver_place daangn kakao_channel email mastodon]
results << check("ChannelConnection::KINDS 9종", ChannelConnection::KINDS.sort == expected.sort, "(#{ChannelConnection::KINDS.size}종)")

# 12. Publisher.call → failed 시 DeliveryLog kind=publication 이지만 state=failed 시 fail audit
puts "[12] Publisher failed path"
ch_email.update!(handle: "broken_no_at")
r5 = Channels::Publisher.call(channel: ch_email, content_item: content, idempotency_key: "verify-fail-#{SecureRandom.hex(4)}")
results << check("Email '@' 없는 핸들 → 거부",  !r5.ok)
ch_email.update!(handle: "support@myshop.kr")
failed_aud = AuditEvent.where(account: acct, action: "channel.publish.failed").count
results << check("AuditEvent channel.publish.failed 카운트", failed_aud >= 1, "(#{failed_aud}건)")

# === 결과 집계 ===
puts "\n=== 결과 ==="
passed = results.count(true)
failed = results.count(false)
puts "PASS: #{passed} / #{results.size}"
puts "FAIL: #{failed}"
puts failed == 0 ? "🎉 todo #8 ALL PASS" : "⚠️  todo #8 일부 실패"
exit(failed == 0 ? 0 : 1)
