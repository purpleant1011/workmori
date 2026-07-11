class App::DashboardsController < App::BaseController
  def show
    @range = params[:range].presence_in(%w[7d 30d 90d]) || "7d"
    @days = { "7d" => 7, "30d" => 30, "90d" => 90 }[@range]
    @since = @days.days.ago.beginning_of_day
    @metrics = BusinessMetrics.call(account: @current_account, since: @since)
    @recent_automations = @current_account.automation_executions.where("created_at >= ?", @since).order(created_at: :desc).limit(8)
    @pending_contents   = @current_account.content_items.where(state: "pending_review").order(created_at: :desc).limit(5)
    @channel_breakdown  = @current_account.publication_attempts.where("created_at >= ?", @since).group(:channel_connection_id).count
  end
end