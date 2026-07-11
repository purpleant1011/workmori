module Platform
  class ReportsController < BaseController
    def show
      @weekly = WeeklyReport.order(week_start: :desc).limit(20)
      @inquiries_by_day = Inquiry.where("created_at > ?", 7.days.ago).group("DATE(created_at)").count
      @accounts_active  = Account.where(status: "active").count
    end
  end
end
