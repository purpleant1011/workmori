module Platform
  class PlansController < BaseController
    def index; @plans = Plan.order(:monthly_price_krw); end
    def show;  @plan  = Plan.find(params[:id]); end
    def create
      Plan.create!(plan_params)
      redirect_to platform_plans_path, notice: "요금제가 추가되었습니다."
    end
    def update
      Plan.find(params[:id]).update(plan_params)
      redirect_to platform_plans_path, notice: "요금제가 업데이트되었습니다."
    end
    private
    def plan_params
      params.require(:plan).permit(:code, :name, :description, :monthly_price_krw, :monthly_price_vat_krw, :active, features: [])
    end
  end
end
