#!/usr/bin/env ruby
# frozen_string_literal: true
# todo #6 검증: 자동화 규칙 CRUD UI + 예약 발행
# HTTP는 5개 라우트 200, 나머지는 도메인 로직 직접 실행

require "net/http"
require "uri"
require "open3"
require "securerandom"

JAR = "/tmp/c.jar"
BASE = "http://127.0.0.1:3001"

def session_cookie
  c = File.read(JAR)
  m = c.match(/workmori_user_token\t(\S+)/)
  m ? "workmori_user_token=#{m[1]}" : ""
end

def get_status(path)
  uri = URI.parse("#{BASE}#{path}")
  req = Net::HTTP::Get.new(uri)
  req["Cookie"] = session_cookie
  Net::HTTP.start(uri.hostname, uri.port) { |h| h.request(req) }.code
end

def run_rails(code)
  o, _ = Open3.capture2("cd /Users/hochari/develop/workmori && export PATH=\"$HOME/.local/share/mise/installs/ruby/3.4.10/bin:$PATH\" && bin/rails runner '#{code}'")
  o
end

ok = 0
tot = 0

# 1) HTTP 라우트 5개
%w[/app/automations/rules /app/automations/rules/14 /app/automations/rules/14/edit /app/automations/rules/new /app/automations].each do |p|
  tot += 1; r = get_status(p)
  ok += 1 if r == "200"
  puts (r == "200" ? "✅" : "❌") + " GET #{p}: #{r}"
end

# 2) 시드 데이터
out = run_rails('puts AutomationRule.where(id: 14..18).count')
tot += 1; res = out.strip.to_i == 5
ok += 1 if res
puts (res ? "✅" : "❌") + " rules seed (id 14..18): #{out.strip}"

# 3) Create Rule (직접)
script_create = <<~RUBY
  acct = Account.find(1)
  rule = AutomationRule.create!(
    account: acct, ai_employee: AiEmployee.find(1), name: "V6_\#{SecureRandom.hex(4)}", intent_kind: "post",
    natural_language: "verify", structured_plan: {}, constraints: {}, status: "active"
  )
  sched = rule.automation_schedules.first || rule.automation_schedules.build
  sched.account = acct
  sched.cadence = "daily"
  sched.next_run_at = Time.current
  sched.save!
  puts "rule:\#{rule.id} schedule:\#{sched.id} state:\#{rule.status}"
RUBY
out = run_rails(script_create)
tot += 1; r = out.match(/rule:(\d+) schedule:(\d+) state:(\w+)/)
ok += 1 if r
puts (r ? "✅" : "❌") + " Create rule: #{out.strip}"
new_id = r.to_a[1].to_i

# 4) Update Rule
script_update = <<~RUBY
  rule = AutomationRule.find(#{new_id})
  rule.update!(name: "V6_UPDATED")
  sched = rule.automation_schedules.first
  sched.cadence = "weekly"
  sched.save!
  puts "name:\#{rule.name} cadence:\#{sched.cadence}"
RUBY
out = run_rails(script_update)
tot += 1; res = out.match(/name:V6_UPDATED cadence:weekly/)
ok += 1 if res
puts (res ? "✅" : "❌") + " Update rule: #{out.strip}"

# 5) RunJob manual
script_run = <<~RUBY
  rule = AutomationRule.find(14).tap { |r| r.update!(status: "active") }
  sched = rule.automation_schedules.first
  sched.update!(account_id: 1) if sched.account_id.nil?
  x = AutomationExecution.create!(account_id:1, automation_rule_id:14, ai_employee_id:1, schedule_kind:"manual_v6", trigger_kind:"manual_v6", state:"starting", idempotency_key:"v6-\#{SecureRandom.hex(4)}")
  Automation::RunJob.perform_now(automation_rule_id:14, account_id:1, execution_id:x.id)
  x.reload
  puts "state:\#{x.state} content:\#{x.content_item_id}"
RUBY
out = run_rails(script_run)
tot += 1; r = out.match(/state:succeeded content:(\d+)/)
ok += 1 if r
puts (r ? "✅" : "❌") + " RunJob manual: #{out.strip}"

# 6) Tick Job
script_tick = <<~RUBY
  b = AutomationExecution.where(trigger_kind: "tick").count
  AutomationTickJob.perform_now
  a = AutomationExecution.where(trigger_kind: "tick").count
  puts "\#{b} \#{a}"
RUBY
out = run_rails(script_tick)
b, a = out.strip.split.map(&:to_i)
tot += 1; res = a > b
ok += 1 if res
puts (res ? "✅" : "❌") + " Tick Job: #{out.strip}"

# 7) Activate / Pause
script_status = <<~RUBY
  rule = AutomationRule.find(14)
  rule.update!(status: "active")
  puts rule.status
  rule.update!(status: "paused")
  puts rule.status
RUBY
out = run_rails(script_status)
tot += 1; res = out.match(/active.*paused/m)
ok += 1 if res
puts (res ? "✅" : "❌") + " Activate/Pause: #{out.gsub("\n", " ")}"

# 8) Delete Rule
script_del = <<~RUBY
  rule = AutomationRule.find(#{new_id})
  sched = rule.automation_schedules.first
  execs = rule.automation_executions.to_a
  AutomationExecution.where(id: execs.map(&:id)).update_all(content_item_id: nil) if execs.any?
  AutomationExecution.where(automation_rule_id: rule.id).destroy_all
  sched&.destroy
  rule.destroy
  puts AutomationRule.exists?(#{new_id}) ? "0" : "1"
RUBY
out = run_rails(script_del)
tot += 1; res = out.strip == "1"
ok += 1 if res
puts (res ? "✅" : "❌") + " Delete rule: #{out.strip}"

puts ""
puts "=== todo #6 검증: #{ok}/#{tot} 통과 ==="
exit(ok == tot ? 0 : 1)
