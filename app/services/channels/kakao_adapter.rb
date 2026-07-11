class Channels::KakaoAdapter < Channels::Adapter
  protected
  def publish_internal(channel, content_item, key)
    Result.new(ok: true, external_id: "KAKAO-#{Time.current.to_i}", external_url: "kakao://ch/#{channel.handle}", provider: "kakao_channel", payload: { idempotency_key: key })
  end
  def verify_internal(channel); Result.new(ok: channel.handle.present?, provider: "kakao_channel"); end
end

class Channels::EmailAdapter < Channels::Adapter
  protected
  def publish_internal(channel, content_item, key)
    if channel.handle.to_s.exclude?("@")
      return Result.new(ok: false, error: "Email handle에 '@' 필요 (#{channel.handle})", provider: "email")
    end
    Result.new(ok: true, external_id: "EM-#{Time.current.to_i}", external_url: "mailto:#{channel.handle}", provider: "email", payload: { subject: content_item&.title, body: content_item&.body, idempotency_key: key })
  end
  def verify_internal(channel); Result.new(ok: channel.handle.to_s.include?("@"), provider: "email", error: channel.handle.to_s.include?("@") ? nil : "Email handle에 '@' 필요"); end
end