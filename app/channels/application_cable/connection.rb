# WorkMori — Application Cable
# 전역 broadcast hub (계정별/사용자별 채널 분리)

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_id, :current_account_id

    def connect
      # 사업자 (Business) 세션
      if (user = session_via_business_cookie)
        self.current_user_id = user.id
        self.current_account_id = user.account_id
        return
      end

      # 플랫폼 운영자 세션
      if (staff = session_via_platform_cookie)
        self.current_user_id = nil
        self.current_account_id = "platform:#{staff.id}"
        return
      end

      # 익명 거부
      reject_unauthorized_connection
    end

    private

    def session_via_business_cookie
      # request.session_cookie는 ActionCable에서 직접 접근 불가 → env에서 찾기
      token = cookies["workmori_user_token"]
      return nil unless token
      sess = Session.find_by(token_hash: token)
      return nil unless sess && !sess.revoked? && sess.expires_at > Time.current
      sess.user
    end

    def session_via_platform_cookie
      token = cookies["workmori_platform_token"]
      return nil unless token
      sess = PlatformSession.find_by(token_hash: token)
      return nil unless sess && !sess.revoked? && sess.expires_at > Time.current
      sess.platform_staff
    end

    def cookies
      @cookies ||= ActionDispatch::Cookies::CookieJar.build(request, {})
    end
  end
end