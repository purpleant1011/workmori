module Platform
  class PlatformStaffController < BaseController
    def index
      @staff = PlatformStaff.order(:role, :email_address)
    end
    def show
      @person = PlatformStaff.find(params[:id])
    end
  end
end
