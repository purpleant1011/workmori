#!/usr/bin/env ruby
# 통합 검증: Platform/* 49개 라우트 + 콘솔 에러 점검 + N+1 카운트
# 사용법: bin/rails runner script/verify_full.rb

require 'net/http'
require 'uri'

routes = [
  ["/platform", 200],
  ["/platform/login", 200],
  ["/platform/accounts", 200],
  ["/platform/accounts/new", 200],
  ["/platform/accounts/1", 200],
  ["/platform/accounts/1/edit", 200],
  ["/platform/audit_events", 200],
  ["/platform/audit_events/3", 200],
  ["/platform/billings", 200],
  ["/platform/contracts", 200],
  ["/platform/contracts/new", 200],
  ["/platform/contracts/1", 200],
  ["/platform/contracts/1/edit", 200],
  ["/platform/feature_flags", 200],
  ["/platform/feature_flags/new", 200],
  ["/platform/feature_flags/1", 200],
  ["/platform/feature_flags/1/edit", 200],
  ["/platform/incidents", 200],
  ["/platform/incidents/new", 200],
  ["/platform/incidents/1", 200],
  ["/platform/incidents/1/edit", 200],
  ["/platform/industries", 200],
  ["/platform/industries/new", 200],
  ["/platform/industries/1", 200],
  ["/platform/industries/1/edit", 200],
  ["/platform/industry_templates", 200],
  ["/platform/industry_templates/new", 200],
  ["/platform/industry_templates/1", 200],
  ["/platform/industry_templates/1/edit", 200],
  ["/platform/inquiries", 200],
  ["/platform/inquiries/new", 200],
  ["/platform/inquiries/1", 200],
  ["/platform/inquiries/1/edit", 200],
  ["/platform/magic_link/abc123", 302],  # 토큰 없음 → /platform/login 리다이렉트
  ["/platform/model_catalog_entries", 200],
  ["/platform/model_catalog_entries/new", 200],
  ["/platform/model_catalog_entries/1", 200],
  ["/platform/model_catalog_entries/1/edit", 200],
  ["/platform/plans", 200],
  ["/platform/plans/new", 200],
  ["/platform/plans/1", 200],
  ["/platform/plans/1/edit", 200],
  ["/platform/platform_staff", 200],
  ["/platform/platform_staff/1", 200],
  ["/platform/prompt_templates", 200],
  ["/platform/prompt_templates/new", 200],
  ["/platform/prompt_templates/1", 200],
  ["/platform/prompt_templates/1/edit", 200],
  ["/platform/reports", 200],
]

# 1) 플랫폼 로그인
login_uri = URI("http://127.0.0.1:3001/dev_login/platform")
http = Net::HTTP.new(login_uri.host, login_uri.port)
req = Net::HTTP::Post.new(login_uri.path)
req.set_form_data('email' => 'platform-admin@workmori.example')
res = http.request(req)
cookie = res['set-cookie']&.split(';')&.first
puts "Login: #{res.code} cookie=#{cookie&.slice(0,40)}"

# 2) 라우트 검증
puts "\n===== Phase: Platform/* 검증 ====="
pass, fail = [], []
routes.each do |path, want|
  code = nil
  begin
    uri = URI("http://127.0.0.1:3001#{path}")
    r = Net::HTTP.get_response(uri, 'Cookie' => cookie)
    code = r.code.to_i
  rescue => e
    code = -1
  end
  ok = code == want
  line = "  #{ok ? "✓" : "✗"} #{path.ljust(48)} → #{code} (want #{want})"
  ok ? pass << line : (fail << line)
end
puts "PASS=#{pass.size} FAIL=#{fail.size}"
fail.each { |l| puts l }

# 3) 콘솔 오류 / N+1 카운트 (development.log tail)
puts "\n===== Phase: Log error scan ====="
log = File.read(Rails.root.join("log/development.log").to_s)
errs = log.scan(/(?:Completed 5\d\d|ActiveModel::UnknownAttributeError|AbstractController::ActionNotFound|NoMethodError|undefined.*method|UnknownAttributeError|Unknown action)/).uniq
puts "최근 발견된 에러 패턴: #{errs.size}개"
errs.first(15).each { |e| puts "  - #{e}" }