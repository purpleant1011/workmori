# Billing::BillingAutomation — 구독자 일간 청구 발행 + 자동 결제 시도
class Billing::BillingAutomation
  Result = Struct.new(:issued, :collected, :errors, keyword_init: true)

  def self.run_daily_billing(today: Date.current)
    new.run_daily_billing(today: today)
  end

  def run_daily_billing(today: Date.current)
    issued = 0
    collected = 0
    errors = []

    Subscription.where(state: "active").where("next_billing_on <= ?", today).find_each do |sub|
      begin
        res = Billing::InvoiceIssuer.call(account: sub.account, subscription: sub, period_start: today, period_end: today.end_of_month)
        if res.ok
          issued += 1
          pay = Billing::PaymentCollector.call(invoice: res.invoice)
          collected += 1 if pay.ok
        else
          errors << "sub=#{sub.id}: #{res.error}"
        end
        sub.advance_period!(today)
      rescue => e
        errors << "sub=#{sub.id}: #{e.class}: #{e.message}"
      end
    end

    Result.new(issued: issued, collected: collected, errors: errors)
  end
end
