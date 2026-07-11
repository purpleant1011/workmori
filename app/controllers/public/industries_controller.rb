module Public
  class IndustriesController < BaseController
    def index
      @industries = IndustryTemplate.active.order(:industry_code)
    end
    def show
      @industry = IndustryTemplate.find_by(industry_code: params[:id]) || IndustryTemplate.first
    end
  end
end
