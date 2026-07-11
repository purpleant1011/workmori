class DailyReportMailer < ApplicationMailer
  # 일간 리포트 메일 — 자동화 발송 결과 + 안전 통계 + 추천 개선
  def daily_report(account:, report_date:, metrics:, sender: :business_owner)
    @account = account
    @report_date = (report_date || Date.current).to_date
    @metrics = metrics || {}
    @sender = sender
    owner = User.where(account_id: account.id).first
    return false unless owner
    mail(
      to: owner.email_address,
      subject: "[워크모리] #{account.name} 일간 리포트 (#{@report_date})"
    )
  end
end
