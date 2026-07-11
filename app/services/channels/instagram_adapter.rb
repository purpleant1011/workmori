# Instagram Graph API 어댑터
# 공식 Meta API (Business account 필요) — 비용 0
#
# 필요 ENV:
#   META_GRAPH_API_TOKEN  — 장기 access token (60일 만료, refresh 필요)
#   META_GRAPH_API_VERSION — v18.0 등 (default v19.0)
#
# 게시물 생성 흐름 (이미지 1장):
#   1. POST /{ig-user-id}/media  (image_url, caption, is_carousel_item=false)
#      → container_id 응답
#   2. POST /{ig-user-id}/media_publish (creation_id=container_id)
#      → media_id (external_id) 응답
#
# 이미지 호스팅: 우리 서버의 public URL이어야 함 (instagram이 fetch)
#   → rails_blob_url 또는 storage_url 사용

class Channels::InstagramAdapter < Channels::Adapter
  GRAPH_BASE = "https://graph.facebook.com"
  DEFAULT_API_VERSION = "v19.0"

  protected

  def publish_internal(channel, content_item, key)
    token = ENV["META_GRAPH_API_TOKEN"].to_s
    ig_user_id = channel.handle.to_s  # 또는 channel.external_user_id (실제 IG user id)
    api_version = ENV.fetch("META_GRAPH_API_VERSION", DEFAULT_API_VERSION)

    if token.blank? || ig_user_id.blank?
      Rails.logger.warn("[instagram] META_GRAPH_API_TOKEN or handle missing → mock fallback")
      return mock_publish(content_item, key)
    end

    image_url = first_published_image_url(content_item)
    if image_url.blank?
      return Result.new(ok: false, error: "Instagram 게시물에는 최소 1장의 이미지가 필요합니다.", provider: "instagram")
    end

    # 1) media container 생성
    container_id = post_media_container(
      ig_user_id: ig_user_id, api_version: api_version, token: token,
      image_url: image_url, caption: content_item.body.to_s
    )
    return Result.new(ok: false, error: "container 생성 실패: #{container_id}", provider: "instagram") unless container_id

    # 2) media_publish
    publish_res = post_media_publish(
      ig_user_id: ig_user_id, api_version: api_version, token: token,
      creation_id: container_id
    )

    if publish_res[:error]
      return Result.new(ok: false, error: "publish 실패: #{publish_res[:error]}", provider: "instagram")
    end

    media_id = publish_res[:id]
    Result.new(
      ok: true,
      external_id: media_id,
      external_url: "https://instagram.com/p/#{media_id}",
      provider: "instagram",
      payload: {
        caption: content_item.body.to_s[0, 2200],
        image_url: image_url,
        media_id: media_id,
        idempotency_key: key
      }
    )
  rescue => e
    Result.new(ok: false, error: "Instagram 어댑터 예외: #{e.class}: #{e.message[0,200]}", provider: "instagram")
  end

  def verify_internal(channel)
    token = ENV["META_GRAPH_API_TOKEN"].to_s
    ig_user_id = channel.handle.to_s
    return Result.new(ok: false, error: "META_GRAPH_API_TOKEN or handle missing", provider: "instagram") if token.blank? || ig_user_id.blank?

    api_version = ENV.fetch("META_GRAPH_API_VERSION", DEFAULT_API_VERSION)
    url = "#{GRAPH_BASE}/#{api_version}/#{ig_user_id}?fields=id,username&access_token=#{token}"
    res = http_get_json(url, timeout: 10)
    if res[:error]
      Result.new(ok: false, error: res[:error], provider: "instagram")
    else
      Result.new(ok: true, provider: "instagram", payload: { ig_user_id: res[:id], username: res[:username] })
    end
  end

  private

  def first_published_image_url(content_item)
    return nil unless content_item.respond_to?(:media) && content_item.media.attached?
    blob = content_item.media.first
    return nil unless blob
    # instagram이 fetch할 수 있는 public URL
    Rails.application.routes.url_helpers.rails_blob_url(blob, host: ENV.fetch("PUBLIC_HOST", "127.0.0.1:3001"), protocol: ENV.fetch("PUBLIC_PROTOCOL", "http"))
  end

  def post_media_container(ig_user_id:, api_version:, token:, image_url:, caption:)
    url = "#{GRAPH_BASE}/#{api_version}/#{ig_user_id}/media"
    body = { image_url: image_url, caption: caption, access_token: token }
    res = http_post_form(url, body, timeout: 30)
    return res[:error] if res[:error]
    res[:id]
  end

  def post_media_publish(ig_user_id:, api_version:, token:, creation_id:)
    url = "#{GRAPH_BASE}/#{api_version}/#{ig_user_id}/media_publish"
    body = { creation_id: creation_id, access_token: token }
    http_post_form(url, body, timeout: 30)
  end

  def http_post_form(url, body, timeout:)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = timeout
    http.read_timeout = timeout
    req = Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data(body)
    res = http.request(req)
    if res.code.to_i >= 400
      return { error: "HTTP #{res.code}: #{res.body[0, 200]}" }
    end
    JSON.parse(res.body)
  rescue => e
    { error: "#{e.class}: #{e.message[0, 200]}" }
  end

  def http_get_json(url, timeout:)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = timeout
    http.read_timeout = timeout
    req = Net::HTTP::Get.new(uri.request_uri)
    res = http.request(req)
    if res.code.to_i >= 400
      return { error: "HTTP #{res.code}: #{res.body[0, 200]}" }
    end
    JSON.parse(res.body)
  rescue => e
    { error: "#{e.class}: #{e.message[0, 200]}" }
  end

  def mock_publish(content_item, key)
    base = "IG-#{Time.current.to_i}-#{SecureRandom.hex(3)}"
    Result.new(
      ok: true,
      external_id: base,
      external_url: "https://instagram.com/p/#{base}",
      provider: "instagram",
      payload: {
        caption: content_item.body.to_s[0, 2200],
        idempotency_key: key,
        mode: "mock",
        hint: "set META_GRAPH_API_TOKEN + ig_user_id to enable real publishing"
      }
    )
  end
end