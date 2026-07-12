# frozen_string_literal: true

# GenerateDiscordReplyJob — Antigravity 워커 호출 → 응답 → Outbound 큐잉
# 원칙: Discord 응답은 항상 OutboundJob을 통해 비동기 송신 (메인 스레드 블로킹 안 함)
# P3 변경 (2026-07-12): stub → AntigravityClient.invoke 실제 호출
class GenerateDiscordReplyJob < DiscordNativeJob
  queue_as :default

  def perform(event_id)
    return unless FeatureFlags.enabled?(:discord_native_enabled)
    event = DiscordMessageEvent.find(event_id)
    business = event.business_profile
    return unless business

    # BusinessMemory recall
    memories = BusinessMemory.recall(business_profile: business, limit: 5)
    context_memories = memories.map { |m| { id: m.id, scope: m.scope, kind: m.memory_kind, content: m.content } }

    # Antigravity 워커 호출 (HTTP)
    response = AntigravityClient.invoke(
      business_profile_id: business.id,
      messages: [
        { role: "system", content: "당신은 매장 안내 직원입니다. 친절하고 간결하게 한국어로 답하세요." },
        { role: "user", content: event.safe_content.to_s }
      ],
      structured_output: "free",
      context_memories: context_memories
    )

    # 결과를 Discord로 송신
    DiscordOutboundJob.perform_later(
      business.id,
      event.channel_id,
      response["text"].to_s,
      reply_to_snowflake_id: event.snowflake_id,
      metadata: { intent: event.intent, memory_ids: memories.map(&:id), provider: response["provider"], model: response["model"] }
    )
  rescue AntigravityClient::Error => e
    Rails.logger.error("[GenerateDiscordReplyJob] #{e.message}")
    # 실패 시 안전한 fallback
    DiscordOutboundJob.perform_later(
      event.business_profile_id,
      event.channel_id,
      "잠시 후 다시 말씀해 주시면 더 정확히 안내드릴게요.",
      reply_to_snowflake_id: event.snowflake_id,
      metadata: { intent: event.intent, error: "antigravity_worker_error" }
    )
  end
end
