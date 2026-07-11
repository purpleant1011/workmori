# 사업자/관리자용 실시간 알림 채널
# - 새 핸드오프 (handoff 발생)
# - AI 응답 도착
# - 자동화 실행 완료
# - 발행 결과 (성공/실패)
module NotificationsChannel < ApplicationCable::Channel
  def subscribed
    if current_account_id.present?
      stream_from "account:#{current_account_id}:notifications"
    end
  end

  def unsubscribed
    # 자동 cleanup
  end
end