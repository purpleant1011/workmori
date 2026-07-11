module Platform
  class InquiriesController < BaseController
    def index
      @inquiries = Inquiry.order(created_at: :desc).limit((params[:page].to_i.clamp(1, 200)) * 50).last(50)
    end
    def show
      @inquiry = Inquiry.find(params[:id])
    end

    def new
      @inquiry = Inquiry.new
    end

    def create
      @inquiry = Inquiry.new(inquiry_params)
      if @inquiry.save
        redirect_to platform_inquiry_path(@inquiry), notice: "문의가 등록되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @inquiry = Inquiry.find(params[:id])
    end

    def update
      @inquiry = Inquiry.find(params[:id])
      if @inquiry.update(inquiry_params)
        redirect_to platform_inquiry_path(@inquiry), notice: "문의 상태가 업데이트되었습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @inquiry = Inquiry.find(params[:id])
      @inquiry.destroy
      redirect_to platform_inquiries_path, notice: "문의가 삭제되었습니다."
    end

    private
    def inquiry_params
      params.require(:inquiry).permit(:status, :score, :subject_kind)
    end
  end
end