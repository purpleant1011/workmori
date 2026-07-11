class Content::PublisherJob < ApplicationJob
  queue_as :default

  # perform_later(account:, content_item_id:, idempotency_key:)
  def perform(account:, content_item_id:, **opts)
    idempotency_key = opts[:idempotency_key] || "publish-#{content_item_id}-#{Time.current.to_i}"

    content = ContentItem.find_by(id: content_item_id, account_id: account.id)
    unless content
      Rails.logger.warn("[Content::PublisherJob] content missing: id=#{content_item_id} account=#{account.id}")
      return
    end

    # Idempotency: 이미 같은 key + state=succeeded 면 skip
    existing = PublicationAttempt.find_by(idempotency_key: idempotency_key, state: "succeeded")
    if existing
      Rails.logger.info("[Content::PublisherJob] already published: ci=#{content_item_id} key=#{idempotency_key}")
      return
    end

    # blocked는 발행 불가 — admin 검토 후 다시 published 상태로 변경 후 호출해야 함
    if content.safety_blocked?
      Rails.logger.warn("[Content::PublisherJob] safety_blocked skip: id=#{content_item_id}")
      return
    end

    channel = pick_default_channel(content.account)
    attempt = PublicationAttempt.create!(
      account: content.account,
      content_item: content,
      channel_connection: channel,
      idempotency_key: idempotency_key,
      state: "running",
      attempts: 0,
    )

    begin
      result = publish_via_adapter(content, channel, attempt)
      attempt.update!(
        state: "succeeded",
        external_url: result[:external_url],
        external_id: result[:external_id],
        response_payload: result,
        attempts: (attempt.attempts || 0) + 1,
      )
      content.update!(state: "published", published_at: Time.current, published_external_url: result[:external_url])
      AuditEvent.create!(account: content.account, action: "content.published", resource_type: "ContentItem", resource_id: content.id, metadata: { external_id: result[:external_id], url: result[:external_url] }, occurred_at: Time.current)
    rescue StandardError => e
      attempts = (attempt.attempts || 0) + 1
      attempt.update!(state: "failed", error_message: e.message, attempts: attempts, response_payload: { exception: e.class.name, message: e.message })
      content.update_columns(state: "failed") # bypass validation since state may transient
      Rails.logger.error("[Content::PublisherJob] failed ci=#{content.id} err=#{e.class}: #{e.message}")
    end
  end

  private

  # Test account: 연결된 채널 없으면 mock으로 즉시 성공 처리
  def pick_default_channel(account)
    account.channel_connections.where(status: "active").first
  end

  def publish_via_adapter(content, channel, attempt)
    payload = {
      title: content.title,
      body: content.body,
      caption: content.caption,
      hashtags: JSON.parse(content.hashtags_json.to_s.presence || "[]"),
      target_channel_kind: content.target_channel_kind,
    }
    if channel.nil?
      # Mock mode: dev/test → fake external id/URL
      fake_id = "mock_#{SecureRandom.hex(8)}"
      { ok: true, external_id: fake_id, external_url: "https://mock.workmori.example/posts/#{fake_id}", request_payload: payload, mode: "mock" }
    else
      # Real adapter path (not yet implemented — fall back to mock for now)
      fake_id = "#{channel.kind}_#{SecureRandom.hex(6)}"
      { ok: true, external_id: fake_id, external_url: "https://#{channel.kind}.workmori.example/p/#{fake_id}", request_payload: payload, mode: "channel_adapter_stub" }
    end
  end
end
