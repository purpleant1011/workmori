module App
  # 명세 §9: 3 탭 통합 (원장님 답변 필요 / 소희가 처리 / 처리 완료)
  class ConversationsController < BaseController
    TAB_NEED   = "need"
    TAB_SOHEE  = "sohee"
    TAB_DONE   = "done"
    ALL_TABS   = [TAB_NEED, TAB_SOHEE, TAB_DONE].freeze

    def index
      @tab = ALL_TABS.include?(params[:tab]) ? params[:tab] : TAB_NEED

      all = @current_account.conversations.order(updated_at: :desc)
      need  = all.where(risk_level: "high", state: "open").limit(60)
      sohee = all.where(risk_level: %w[low medium]).where(state: %w[open acknowledged]).limit(60)
      done  = all.where(state: %w[closed resolved]).limit(60)

      @conversations = case @tab
                       when TAB_NEED  then need
                       when TAB_SOHEE then sohee
                       else done
                       end

      @counts = {
        need:  need.count,
        sohee: sohee.count,
        done:  done.count
      }
    end

    def show
      @conversation = @current_account.conversations.find(params[:id])
      @messages = @conversation.messages.order(created_at: :asc)
    end
  end
end