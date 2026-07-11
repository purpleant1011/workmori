module App
  class BillingController < BaseController
    before_action -> { Rails.application.executor.wrap { Billing::InvoiceIssuer; Billing::PaymentCollector } }
    def index
      @invoices = @current_account.invoices.order(issued_on: :desc)
      @subscription = @current_account.subscriptions.where(state: %w[active paused]).first
      @plans = Plan.where(active: true).order(monthly_price_krw: :asc)
    end

    def show
      @invoice = @current_account.invoices.find_by(id: params[:id]) || @current_account.invoices.order(issued_on: :desc).first
    end

    def pay
      invoice = @current_account.invoices.find(params[:invoice_id])
      res = Billing::PaymentCollector.call(invoice: invoice)
      if res.ok
        flash[:notice] = "결제 완료 (#{res.payment.provider_txn_id}) — #{res.payment.amount_krw}원"
        DeliveryLog.create!(
          account: @current_account,
          kind: "billing",
          subject: "결제 완료 — #{invoice.invoice_number}",
          body_excerpt: "금액 #{res.payment.amount_krw}원 / Txn #{res.payment.provider_txn_id}",
          recipient_count: 1,
          delivered_at: Time.current,
          external_provider: "toss_mock",
          result_payload: { txn: res.payment.provider_txn_id, amount: res.payment.amount_krw }.to_json
        )
        redirect_to app_billing_invoice_path(res.invoice)
      else
        flash[:alert] = "결제 실패: #{res.error}"
        redirect_to app_billing_invoice_path(invoice)
      end
    end

    def subscribe
      plan = Plan.find(params[:plan_id])
      sub = @current_account.subscriptions.first || @current_account.build_subscription
      sub.plan = plan
      sub.started_on = Date.current
      sub.monthly_price_krw = plan.monthly_price_krw
      sub.monthly_price_vat_krw = plan.monthly_price_vat_krw
      sub.state = "active"
      sub.save!
      flash[:notice] = "구독 시작: #{plan.name} (#{plan.monthly_price_krw}원 + VAT)"
      redirect_to app_billing_path
    end

    def cancel_subscription
      sub = @current_account.subscriptions.find_by(state: "active")
      if sub
        sub.update!(state: "canceled", ended_on: Date.current, auto_renew: false)
        DeliveryLog.create!(
          account: @current_account, kind: "billing",
          subject: "구독 해지 안내",
          body_excerpt: "구독이 해지되었습니다. #{Date.current.strftime('%Y-%m-%d')} 까지 서비스 이용 가능합니다.",
          recipient_count: 1, delivered_at: Time.current, external_provider: "system",
          result_payload: { state: "canceled" }.to_json
        )
        flash[:notice] = "구독이 해지되었습니다."
      end
      redirect_to app_billing_path
    end
  end
end
