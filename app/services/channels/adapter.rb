# Channels::Adapter — 채널별 어댑터 (Instagram/Naver/Mastodon 등 mock)
# Result: { ok:, external_id:, external_url:, error: }
class Channels::Adapter
  Result = Struct.new(:ok, :external_id, :external_url, :provider, :error, :payload, keyword_init: true)

  def self.for(kind)
    case kind.to_s
    when "instagram"  then Channels::InstagramAdapter.new
    when "threads"    then Channels::ThreadsAdapter.new
    when "naver_place", "blog", "naver" then Channels::NaverAdapter.new
    when "mastodon"   then Channels::MastodonAdapter.new
    when "kakao_channel" then Channels::KakaoAdapter.new
    when "email"      then Channels::EmailAdapter.new
    when "discord"    then Channels::GenericAdapter.new(kind)
    else Channels::GenericAdapter.new(kind)
    end
  end

  def self.publish(channel:, content_item:, idempotency_key:)
    new(channel: channel, content_item: content_item, idempotency_key: idempotency_key).publish
  end

  def self.verify(channel:)
    adapter = self.for(channel.kind)
    adapter.send(:verify_internal, channel)
  end

  def initialize(channel: nil, content_item: nil, idempotency_key: nil)
    @channel = channel
    @content_item = content_item
    @idempotency_key = idempotency_key
  end

  def publish
    adapter = self.class.for(@channel.kind)
    adapter.send(:publish_internal, @channel, @content_item, @idempotency_key)
  end

  def verify
    adapter = self.class.for(@channel.kind)
    adapter.send(:verify_internal, @channel)
  end

  protected

  def publish_internal(channel, content_item, key)
    base = "TX-#{channel.kind.upcase}-#{Time.current.to_i}-#{SecureRandom.hex(3)}"
    Result.new(
      ok: true,
      external_id: base,
      external_url: "https://mock.#{channel.kind}.local/posts/#{base}",
      provider: channel.kind,
      payload: { title: content_item&.title, body: content_item&.body, idempotency_key: key, external_url: "https://mock.#{channel.kind}.local/posts/#{base}" }
    )
  end

  def verify_internal(channel)
    Result.new(ok: channel.status == "active", provider: channel.kind, payload: { status: channel.status })
  end
end