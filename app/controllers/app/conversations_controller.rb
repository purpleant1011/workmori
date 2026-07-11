module App
  class ConversationsController < BaseController
    def index; @conversations = @current_account.conversations.order(updated_at: :desc).limit(50); end
    def show
      @conversation = @current_account.conversations.find(params[:id])
      @messages = @conversation.messages.order(created_at: :asc)
    end
  end
end
