class Public::HomeController < Public::BaseController
  def show
    @industries = IndustryTemplate.order(:industry_code)
    @stats = {
      accounts: [Account.count, "계정"],
      automations_today: [AutomationExecution.where(state: "succeeded", created_at: Time.zone.today.all_day).count, "오늘 자동화 성공"],
      content_published: [PublicationAttempt.where(state: "succeeded").count, "게시된 콘텐츠"]
    }
    @testimonials = []
  end
end
