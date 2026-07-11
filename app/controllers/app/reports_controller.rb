class App::ReportsController < App::BaseController
  before_action :require_owner_or_admin!

  def index
    @weekly_reports = @current_account.weekly_reports.order(week_start_on: :desc).limit(12)
    @today_metrics = AutoReport.daily(account: @current_account, target_date: Date.current - 1)
    @recent_deliveries = @current_account.delivery_logs.where(kind: %w[daily_report weekly_report]).order(delivered_at: :desc).limit(10)
  end

  def show_weekly
    @report = @current_account.weekly_reports.find(params[:id])
    render :weekly
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "해당 주간 리포트가 없습니다."
    redirect_to app_reports_path
  end

  def trigger_weekly
    WeeklyReportJob.perform_now(week_start_on: 1.week.ago.to_date.beginning_of_week)
    flash[:notice] = "주간 리포트를 즉시 생성했습니다."
    redirect_to app_reports_path
  end

  def trigger_daily
    DailyReportJob.perform_now(report_date: Date.current - 1, account_id: @current_account.id)
    flash[:notice] = "일간 리포트를 즉시 생성했습니다."
    redirect_to app_reports_path
  end
end
