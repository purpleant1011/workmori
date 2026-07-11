module Public
  class PricingController < BaseController
    def show
      @monthly_krw = brand.pricing[:beta_monthly_krw]
      @deposit_krw = brand.pricing[:beta_deposit_krw]
      @plans = Plan.where(active: true).order(:monthly_price_krw)
    end
  end
end
