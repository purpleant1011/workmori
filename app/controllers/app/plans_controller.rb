module App
  class PlansController < BaseController
    # 플랜 페이지는 만료된 트라이얼도 접근 가능 (결제 진행 위해)
    skip_before_action :enforce_trial_status!, only: [:index]

    def index; @plans = Plan.where(active: true).order(:monthly_price_krw); end
  end
end
