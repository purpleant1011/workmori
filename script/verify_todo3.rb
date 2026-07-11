puts "=== todo #3 검증 ==="

# 0. MagicLink 모델 + 라우트 점검
require "net/http"
routes = Rails.application.routes.routes.map { |r| { verb: r.verb, path: r.path.spec.to_s, name: r.name } }
ml_routes = routes.select { |r| r[:path].include?("magic_link") }
puts "MagicLink routes:"
ml_routes.each { |r| puts "  #{r[:verb]} #{r[:path]}  (name=#{r[:name]})" }

# 1. Safety::Policy 차단 시뮬레이션
acct = Account.first
ae = acct.ai_employees.first
puts "\n--- Safety::Policy.check! ---"
[safety_test1 = "100% 보장하는 시술로 부작용 0%.",
 "저희 매장에서 50% 할인 행사 합니다",
 "진짜 좋은 후기 정말 만족스러워요 (작성자가 임직원)",
 "예약 가능한 시간 알려주세요",
 "비밀번호가 뭔가요?"].each do |content|
  result = Safety::Policy.check!(content: content, account: acct, stage: "pre_publish", persist: true)
  puts "  content=#{content[0..30]}... → verdict=#{result.verdict}"
end
puts "SafetyLog count: #{SafetyLog.count}"

# 2. AiEmployee 메모리 helpers
puts "\n--- AiEmployee memory ---"
puts "before memory=#{ae.memory.inspect}"
ae.append_memory!(kind: "topics", value: "시술 예약 상담")
ae.append_memory!(kind: "topics", value: "피부 트러블 케어")
ae.append_memory!(kind: "style_examples", value: "~드림 / ~해드릴게요 / 부드럽고 공손한 톤")
ae.append_memory!(kind: "notes", value: "주말 예약 많음, 30분 단위 처리")
ae.save!
ae.reload
puts "after memory="
ae.memory.each { |k,v| puts "  #{k}: #{v.length} entries (sample: #{v.first&.[](0..40)})" }

# 3. MagicLink e2e — User 측
puts "\n--- UserMagicLink e2e (rails 내부) ---"
user = User.first
puts "user: id=#{user.id} email_address=#{user.email_address}"
link, raw = MagicLink.issue!(email: user.email_address, purpose: MagicLink::PURPOSE_USER_LOGIN, ip: "127.0.0.1")
puts "issued link: id=#{link.id} token_hash present=#{link.token_hash.present?}"
verified = MagicLink.verify_and_consume(raw, email: user.email_address, purpose: MagicLink::PURPOSE_USER_LOGIN)
puts "verify_and_consume returned: id=#{verified&.id} email=#{verified&.email}"
verified_again = MagicLink.verify_and_consume(raw, email: user.email_address, purpose: MagicLink::PURPOSE_USER_LOGIN)
puts "verify_again (재사용 시도): #{verified_again.inspect}"
puts "MagicLink total: #{MagicLink.count}, consumed: #{MagicLink.where.not(consumed_at: nil).count}"

# 4. Platform 측
puts "\n--- PlatformMagicLink e2e ---"
ps = PlatformStaff.first
puts "platform staff: id=#{ps.id} email_address=#{ps.email_address}"
link, raw = MagicLink.issue!(email: ps.email_address, purpose: MagicLink::PURPOSE_PLATFORM_LOGIN, ip: "127.0.0.1")
puts "issued link: id=#{link.id}"
verified = MagicLink.verify_and_consume(raw, email: ps.email_address, purpose: MagicLink::PURPOSE_PLATFORM_LOGIN)
puts "verify_and_consume returned: id=#{verified&.id} email=#{verified&.email}"

puts "\n=== todo #3 검증 완료 ==="
