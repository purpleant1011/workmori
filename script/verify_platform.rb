#!/usr/bin/env ruby
# Platform/* 라우트 일괄 200 OK 검증
# 사용법: bin/rails runner script/verify_platform.rb

require 'net/http'
require 'uri'

routes = [
  ["/platform", 200],
  ["/platform/login", 200],
  ["/platform/accounts", 302],  # 미로그인 → 리다이렉트
  ["/platform/accounts/new", 302],
  ["/platform/accounts/1", 302],
  ["/platform/accounts/1/edit", 302],
  ["/platform/audit_events", 302],
  ["/platform/audit_events/3", 302],
  ["/platform/billings", 302],
  ["/platform/contracts", 302],
  ["/platform/contracts/new", 302],
  ["/platform/contracts/1", 302],
  ["/platform/contracts/1/edit", 302],
  ["/platform/feature_flags", 302],
  ["/platform/feature_flags/new", 302],
  ["/platform/feature_flags/1", 302],
  ["/platform/feature_flags/1/edit", 302],
  ["/platform/incidents", 302],
  ["/platform/incidents/new", 302],
  ["/platform/incidents/1", 302],
  ["/platform/incidents/1/edit", 302],
  ["/platform/industries", 302],
  ["/platform/industries/new", 302],
  ["/platform/industries/1", 302],
  ["/platform/industries/1/edit", 302],
  ["/platform/industry_templates", 302],
  ["/platform/industry_templates/new", 302],
  ["/platform/industry_templates/1", 302],
  ["/platform/industry_templates/1/edit", 302],
  ["/platform/inquiries", 302],
  ["/platform/inquiries/new", 302],
  ["/platform/inquiries/1", 302],
  ["/platform/inquiries/1/edit", 302],
  ["/platform/magic_link/abc123", 404],  # 토큰 없음
  ["/platform/model_catalog_entries", 302],
  ["/platform/model_catalog_entries/new", 302],
  ["/platform/model_catalog_entries/1", 302],
  ["/platform/model_catalog_entries/1/edit", 302],
  ["/platform/plans", 302],
  ["/platform/plans/new", 302],
  ["/platform/plans/1", 302],
  ["/platform/plans/1/edit", 302],
  ["/platform/platform_staff", 302],
  ["/platform/platform_staff/1", 302],
  ["/platform/prompt_templates", 302],
  ["/platform/prompt_templates/new", 302],
  ["/platform/prompt_templates/1", 302],
  ["/platform/prompt_templates/1/edit", 302],
  ["/platform/reports", 302],
]

# 1) 미로그인 베이스라인
puts "===== Phase 1: unauthenticated ====="
pass1, fail1 = [], []
routes.each do |path, want|
  code = nil
  begin
    code = Net::HTTP.get_response(URI("http://127.0.0.1:3001#{path}")).code.to_i
  rescue => e
    code = "ERR: #{e.message[0,30]}"
  end
  ok = (want == :any) || code == want || (want == 302 && code == 302) || (want == 200 && code == 200) || (want == 404 && code == 404)
  line = "  #{ok ? "✓" : "✗"} #{path.ljust(48)} → #{code} (want #{want})"
  ok ? pass1 << line : (fail1 << line)
end
puts pass1.size, fail1.size
fail1.each { |l| puts l }
puts "---"

# 2) 플랫폼 로그인
login_uri = URI("http://127.0.0.1:3001/dev_login/platform")
http = Net::HTTP.new(login_uri.host, login_uri.port)
req = Net::HTTP::Post.new(login_uri.path)
req.set_form_data('email' => 'platform-admin@workmori.example')
res = http.request(req)
puts "Login: #{res.code} cookie=#{res['set-cookie']&.slice(0,60)}"
cookie = res['set-cookie']&.split(';')&.first

# 3) 로그인 후 라우트
puts "===== Phase 2: authenticated ====="
pass2, fail2 = [], []
routes.each do |path, _want|
  next if path == "/platform/login"
  next if path == "/platform/magic_link/abc123"  # 토큰 없음

  want = case path
         when "/platform" then 200
         when "/platform/accounts/1" then 200
         when "/platform/audit_events" then 200
         when "/platform/audit_events/3" then 200
         when "/platform/billings" then 200
         when "/platform/feature_flags" then 200
         when "/platform/incidents" then 200
         when "/platform/incidents/1" then 200
         when "/platform/inquiries" then 200
         when "/platform/industry_templates" then 200
         when "/platform/industries" then 200
         when "/platform/model_catalog_entries" then 200
         when "/platform/plans" then 200
         when "/platform/platform_staff" then 200
         when "/platform/platform_staff/1" then 200
         when "/platform/prompt_templates" then 200
         when "/platform/reports" then 200
         else 200
         end

  code = nil
  begin
    uri = URI("http://127.0.0.1:3001#{path}")
    r = Net::HTTP.get_response(uri, 'Cookie' => cookie)
    code = r.code.to_i
  rescue => e
    code = "ERR: #{e.message[0,30]}"
  end
  ok = code == want
  line = "  #{ok ? "✓" : "✗"} #{path.ljust(48)} → #{code} (want #{want})"
  ok ? pass2 << line : (fail2 << line)
end
puts "pass=#{pass2.size} fail=#{fail2.size}"
fail2.each { |l| puts l }
puts "---"
puts "TOTAL: phase1=#{pass1.size} pass / #{fail1.size} fail, phase2=#{pass2.size} pass / #{fail2.size} fail"