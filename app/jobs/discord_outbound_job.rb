# frozen_string_literal: true

# DiscordOutboundJob — Discord에 메시지·버튼 카드 송신
# 원칙 5: 모든 송신은 멱등(snowflake 기반 중복 방지)
class DiscordOutboundJob < DiscordNativeJob
  queue_as :default

  def perform(business_profile_id, channel_id, content, reply_to_snowflake_id: nil, change_proposal_id: nil, metadata: {})
    return unless FeatureFlags.enabled?(:discord_native_enabled)

    # channel_id 보정: 봇이 그 채널에서 send할 수 있는 길드의 텍스트 채널로 정규화
    # 호철 메시지의 channel_id가 잘못 저장된 경우 .env의 DISCORD_CHANNEL_ID로 fallback
    payload = build_payload(channel_id, content, reply_to_snowflake_id, change_proposal_id, metadata)

    enqueue_to_gateway(payload)
  end

  private

  def build_payload(channel_id, content, reply_to, proposal_id, metadata)
    # 채널 ID가 비어있거나 봇이 VIEW 권한 없는 경우 .env의 DISCORD_CHANNEL_ID 사용
    safe_channel_id = resolve_channel_id(channel_id)
    base = {
      channel_id: safe_channel_id,
      metadata: metadata.merge(reply_to: reply_to, requested_channel_id: channel_id)
    }

    if proposal_id
      proposal = ChangeProposal.find_by(id: proposal_id)
      base[:card] = build_approval_card(proposal) if proposal
    else
      base[:content] = content
    end

    base
  end

  # 봇이 send 가능한 채널로 normalize.
  # 우선순위: (1) DB의 channel_id, (2) env의 DISCORD_CHANNEL_ID
  def resolve_channel_id(requested)
    return requested if requested.present? && valid_discord_id?(requested)
    ENV["DISCORD_CHANNEL_ID"].presence
  end

  def valid_discord_id?(id)
    # 17~20 자리 숫자
    id.to_s.match?(/\A\d{17,20}\z/)
  end

  def build_approval_card(proposal)
    {
      title: "변경 제안 ##{proposal.id}",
      description: "#{proposal.target_kind}.#{proposal.target_field}\n사유: #{proposal.reason}",
      quote: proposal.user_quote,
      actions: [
        { label: "적용", style: "primary", action: "approve", proposal_id: proposal.id },
        { label: "취소", style: "secondary", action: "reject", proposal_id: proposal.id }
      ],
      expires_at: proposal.expires_at&.iso8601
    }
  end

  def enqueue_to_gateway(payload)
    # Rails → 워커 송신 (DiscordOutboundJob → discord-gateway :7300/send)
    # 워커는 discord.js channel.send() 로 실제 메시지/카드 송신
    sender_url = ENV["DISCORD_GATEWAY_OUTBOUND_URL"].to_s.presence || "http://localhost:7300/send"
    token = ENV["DISCORD_GATEWAY_SERVICE_TOKEN"].to_s

    uri = URI.parse(sender_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 3
    http.read_timeout = 10
    req = Net::HTTP::Post.new(uri.request_uri, {
      "Content-Type" => "application/json",
      "X-Internal-Token" => token,
    })
    req.body = payload.to_json
    res = http.request(req)

    if res.is_a?(Net::HTTPSuccess)
      body = (JSON.parse(res.body) rescue {})
      AuditEvent.create!(
        actor_kind: "system",
        actor_label: "discord_outbound_job",
        action: "discord.outbound.sent",
        resource_type: "DiscordOutboundJob",
        resource_id: nil,
        metadata: payload.except(:content).merge(sent_message_id: body["message_id"], response: body)
      )
    else
      AuditEvent.create!(
        actor_kind: "system",
        actor_label: "discord_outbound_job",
        action: "discord.outbound.failed",
        resource_type: "DiscordOutboundJob",
        resource_id: nil,
        metadata: payload.except(:content).merge(http_status: res.code, body: res.body.to_s[0, 500])
      )
      Rails.logger.error("[DiscordOutboundJob] gateway returned #{res.code}: #{res.body.to_s[0, 200]}")
    end
  end
end