# Threads API 어댑터 (Meta, 2024 출시, 공식)
# 비용 0 — 무료 API, OAuth 2.0 필요
#
# 필요 ENV:
#   THREADS_ACCESS_TOKEN  — long-lived access token
#   THREADS_USER_ID       — Threads numeric user id
#
# 흐름 (텍스트 only):
#   1. POST /{threads-user-id}/threads  (media_type=TEXT, text, ...)
#      → creation_id 응답
#   2. POST /{threads-user-id}/threads_publish  (creation_id)
#      → threads_post_id
#
# 흐름 (이미지):
#   media_type=IMAGE + image_url + text
#
# 흐름 (비디오):
#   media_type=VIDEO + video_url + text
#
# 공식 문서: https://developers.facebook.com/docs/threads

class Channels::ThreadsAdapter < Channels::Adapter
  GRAPH_BASE = "https://graph.threads.net"
  DEFAULT_API_VERSION = "v1.0"

  protected

  def publish_internal(channel, content_item, key)
    token = ENV["THREADS_ACCESS_TOKEN"].to_s
    user_id = ENV["THREADS_USER_ID"].to_s
    api_version = ENV.fetch("THREADS_API_VERSION", DEFAULT_API_VERSION)

    if token.blank? || user_id.blank?
      Rails.logger.warn("[threads] THREADS_ACCESS_TOKEN or THREADS_USER_ID missing → mock fallback")
      return mock_publish(content_item, key)
    end

    media_type = detect_media_type(content_item)
    container_body = {
      media_type: media_type,
      text: content_item.body.to_s[0, 500],
      access_token: token
    }
    if media_type == "IMAGE" && (img = first_published_image_url(content_item))
      container_body[:image_url] = img
    elsif media_type == "VIDEO" && (vid = first_published_video_url(content_item))
      container_body[:video_url] = vid
    end

    # 1) 컨테이너 생성
    container_id = post_container(api_version, user_id, container_body)
    return Result.new(ok: false, error: "container 생성 실패: #{container_id}", provider: "threads") unless container_id

    # 2) 게시
    post_id = post_publish(api_version, user_id, container_id, token)
    if post_id.is_a?(Hash) && post_id[:error]
      return Result.new(ok: false, error: "publish 실패: #{post_id[:error]}", provider: "threads")
    end

    Result.new(
      ok: true,
      external_id: post_id,
      external_url: "https://www.threads.net/@#{channel.handle.to_s.delete('@')}/post/#{post_id}",
      provider: "threads",
      payload: {
        text: content_item.body.to_s[0, 500],
        media_type: media_type,
        threads_post_id: post_id,
        idempotency_key: key
      }
    )
  rescue => e
    Result.new(ok: false, error: "Threads 어댑터 예외: #{e.class}: #{e.message[0,200]}", provider: "threads")
  end

  def verify_internal(channel)
    token = ENV["THREADS_ACCESS_TOKEN"].to_s
    user_id = ENV["THREADS_USER_ID"].to_s
    return Result.new(ok: false, error: "THREADS_ACCESS_TOKEN or THREADS_USER_ID missing", provider: "threads") if token.blank? || user_id.blank?

    api_version = ENV.fetch("THREADS_API_VERSION", DEFAULT_API_VERSION)
    url = "#{GRAPH_BASE}/#{api_version}/#{user_id}?fields=id,username&access_token=#{token}"
    res = http_get_json(url, timeout: 10)
    if res[:error]
      Result.new(ok: false, error: res[:error], provider: "threads")
    else
      Result.new(ok: true, provider: "threads", payload: { threads_user_id: res[:id], username: res[:username] })
    end
  end

  private

  def detect_media_type(content_item)
    return "TEXT" unless content_item.respond_to?(:media) && content_item.media.attached?
    blob = content_item.media.first
    return "TEXT" unless blob
    ct = blob.content_type.to_s
    return "VIDEO" if ct.start_with?("video/")
    return "IMAGE" if ct.start_with?("image/")
    "TEXT"
  end

  def first_published_image_url(content_item)
    blob = content_item.media.find { |b| b.content_type.to_s.start_with?("image/") }
    return nil unless blob
    Rails.application.routes.url_helpers.rails_blob_url(blob, host: ENV.fetch("PUBLIC_HOST", "127.0.0.1:3001"), protocol: ENV.fetch("PUBLIC_PROTOCOL", "http"))
  end

  def first_published_video_url(content_item)
    blob = content_item.media.find { |b| b.content_type.to_s.start_with?("video/") }
    return nil unless blob
    Rails.application.routes.url_helpers.rails_blob_url(blob, host: ENV.fetch("PUBLIC_HOST", "127.0.0.1:3001"), protocol: ENV.fetch("PUBLIC_PROTOCOL", "http"))
  end

  def post_container(api_version, user_id, body)
    url = "#{GRAPH_BASE}/#{api_version}/#{user_id}/threads"
    res = http_post_form(url, body, timeout: 30)
    return res[:error] if res[:error]
    res[:id]
  end

  def post_publish(api_version, user_id, creation_id, token)
    url = "#{GRAPH_BASE}/#{api_version}/#{user_id}/threads_publish"
    http_post_form(url, { creation_id: creation_id, access_token: token }, timeout: 30)
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
    base = "T-#{Time.current.to_i}-#{SecureRandom.hex(3)}"
    Result.new(
      ok: true,
      external_id: base,
      external_url: "https://www.threads.net/@#{content_item.account.handle.to_s.delete('@')}/post/#{base}",
      provider: "threads",
      payload: {
        text: content_item.body.to_s[0, 500],
        idempotency_key: key,
        mode: "mock",
        hint: "set THREADS_ACCESS_TOKEN + THREADS_USER_ID to enable real publishing"
      }
    )
  end
end