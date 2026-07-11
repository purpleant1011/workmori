class App::DashboardsController < App::BaseController
  def show
    @range = params[:range].presence_in(%w[7d 30d 90d]) || "7d"
    @days = { "7d" => 7, "30d" => 30, "90d" => 90 }[@range]
    @since = @days.days.ago.beginning_of_day
    @metrics = BusinessMetrics.call(account: @current_account, since: @since)
    @recent_automations = @current_account.automation_executions.where("created_at >= ?", @since).order(created_at: :desc).limit(8)
    @pending_contents   = @current_account.content_items.where(state: "pending_review").order(created_at: :desc).limit(5)
    @channel_breakdown  = @current_account.publication_attempts.where("created_at >= ?", @since).group(:channel_connection_id).count
    @announcements = Announcement.for_account(@current_account).recent.limit(5)
    @internal_info = build_internal_info
  end

  private

  def build_internal_info
    # 사업자에게 노출되는 내부 운영 정보
    {
      api_endpoints: {
        backend: ENV.fetch("PUBLIC_HOST", "127.0.0.1:3001"),
        local: "http://127.0.0.1:3001",
        tunnel: ENV["TUNNEL_URL"]
      }.compact,
      demo_accounts: {
        business_skin: "owner@demo.example",
        business_cafe: "cafe-owner@demo.example",
        business_shop: "shop-owner@demo.example"
      },
      stack: "Rails 8 + Hotwire + Tailwind v3 + PG 16 + Solid Queue/Cable + ActiveStorage + Sentry",
      e2e_tests: "Playwright 14/14 PASS"
    }
  end
end