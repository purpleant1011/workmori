module App
  class TerminationsController < BaseController
    def new
      @req = TerminationRequest.find_or_initialize_by(account: @current_account, state: "draft")
      @req.requested_by_user_id ||= current_user.id
      @req.save
    end
    def confirm
      @req = TerminationRequest.where(account: @current_account).order(created_at: :desc).first
    end
    def create
      TerminationRequest.create!(account: @current_account, reason: params[:reason].to_s, requested_by_user_id: current_user.id, state: "pending", requested_at: Time.current, notice_period_days: 30)
      redirect_to app_root_path, notice: "해지 요청이 접수되었습니다."
    end
  end
end
