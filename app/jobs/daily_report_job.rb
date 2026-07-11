class DailyReportJob < ApplicationJob
  queue_as :default

  # 매일 새벽 1시 1회, 다중 고객 각 account별로 일간 리포트 생성 + 메일 발송
  def perform(report_date: nil, account_id: nil)
    target_date = (report_date || Date.current - 1).to_date
    scope = account_id ? Account.where(id: account_id) : Account.all
    scope.find_each do |account|
      result = AutoReport.daily(account: account, target_date: target_date)
      next if result.nil?
      DeliveryLog.create!(
        account: account,
        kind: "daily_report",
        subject: "워크모리 일간 리포트",
        body_excerpt: result[:summary].to_s.first(120),
        recipient_count: 1,
        delivered_at: Time.current
      )
      begin
        DailyReportMailer.daily_report(account: account, report_date: target_date, metrics: result).deliver_now
      rescue StandardError => e
        Rails.logger.warn("[DailyReportJob] mailer failed: account=#{account.id} #{e.class} #{e.message}")
      end
    end
  end
end
