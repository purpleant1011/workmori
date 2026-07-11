module Platform
  class IndustriesController < BaseController
    def index
      @industries = IndustryTemplate.order(:industry_code)
    end
    def show
      @industry = IndustryTemplate.find(params[:id])
    end

    def new
      @industry = IndustryTemplate.new
    end

    def create
      @industry = IndustryTemplate.new(industry_params)
      if @industry.save
        redirect_to platform_industry_path(@industry), notice: "산업 템플릿이 생성되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @industry = IndustryTemplate.find(params[:id])
    end

    def update
      @industry = IndustryTemplate.find(params[:id])
      if @industry.update(industry_params)
        redirect_to platform_industry_path(@industry), notice: "산업 템플릿이 업데이트되었습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @industry = IndustryTemplate.find(params[:id])
      @industry.destroy
      redirect_to platform_industries_path, notice: "산업 템플릿이 삭제되었습니다."
    end

    private
    def industry_params
      params.require(:industry_template).permit(
        :industry_code, :industry_kind, :display_name, :slug, :version,
        :starter_brand_profile, :starter_ai_employee, :starter_automations, :starter_guardrails
      )
    end
  end
end