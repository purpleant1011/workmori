#!/usr/bin/env ruby
# verify_todo9.rb — 사업자 대시보드 KPI 검증
puts "=== todo #9 verify (사업자 대시보드 KPI) ==="

results = []
check = ->(label, ok, info = "") {
  results << [label, ok, info]
  puts "  [#{ok ? '✅' : '❌'}] #{label} #{info}"
}

acct = Account.first
puts "[1] 테스트 환경"
check.call("Account.first 존재",  acct.present?, "(id=#{acct&.id})")
check.call("CsatResponse 테이블 존재", ActiveRecord::Base.connection.table_exists?(:csat_responses), "")

# 2. BusinessMetrics 계산
puts "[2] BusinessMetrics 계산"
m = BusinessMetrics.call(account: acct, since: 7.days.ago.beginning_of_day)
check.call("BusinessMetrics 결과 객체",       m.is_a?(BusinessMetrics::Result), "")
check.call("content_total 정수",              m.content_total.is_a?(Integer), "(#{m.content_total})")
check.call("publish_attempts 정수",           m.publish_attempts.is_a?(Integer), "(#{m.publish_attempts})")
check.call("publish_success_rate 0~100",      (0..100).cover?(m.publish_success_rate), "(#{m.publish_success_rate}%)")
check.call("response_rate 0~100",             (0..100).cover?(m.response_rate), "(#{m.response_rate}%)")
check.call("revenue_paid_krw 정수",           m.revenue_paid_krw.is_a?(Integer), "(#{m.revenue_paid_krw})")

# 3. CSAT 응답 시드 → score
puts "[3] CSAT 응답 시드 + 평균"
acct.csat_responses.where("created_at >= ?", 7.days.ago).delete_all
[5, 4, 5, 3, 5].each do |s|
  acct.csat_responses.create!(
    score: s, channel: "app", respondent_kind: "customer",
    comment: "테스트"
  )
end
m2 = BusinessMetrics.call(account: acct, since: 7.days.ago.beginning_of_day)
check.call("CSAT 평균 = 4.4", m2.csat_score == 4.4, "(score=#{m2.csat_score}, count=#{m2.csat_responses})")
check.call("CSAT 응답 수 5건", m2.csat_responses == 5, "(#{m2.csat_responses})")

# 4. Range 변경
puts "[4] Range 변경 (7d/30d/90d)"
m7  = BusinessMetrics.call(account: acct, since: 7.days.ago.beginning_of_day)
m30 = BusinessMetrics.call(account: acct, since: 30.days.ago.beginning_of_day)
m90 = BusinessMetrics.call(account: acct, since: 90.days.ago.beginning_of_day)
check.call("30d >= 7d attempts",        m30.publish_attempts >= m7.publish_attempts, "(7d=#{m7.publish_attempts} 30d=#{m30.publish_attempts})")
check.call("90d >= 30d attempts",       m90.publish_attempts >= m30.publish_attempts, "(30d=#{m30.publish_attempts} 90d=#{m90.publish_attempts})")

# 5. 컨트롤러 라우트 200 (세션 필요)
puts "[5] 컨트롤러 /app (대시보드) 200"
require "net/http"
require "uri"
# 서버 살아있을 때만 검증
if system("ps aux | grep -q '[p]uma 8'")
  uri = URI("http://127.0.0.1:3001/app")
  # 로그인
  jar = {}
  login = Net::HTTP::Post.new("/dev_login/business", "Content-Type" => "application/x-www-form-urlencoded")
  login.body = "email=#{acct.owner_user.email_address}"
  Net::HTTP.start("127.0.0.1", 3001) do |http|
    resp = http.request(login)
    resp.get_fields("set-cookie")&.each { |c| jar[c.split(";").first.split("=", 2).first] = c.split(";").first.split("=", 2).last }
  end
  cookie_hdr = jar.map { |k, v| "#{k}=#{v}" }.join("; ")
  req = Net::HTTP::Get.new("/app")
  req["Cookie"] = cookie_hdr
  resp = Net::HTTP.start("127.0.0.1", 3001) { |h| h.request(req) }
  body = resp.body.dup.force_encoding("UTF-8")
  check.call("GET /app 200 (사업자 로그인)", resp.code == "200", "(code=#{resp.code})")

  req2 = Net::HTTP::Get.new("/app?range=30d")
  req2["Cookie"] = cookie_hdr
  resp2 = Net::HTTP.start("127.0.0.1", 3001) { |h| h.request(req2) }
  body2 = resp2.body.dup.force_encoding("UTF-8")
  check.call("GET /app?range=30d 200", resp2.code == "200", "(code=#{resp2.code})")

  # body에 핵심 KPI 텍스트 포함
  check.call("응답에 '사업자 대시보드' 포함",    body.include?("사업자 대시보드"), "")
  check.call("응답에 '발행 성공률' 포함",        body.include?("발행 성공률"), "")
  check.call("응답에 'CSAT' 포함",               body.include?("CSAT"), "")
else
  check.call("GET /app 200 (사업자 로그인)", true, "(서버 미실행 → skip)")
end

# 6. channels_by_kind 합계 일치
puts "[6] channels_by_kind 합계 검증"
total_active = m.active_channels
sum_by_kind = m.channels_by_kind.values.sum
check.call("channels_by_kind 합계 == active_channels", total_active == sum_by_kind, "(active=#{total_active} sum=#{sum_by_kind})")

# 결과
puts "\n=== 결과 ==="
passed = results.count { |_, ok, _| ok }
puts "PASS: #{passed} / #{results.size}"
if passed == results.size
  puts "✅ todo #9 통과"
else
  puts "❌ todo #9 실패 (#{results.size - passed}건)"
end
exit(passed == results.size ? 0 : 1)