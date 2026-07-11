class WeeklyReportJob < ApplicationJob
  queue_as :default

  # 매주 월요일 아침 자동 실행 — WeeklyReport row를 만들고 사장에게 메일 발송
  def perform(week_start_on: nil)
    target_start = (week_start_on || (Date.current - 7).beginning_of_week).to_date
    target_end   = (target_start + 6)
    Account.find_each do |account|
      report = AutoReport.weekly(account: account, week_start: target_start, week_end: target_end)
      next unless report
      DeliveryLog.create!(
        account: account,
        kind: "weekly_report",
        subject: "워크모리 주간 리포트",
        body_excerpt: report.summary.to_s.first(120),
        recipient_count: 1,
        delivered_at: Time.current
      )
    end
  end
end
