# Billing::PaymentCollector — 청구 결제 → Payment + Invoice paid 전이
class Billing::PaymentCollector
  Result = Struct.new(:ok, :payment, :invoice, :error, keyword_init: true)

  def self.call(invoice:, method: "toss_mock")
    new(invoice: invoice, method: method).call
  end

  def initialize(invoice:, method:)
    @invoice = invoice
    @method = method
  end

  def call
    return Result.new(ok: false, error: "이미 결제됨") if @invoice.state == "paid"

    res = Billing::TossMock.simulate_payment_now!(
      amount_krw: @invoice.final_amount_krw,
      account_id: @invoice.account_id,
      invoice_number: @invoice.invoice_number
    )
    return Result.new(ok: false, error: "결제 승인 실패") unless res[:ok]

    payment = Payment.create!(
      account: @invoice.account,
      invoice: @invoice,
      provider: @method,
      provider_txn_id: res[:txn_id],
      amount_krw: @invoice.final_amount_krw,
      state: "succeeded",
      paid_at: Time.current,
      memo: "자동 결제 (mock)",
      encrypted_metadata: res[:payload].to_json
    )

    @invoice.update!(state: "paid", paid_on: Date.current)

    AuditEvent.create!(
      account_id: @invoice.account_id,
      action: "billing.payment.succeeded",
      resource_type: "Invoice",
      resource_id: @invoice.id,
      occurred_at: Time.current,
      metadata: { payment_id: payment.id, txn: res[:txn_id], amount_krw: payment.amount_krw }
    )

    Result.new(ok: true, payment: payment, invoice: @invoice)
  rescue => e
    Result.new(ok: false, error: e.message)
  end
end