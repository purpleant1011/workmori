# Mastodon mock adapter (ActivityPub 기반, toot)
class Channels::MastodonAdapter < Channels::Adapter
  MAX_CHARS = 500

  protected

  def publish_internal(channel, content_item, key)
    body = content_item&.body.to_s
    if body.strip.empty?
      return Result.new(ok: false, error: "toot 본문이 비어있음", provider: "mastodon")
    end
    if body.length > MAX_CHARS
      return Result.new(ok: false, error: "Mastodon 500자 제한 초과 (#{body.length}/#{MAX_CHARS})", provider: "mastodon")
    end

    base = "MASTO-#{Time.current.to_i}-#{SecureRandom.hex(3)}"
    Result.new(
      ok: true,
      external_id: base,
      external_url: "https://#{channel.handle.to_s.sub('@', '').sub('.', '.')}/@#{channel.handle}/#{base}",
      provider: "mastodon",
      payload: {
        toot: body,
        visibility: "public",
        idempotency_key: key
      }
    )
  end

  def verify_internal(channel)
    ok = channel.handle.to_s.include?("@")
    Result.new(ok: ok, provider: "mastodon", payload: { handle: channel.handle })
  end
end