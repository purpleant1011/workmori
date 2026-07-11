#!/usr/bin/env ruby
# App/* N+1 / 콘솔 오류 점검
require 'net/http'
require 'uri'

routes = [
  ["/app", 200],
  ["/app/business_profile", 200],
  ["/app/business_profile/edit", 200],
  ["/app/products", 200],
  ["/app/products/new", 200],
  ["/app/products/1", 200],
  ["/app/services", 200],
  ["/app/services/new", 200],
  ["/app/services/1", 200],
  ["/app/faqs", 200],
  ["/app/faqs/new", 200],
  ["/app/faqs/1", 200],
  ["/app/knowledge", 200],
  ["/app/knowledge/sources/1", 200],
  ["/app/ai_employees", 200],
  ["/app/ai_employees/1", 200],
  ["/app/channels", 200],
  ["/app/channels/new", 200],
  ["/app/channels/1", 200],
  ["/app/channels/1/edit", 200],
  ["/app/content", 200],
  ["/app/content/items", 200],
  ["/app/content/items/2", 200],
  ["/app/analytics", 200],
  ["/app/conversations", 200],
  ["/app/conversations/1", 200],
  ["/app/reports", 200],
  ["/app/reports/show", 200],
  ["/app/reports/weekly/1", 200],
  ["/app/billing", 200],
  ["/app/billing/invoice/1", 200],
  ["/app/data_exports", 200],
  ["/app/data_exports/new", 200],
  ["/app/automations", 200],
  ["/app/automations/rules", 200],
  ["/app/automations/rules/new", 200],
  ["/app/automations/rules/14", 200],
  ["/app/automations/rules/14/edit", 200],
  ["/app/automations/executions", 200],
  ["/app/automations/executions/18", 200],
  ["/app/settings", 200],
  ["/app/termination", 200],
  ["/app/termination/new", 200],
  ["/app/termination/confirm", 200],
  ["/app/deletion_requests", 200],
  ["/app/deletion_requests/new", 200],
  ["/app/plans", 200],
  ["/app/referrals", 200],
  ["/app/delivery_logs", 200],
  ["/app/handoffs", 200],
  ["/app/handoffs/6", 200],
  ["/app/handoffs/6/edit", 200],
  ["/app/csat/new", 200],
]

# 사업자 로그인
login_uri = URI("http://127.0.0.1:3001/dev_login/business")
http = Net::HTTP.new(login_uri.host, login_uri.port)
req = Net::HTTP::Post.new(login_uri.path)
req.set_form_data('email' => 'owner@demo.example')
res = http.request(req)
cookie = res['set-cookie']&.split(';')&.first
puts "Login: #{res.code} cookie=#{cookie&.slice(0,40)}"

# 라우트 검증 + query count
puts "\n===== App/* 검증 ====="
pass, fail = [], []
queries = {}
routes.each do |path, want|
  # 로그 offset 측정 시작
  log_size_before = File.size("log/development.log")
  code = nil
  begin
    uri = URI("http://127.0.0.1:3001#{path}")
    r = Net::HTTP.get_response(uri, 'Cookie' => cookie)
    code = r.code.to_i
  rescue => e
    code = -1
  end
  sleep 0.3
  log = File.read("log/development.log")
  log_new = log[log_size_before..] || ""
  qcount = log_new.scan(/SELECT|UPDATE|INSERT|DELETE/).size
  queries[path] = qcount
  ok = code == want
  line = "  #{ok ? "✓" : "✗"} #{path.ljust(40)} → #{code} (queries: #{qcount})"
  ok ? pass << line : (fail << line)
end
puts "PASS=#{pass.size} FAIL=#{fail.size}"
fail.each { |l| puts l }

# N+1 의심 — 상위 10개
puts "\n===== Query count 상위 15개 (N+1 의심) ====="
queries.sort_by { |_, v| -v }.first(15).each do |p, q|
  puts "  #{q.to_s.rjust(3)}q  #{p}"
end

# 콘솔 에러 / 에러 패턴
puts "\n===== Log error scan ====="
errs = log.scan(/(?:Completed 5\d\d|ActiveModel::UnknownAttributeError|AbstractController::ActionNotFound|NoMethodError|undefined.*method|UnknownAttributeError|Unknown action|ActiveRecord::RecordInvalid|RuntimeError)/).uniq
puts "에러 패턴: #{errs.size}개"
errs.first(15).each { |e| puts "  - #{e}" }