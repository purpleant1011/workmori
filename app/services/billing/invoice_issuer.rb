# Billing::InvoiceIssuer — 청구 발행 → 결제 대기 상태로 전환
class Billing::InvoiceIssuer
  Result = Struct.new(:ok, :invoice, :payment, :error, keyword_init: true)

  def self.call(account:, subscription: nil, plan: nil, period_start: Date.current.beginning_of_month, period_end: Date.current.end_of_month)
    new(account: account, subscription: subscription, plan: plan, period_start: period_start, period_end: period_end).call
  end

  def initialize(account:, subscription: nil, plan: nil, period_start:, period_end:)
    @account = account
    @subscription = subscription
    @plan = plan || subscription&.plan
    @period_start = period_start
    @period_end = period_end
  end

  def call
    supply = @subscription&.monthly_price_krw || @plan&.monthly_price_krw || 300_000
    vat = (@subscription&.monthly_price_vat_krw || @plan&.monthly_price_vat_krw) || (supply * 0.1).round
    total = supply + vat
    number = "INV-#{@period_start.strftime('%Y%m')}-#{@account.id.to_s.rjust(4, '0')}-#{SecureRandom.hex(2).upcase}"

    invoice = Invoice.create!(
      account: @account,
      contract_term: @subscription&.contract_term,
      invoice_number: number,
      billing_period_start: @period_start,
      billing_period_end: @period_end,
      supply_amount_krw: supply,
      vat_amount_krw: vat,
      total_amount_krw: total,
      discount_amount_krw: 0,
      final_amount_krw: total,
      state: "issued",
      issued_on: Date.current,
      due_on: Date.current + 7
    )

    Result.new(ok: true, invoice: invoice)
  rescue => e
    Result.new(ok: false, error: e.message)
  end
end