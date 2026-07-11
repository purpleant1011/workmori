# WorkMori — NotificationBroadcaster
# 실시간 알림 broadcast 헬퍼
#
# 사용법:
#   NotificationBroadcaster.handoff_created(account_id, handoff)
#   NotificationBroadcaster.message_arrived(account_id, conversation)
#   NotificationBroadcaster.automation_completed(account_id, execution)
#   NotificationBroadcaster.publish_result(account_id, content_item, status)
#   NotificationBroadcaster.platform_event(action, payload)
module NotificationBroadcaster
  module_function

  def handoff_created(account_id, handoff)
    broadcast(account_id, "handoff_created", {
      id: handoff.id,
      reason: handoff.reason,
      summary: handoff.summary,
      state: handoff.state,
      url: "/app/handoffs/#{handoff.id}",
      created_at: handoff.created_at
    })
  end

  def message_arrived(account_id, conversation)
    broadcast(account_id, "message_arrived", {
      conversation_id: conversation.id,
      last_message_at: conversation.last_message_at,
      risk_level: conversation.risk_level,
      url: "/app/conversations/#{conversation.id}"
    })
  end

  def automation_completed(account_id, execution)
    broadcast(account_id, "automation_completed", {
      id: execution.id,
      rule_id: execution.automation_rule_id,
      state: execution.state,
      duration_ms: execution.duration_ms,
      finished_at: execution.finished_at
    })
  end

  def publish_result(account_id, content_item, status)
    broadcast(account_id, "publish_result", {
      content_item_id: content_item.id,
      state: status,
      url: "/app/content/items/#{content_item.id}"
    })
  end

  def platform_event(action, payload = {})
    ActionCable.server.broadcast("platform:events", {
      event: action,
      payload: payload,
      at: Time.current.iso8601
    }.to_json)
  end

  def broadcast(account_id, event, payload)
    return if account_id.blank?
    ActionCable.server.broadcast("account:#{account_id}:notifications", {
      event: event,
      payload: payload,
      at: Time.current.iso8601
    }.to_json)
  rescue => e
    Rails.logger.warn("[NotificationBroadcaster] broadcast failed: #{e.class}: #{e.message[0,120]}")
  end
end