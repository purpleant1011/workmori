# ContentScheduler — 콘텐츠 발행을 잡 큐에 enqueue
class ContentScheduler
  def self.enqueue_publisher(content)
    PublisherJob.perform_later(content.id, content.account_id)
  end

  def self.enqueue_automation(rule, content)
    Automation::RunJob.perform_later(rule.id, content&.id)
  end
end