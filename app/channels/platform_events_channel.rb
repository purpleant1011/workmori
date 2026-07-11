# 플랫폼 운영자용 글로벌 채널 — 모든 시스템 이벤트
module PlatformEventsChannel < ApplicationCable::Channel
  def subscribed
    if current_account_id.to_s.start_with?("platform:")
      stream_from "platform:events"
    end
  end
end