module App
  class PlansController < BaseController
    def index; @plans = Plan.where(active: true).order(:monthly_price_krw); end
  end
end
