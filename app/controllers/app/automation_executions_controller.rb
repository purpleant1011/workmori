class App::AutomationExecutionsController < App::BaseController
  def index
    @executions = @current_account.automation_executions.order(created_at: :desc).limit(100)
  end

  def show
    @execution = @current_account.automation_executions.find(params[:id])
    @events = @execution.execution_events.order(occurred_at: :asc)
  end
end
