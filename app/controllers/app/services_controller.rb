module App
  class ServicesController < BaseController
    before_action :load_service, only: [:show, :edit, :update, :destroy]

    def index
      @services = @current_account.services.order(:name)
    end

    def show; end

    def new
      @service = @current_account.services.new(active: true)
    end

    def create
      @service = @current_account.services.new(service_params)
      if @service.save
        redirect_to app_services_path, notice: "서비스가 등록되었습니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @service.update(service_params)
        redirect_to app_services_path, notice: "서비스가 수정되었습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @service.destroy
      redirect_to app_services_path, notice: "서비스가 삭제되었습니다."
    end

    private

    def load_service
      @service = @current_account.services.find(params[:id])
    end

    def service_params
      params.require(:service).permit(:name, :description, :active)
    end
  end
end