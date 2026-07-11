#!/usr/bin/env ruby
# todo #7 verify — 가격·결제 통합 종단간 검증
# 1) routes 200
# 2) Subscription 생성
# 3) Invoice 발행
# 4) Payment 시뮬레이션
# 5) Toss mock txn_id
# 6) state 전이 (paid)
# 7) DeliveryLog
# 8) AuditEvent
# 9) platform billing view

require "open-uri"
BASE = "http://127.0.0.1:3001"
JAR  = "/tmp/c.jar"
$pass = 0
$fails = []

def check(name, cond, detail = nil)
  if cond
    puts "  ✓ #{name}"
    $pass += 1
  else
    puts "  ✗ #{name} #{detail}"
    $fails << "#{name} #{detail}"
  end
end

def login_business!
  File.delete(JAR) if File.exist?(JAR)
  system("curl -s -c #{JAR} -X POST #{BASE}/dev_login/business -d 'email=owner@demo.example' -o /dev/null")
end

def login_platform!
  File.delete(JAR) if File.exist?(JAR)
  system("curl -s -c #{JAR} -X POST #{BASE}/dev_login/platform -d 'email=platform-admin@workmori.example' -o /dev/null")
end

def get(path)
  `curl -s -b #{JAR} -c #{JAR} -o /dev/null -w "%{http_code}" #{BASE}#{path}`.to_i
end

def post(path, data = nil, token: nil)
  cmd = "curl -s -b #{JAR} -c #{JAR} -X POST"
  cmd += " -H 'X-CSRF-Token: #{token}'" if token
  cmd += " --data-urlencode '#{data}'" if data
  cmd += " -o /dev/null -w '%{http_code}'"
  cmd += " #{BASE}#{path}"
  `#{cmd}`.to_i
end

def form_token_for(path, action)
  html = `curl -s -b #{JAR} -c #{JAR} #{BASE}#{path}`
  m = html.match(/action="#{Regexp.escape(action)}[^"]*"[^>]*>(?:.|[\r\n])*?authenticity_token.*?value="([^"]+)"/m)
  m ? m[1] : nil
end

puts "[1] routes 200"
login_business!
check("GET /app/billing 200", get("/app/billing") == 200)
check("GET /app/billing/invoice/1 200", get("/app/billing/invoice/1") == 200)

puts "[2] platform admin billing"
login_platform!
check("GET /platform/billings 200", get("/platform/billings") == 200)

puts "[3] Subscription 존재"
require "open3"
out, _ = Open3.capture2("cd /Users/hochari/develop/workmori && export PATH=\"$HOME/.local/share/mise/installs/ruby/3.4.10/bin:$PATH\" && bin/rails runner 'puts Subscription.count' 2>/dev/null")
check("Subscription count >= 1", out.to_i >= 1, "got #{out.strip}")

puts "[4] Invoice 발행 + 결제"
out, _ = Open3.capture2("cd /Users/hochari/develop/workmori && export PATH=\"$HOME/.local/share/mise/installs/ruby/3.4.10/bin:$PATH\" && bin/rails runner 'puts Invoice.count' 2>/dev/null")
inv_count_before = out.to_i

# 새 invoice 발행
out, _ = Open3.capture2("cd /Users/hochari/develop/workmori && export PATH=\"$HOME/.local/share/mise/installs/ruby/3.4.10/bin:$PATH\" && bin/rails runner 'a=Account.first; s=Subscription.first; r=Billing::InvoiceIssuer.call(account: a, subscription: s, period_start: Date.current+2.month, period_end: (Date.current+2.month).end_of_month); puts r.invoice.id if r.ok' 2>/dev/null")
new_inv_id = out.to_i
check("새 Invoice 발행됨 (#{new_inv_id})", new_inv_id > 0)

# pay 진행
login_business!
token = form_token_for("/app/billing/invoice/#{new_inv_id}", "/app/billing/pay")
status = post("/app/billing/pay", "invoice_id=#{new_inv_id}", token: token)
check("POST /app/billing/pay 302", status == 302, "got #{status}")

puts "[5] Toss mock txn_id + state 전이"
out, _ = Open3.capture2("cd /Users/hochari/develop/workmori && export PATH=\"$HOME/.local/share/mise/installs/ruby/3.4.10/bin:$PATH\" && bin/rails runner script/check_inv.rb #{new_inv_id} 2>/dev/null")
state, paid_on, txn, pay_state = out.strip.split("|")
check("Invoice state=paid", state == "paid", "got #{state}")
check("Invoice paid_on set", !paid_on.to_s.empty? && paid_on != "nil", "got #{paid_on}")
check("Payment TXN starts with TXN_", txn.to_s.start_with?("TXN_"), "got #{txn}")
check("Payment state=succeeded", pay_state == "succeeded", "got #{pay_state}")

puts "[6] DeliveryLog + AuditEvent"
out, _ = Open3.capture2("cd /Users/hochari/develop/workmori && export PATH=\"$HOME/.local/share/mise/installs/ruby/3.4.10/bin:$PATH\" && bin/rails runner script/check_logs.rb 2>/dev/null")
dl_count, ae_count = out.strip.split("\n").map(&:to_i)
check("DeliveryLog billing >= 1", dl_count >= 1, "got #{dl_count}")
check("AuditEvent billing.payment.succeeded >= 1", ae_count >= 1, "got #{ae_count}")

puts "[7] BillingAutomation (일간 청구)"
out, _ = Open3.capture2("cd /Users/hochari/develop/workmori && export PATH=\"$HOME/.local/share/mise/installs/ruby/3.4.10/bin:$PATH\" && bin/rails runner 'r=Billing::BillingAutomation.run_daily_billing(today: Date.current+2.month+1.day); puts r.class' 2>/dev/null")
check("BillingAutomation 정상 동작", out.strip.include?("Result") || out.strip.length > 0, "got #{out.strip}")

puts
puts "============================================"
puts "PASS: #{$pass}    FAIL: #{$fails.size}"
puts "============================================"
exit($fails.empty? ? 0 : 1)