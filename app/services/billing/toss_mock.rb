# TossPayments mock adapter — sandbox / dev 전용 가짜 결제 게이트웨이
class Billing::TossMock
  Result = Struct.new(:ok, :txn_id, :provider, :payload, keyword_init: true)

  def self.authorize(amount_krw:, account_id:, invoice_number:, idempotency_key: nil)
    key = idempotency_key || "toss-#{invoice_number}-#{Time.current.to_i}-#{SecureRandom.hex(3)}"
    txn = "TXN_#{account_id}_#{key[0,24]}"
    Rails.logger.info "[TossMock] authorize account=#{account_id} invoice=#{invoice_number} amount=#{amount_krw} txn=#{txn}"
    Result.new(ok: true, txn_id: txn, provider: "toss_mock", payload: {
      txn_id: txn, amount_krw: amount_krw, authorized_at: Time.current, key: key, sandbox: true
    })
  end

  def self.capture(txn_id:)
    res = (txn_id.present? && txn_id.start_with?("TXN_"))
    Result.new(ok: res, txn_id: txn_id, provider: "toss_mock", payload: { captured_at: Time.current, sandbox: true })
  end

  def self.refund(txn_id:, amount_krw:)
    Result.new(ok: true, txn_id: txn_id, provider: "toss_mock", payload: {
      refunded_at: Time.current, refund_amount_krw: amount_krw, sandbox: true
    })
  end

  def self.webhook(event:, body:)
    res = authorize(amount_krw: body[:amount_krw], account_id: body[:account_id], invoice_number: body[:invoice_number])
    { ok: true, sandbox: true, event: event, txn: res.txn_id }
  end

  # 데모 헬퍼: 자동 결제 흐름 검증용 — 일정 시간 안에 결제 승인 후 콜백 호출
  def self.simulate_payment_now!(amount_krw:, account_id:, invoice_number:)
    res = authorize(amount_krw: amount_krw, account_id: account_id, invoice_number: invoice_number)
    { ok: res.ok, txn_id: res.txn_id, payload: res.payload }
  end
end
