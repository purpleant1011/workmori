module App
  class DeletionRequestsController < BaseController
    def index
      @del = @current_account.deletion_requests.order(requested_at: :desc)
    end
    def show
      @del = @current_account.deletion_requests.find(params[:id])
    end
    def create
      DeletionRequest.create!(account: @current_account, requested_by_user_id: current_user.id, requested_at: Time.current, status: "queued", notice_period_days: 30)
      redirect_to deletion_requests_path, notice: "삭제 요청이 등록되었습니다."
    end
  end
end
