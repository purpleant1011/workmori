module App
  class KnowledgeSourcesController < BaseController
    def index
      @sources = @current_account.knowledge_sources.order(:source_kind, :title)
      @documents = @current_account.knowledge_documents.order(created_at: :desc).limit(20)
    end
    def show
      @source = @current_account.knowledge_sources.find(params[:id])
    end
  end
end
