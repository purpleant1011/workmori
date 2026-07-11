module App
  # /app/login 사업자 로그인 (docs/index.html 모달에서 호출)
  # - account_or_email: 이메일 또는 Account slug
  # - 성공 시 app_root로 이동 (사업장 대시보드)
  class SessionsController < ApplicationController
    skip_before_action :require_business_sign_in!, raise: false

    def new
      @account_or_email = params[:account_or_email].to_s
    end

    def create
      raw = params.require(:account_or_email).to_s.strip
      password = params.require(:password).to_s

      # 1) 이메일 또는 슬러그로 user 찾기
      user = User.find_by(email_address: raw)
      user ||= Account.find_by(slug: raw)&.owner_user
      if user.nil? && (acct_fb = Account.find_by(slug: raw))
        user = acct_fb.users.find_by(role: "owner") || acct_fb.users.first
      end

      account = user&.account
      if user&.authenticate(password)
        token = SecureRandom.hex(32)
        Session.create!(user: user, token_hash: token, ip_address: request.remote_ip, user_agent: request.user_agent.to_s[0, 200], last_seen_at: Time.current, expires_at: 30.days.from_now)
        cookies.signed[:workmori_user_token] = { value: token, httponly: true, expires: 30.days.from_now, same_site: :lax }
        AuditEvent.create!(account: user.account, actor_user: user, actor_kind: "user", action: "session.login_success", resource_type: "User", resource_id: user.id, metadata: { ip: request.remote_ip, ua: request.user_agent.to_s[0, 100] }, occurred_at: Time.current)
        redirect_to app_root_path, notice: "로그인되었습니다."
      else
        AuditEvent.create!(
          account: account,
          actor_kind: "system",
          action: "session.login_failed",
          metadata: { ip: request.remote_ip, ua: request.user_agent.to_s[0, 100], account_or_email: raw[0, 100] },
          occurred_at: Time.current
        )
        flash.now[:alert] = "계정/이메일 또는 비밀번호가 올바르지 않습니다."
        render :new, status: :unauthorized
      end
    end

    def destroy
      if (s = user_session)
        s.update!(revoked_at: Time.current)
      end
      cookies.delete(:workmori_user_token)
      redirect_to public_root_path, notice: "로그아웃되었습니다."
    end
  end
end