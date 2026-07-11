module App
  class FaqsController < BaseController
    before_action :load_faq, only: [:show, :edit, :update, :destroy]

    def index
      @faqs = @current_account.faqs.order(:id).limit(200)
    end

    def show
    end

    def new
      @faq = @current_account.faqs.new(active: true)
    end

    def create
      @faq = @current_account.faqs.new(faq_params)
      if @faq.save
        redirect_to app_faqs_path, notice: "FAQ가 등록되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @faq.update(faq_params)
        redirect_to app_faqs_path, notice: "FAQ가 수정되었습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @faq.destroy
      redirect_to app_faqs_path, notice: "FAQ가 삭제되었습니다."
    end

    private

    def load_faq
      @faq = @current_account.faqs.find(params[:id])
    end

    def faq_params
      params.require(:faq).permit(:question, :answer, :tags_json, :risk_level, :active, :ai_employee_id)
    end
  end
end