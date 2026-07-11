# Channels::Publisher — 채널 어댑터 호출 + PublicationAttempt 기록 + DeliveryLog
class Channels::Publisher
  Result = Struct.new(:ok, :publication, :error, keyword_init: true)

  def self.call(channel:, content_item:, idempotency_key: nil)
    new(channel: channel, content_item: content_item, idempotency_key: idempotency_key).call
  end

  def initialize(channel:, content_item:, idempotency_key: nil)
    @channel = channel
    @content_item = content_item
    @idempotency_key = idempotency_key || SecureRandom.uuid
  end

  def call
    return Result.new(ok: false, error: "채널이 active 아님 (#{@channel.status})") unless @channel.status == "active"

    # idempotency
    if (existing = PublicationAttempt.find_by(idempotency_key: @idempotency_key))
      return Result.new(ok: existing.state == "succeeded", publication: existing, error: existing.error_message)
    end

    pa = PublicationAttempt.create!(
      account: @channel.account,
      content_item: @content_item,
      channel_connection: @channel,
      idempotency_key: @idempotency_key,
      state: "in_flight",
      attempts: 1,
      created_at: Time.current
    )

    res = Channels::Adapter.publish(channel: @channel, content_item: @content_item, idempotency_key: @idempotency_key)

    if res.ok
      pa.update!(
        state: "succeeded",
        external_id: res.external_id,
        external_url: res.external_url,
        response_payload: (res.payload || {}).to_h.merge("ok" => true, "provider" => res.provider, "external_id" => res.external_id, "external_url" => res.external_url)
      )

      DeliveryLog.create!(
        account: @channel.account,
        kind: "channel_publish",
        subject: "#{@channel.kind} 게시 완료 — #{@content_item.title.presence || @content_item.body.to_s[0,30]}",
        body_excerpt: "external=#{res.external_url}",
        recipient_count: 1,
        delivered_at: Time.current,
        external_provider: res.provider,
        result_payload: { external_id: res.external_id, url: res.external_url }.to_json
      )

      AuditEvent.create!(
        account_id: @channel.account_id,
        action: "channel.published",
        resource_type: "ContentItem",
        resource_id: @content_item.id,
        occurred_at: Time.current,
        metadata: { channel: @channel.kind, external_id: res.external_id, external_url: res.external_url }
      )

      @content_item.update_column(:published_at, Time.current) if @content_item.respond_to?(:published_at=)
      @content_item.update_column(:published_external_url, res.external_url) if @content_item.respond_to?(:published_external_url=) && res.external_url
      Result.new(ok: true, publication: pa)
    else
      pa.update!(
        state: "failed",
        error_message: res.error,
        response_payload: { "ok" => false, "error" => res.error }
      )

      AuditEvent.create!(
        account_id: @channel.account_id,
        action: "channel.publish.failed",
        resource_type: "ContentItem",
        resource_id: @content_item.id,
        occurred_at: Time.current,
        metadata: { channel: @channel.kind, error: res.error }
      )

      Result.new(ok: false, publication: pa, error: res.error)
    end
  rescue => e
    if pa
      pa.update(state: "failed", error_message: e.message)
    else
      PublicationAttempt.create!(
        account: @channel.account,
        content_item: @content_item,
        channel_connection: @channel,
        idempotency_key: @idempotency_key,
        state: "failed",
        attempts: 1,
        error_message: e.message
      )
    end
    Result.new(ok: false, error: e.message)
  end
end
