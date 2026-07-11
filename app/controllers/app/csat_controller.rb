# frozen_string_literal: true
module App
  class CsatController < App::BaseController
    def new
      @csat = CsatResponse.new
    end

    def create
      @csat = @current_account.csat_responses.new(csat_params)
      if @csat.save
        redirect_to app_analytics_path, notice: "피드백이 저장되었습니다. 감사합니다."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def csat_params
      params.require(:csat_response).permit(:score, :comment, :channel, :conversation_id, :respondent_kind)
    end
  end
end