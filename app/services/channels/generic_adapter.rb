class Channels::GenericAdapter < Channels::Adapter
  def initialize(kind)
    @kind = kind
  end

  protected

  def publish_internal(channel, content_item, key)
    base = "#{@kind.upcase}-#{Time.current.to_i}-#{SecureRandom.hex(3)}"
    Result.new(
      ok: true,
      external_id: base,
      external_url: "https://mock.#{@kind}.local/posts/#{base}",
      provider: @kind,
      payload: { content: content_item&.body, idempotency_key: key }
    )
  end

  def verify_internal(channel)
    Result.new(ok: true, provider: @kind, payload: { handle: channel.handle })
  end
end