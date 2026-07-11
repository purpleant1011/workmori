# Content::Scheduler — 예약 발행 큐 잡 enqueue + 잡 상태 관리
class Content::Scheduler
  def self.enqueue_publisher(content_item, delay: nil, idempotency_key: nil)
    return false unless content_item
    key = idempotency_key || "publish-#{content_item.id}-#{Time.current.to_i}-#{SecureRandom.hex(3)}"
    attrs = {
      account: content_item.account,
      content_item_id: content_item.id,
      idempotency_key: key,
    }
    delay_seconds = delay || seconds_until(content_item.scheduled_at)
    # state 전이: auto_approved -> scheduled (예약/즉시 모두 scheduled 사용)
    content_item.update_columns(state: "scheduled")
    if delay_seconds && delay_seconds > 0
      Content::PublisherJob.set(wait: delay_seconds.to_i.seconds).perform_later(**attrs)
    else
      Content::PublisherJob.perform_later(**attrs)
    end
    true
  end

  def self.seconds_until(time)
    return nil unless time
    secs = (time.to_time - Time.current).to_f
    return 0 if secs <= 0
    secs
  end
end
