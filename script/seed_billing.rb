acct = Account.first || Account.create!(name: "워크모리 시뮬레이션 스튜디오", status: "active")
puts "account: #{acct.name} (id=#{acct.id})"

# 기존 plan 모두 지우지 말고 코드 upsert
plans_data = [
  { code: "starter", name: "Starter", description: "소규모 매장용 — 핵심 자동화 1개 + 월간 요약 리포트", monthly_price_krw: 99_000, monthly_price_vat_krw: 9_900, features: { automation_limit: 1, content_per_month: 30, channels: ["blog"], human_review: false } },
  { code: "growth", name: "Growth", description: "성장 중인 매장 — 자동화 3개 + 다채널 + 주간 리포트", monthly_price_krw: 199_000, monthly_price_vat_krw: 19_900, features: { automation_limit: 3, content_per_month: 100, channels: %w[blog thread daangn], human_review: false } },
  { code: "byirim_special", name: "바이름 특별 플랜", description: "바이름 브랜드 직계약 — 자동화 무제한 + 사업주 검수 + 전담 매니저. 보증금 500,000원 별도.", monthly_price_krw: 300_000, monthly_price_vat_krw: 30_000, features: { automation_limit: 999, content_per_month: 9999, channels: %w[blog thread daangn instagram naver], human_review: true, deposit_krw: 500_000, contract_manager: true } }
]

plans_data.each do |p|
  plan = Plan.find_or_initialize_by(code: p[:code])
  plan.name = p[:name]
  plan.description = p[:description]
  plan.monthly_price_krw = p[:monthly_price_krw]
  plan.monthly_price_vat_krw = p[:monthly_price_vat_krw]
  plan.features = p[:features]
  plan.active = true
  plan.save!
  puts "plan: #{plan.code} → #{plan.monthly_price_krw}원"
end

# 바이름 특별 계약 / 보증금 시드
ct = ContractTerm.find_or_initialize_by(contract_code: "BYIRIM-2026-001")
ct.account = acct
ct.status = "active"
ct.test_started_on = Date.current - 14
ct.test_ends_on = Date.current - 7
ct.official_service_started_on = Date.current
ct.deposit_amount_krw = 500_000
ct.save!
puts "contract: #{ct.contract_code}"

# 계약에 연결된 보증금
deposit = Deposit.find_or_initialize_by(contract_term: ct, account: acct)
deposit.amount_krw = 500_000
deposit.state = "received"
deposit.received_on = Date.current
deposit.save!
puts "deposit: #{deposit.amount_krw}원 (#{deposit.state})"

# 바이름 특별 플랜 구독
plan = Plan.find_by(code: "byirim_special")
acct = Account.includes(:subscriptions).first
sub = acct.subscriptions.first || acct.subscriptions.new
sub.plan = plan
sub.contract_term = ct
sub.started_on = Date.current
sub.current_period_start = Date.current
sub.current_period_end = Date.current + 30
sub.next_billing_on = Date.current + 30
sub.monthly_price_krw = plan.monthly_price_krw
sub.monthly_price_vat_krw = plan.monthly_price_vat_krw
sub.deposit_krw = 500_000
sub.state = "active"
sub.auto_renew = true
sub.save!
puts "subscription: #{sub.id} → #{plan.name} (#{sub.monthly_price_krw}원 + VAT)"

# 첫 청구 발행 (이번 달)
issuer = Billing::InvoiceIssuer.call(account: acct, subscription: sub, period_start: Date.current.beginning_of_month, period_end: Date.current.end_of_month)
if issuer.ok
  puts "invoice: #{issuer.invoice.invoice_number} #{issuer.invoice.final_amount_krw}원 (#{issuer.invoice.state})"
end

puts "=== billing seed complete ==="
