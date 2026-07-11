module App
  class HandoffsController < BaseController
    before_action :load_handoff, only: [:show, :edit, :update, :acknowledge, :resolve]

    def index
      @handoffs = @current_account.handoffs.order(created_at: :desc).limit(50)
    end

    def show; end

    def edit; end

    def update
      if @handoff.update(handoff_params)
        redirect_to app_handoff_path(@handoff), notice: "핸드오프가 수정되었습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def acknowledge
      @handoff.update(state: "acknowledged", acknowledged_at: Time.current)
      redirect_to app_handoff_path(@handoff), notice: "핸드오프를 수신 확인했습니다."
    end

    def resolve
      @handoff.update(state: "resolved", resolved_at: Time.current, resolution_notes: params[:resolution_notes])
      redirect_to app_handoff_path(@handoff), notice: "핸드오프를 종료 처리했습니다."
    end

    private

    def load_handoff
      @handoff = @current_account.handoffs.find(params[:id])
    end

    def handoff_params
      params.require(:handoff).permit(:reason, :summary, :resolution_notes, :assigned_to_user_id, :state)
    end
  end
end