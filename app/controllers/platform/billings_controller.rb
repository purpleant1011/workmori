module Platform
  class BillingsController < BaseController
    def index
      @plans = Plan.order(:monthly_price_krw)
      @contracts = ContractTerm.order(official_service_started_on: :desc).limit(50)
      @subscriptions = Subscription.includes(:account, :plan, :contract_term).order(created_at: :desc).limit(50)
      @invoices = Invoice.includes(:account).order(issued_on: :desc).limit(50)
      @payments = Payment.includes(:account, :invoice).order(paid_at: :desc).limit(50)
    end
  end
end