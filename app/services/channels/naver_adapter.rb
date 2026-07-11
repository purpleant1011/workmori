# Naver Place/Blog mock adapter
class Channels::NaverAdapter < Channels::Adapter
  PROTOCOL_VERSION = "v2".freeze

  protected

  def publish_internal(channel, content_item, key)
    if content_item.blank? || (content_item.title.to_s.strip.empty? && content_item.body.to_s.strip.empty?)
      return Result.new(ok: false, error: "제목/본문 비어있음", provider: "naver")
    end

    base = "NAVER-#{channel.kind.upcase}-#{Time.current.to_i}-#{SecureRandom.hex(3)}"
    Result.new(
      ok: true,
      external_id: base,
      external_url: "https://#{channel.kind == 'naver_place' ? 'map.naver.com' : 'blog.naver.com'}/#{channel.handle}/#{base}",
      provider: "naver",
      payload: {
        title: content_item.title,
        body: content_item.body,
        idempotency_key: key,
        protocol: PROTOCOL_VERSION
      }
    )
  end

  def verify_internal(channel)
    ok = channel.handle.present?
    Result.new(ok: ok, provider: "naver", payload: { kind: channel.kind, handle: channel.handle })
  end
end