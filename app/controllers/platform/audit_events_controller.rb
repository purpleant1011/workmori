module Platform
  class AuditEventsController < BaseController
    def index; @events = AuditEvent.order(created_at: :desc).limit(200); end
    def show;  @event  = AuditEvent.find(params[:id]); end
  end
end
