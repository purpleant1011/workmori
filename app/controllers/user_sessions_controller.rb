class UserSessionsController < ApplicationController
  # Rate limiting: 로그인 시도 5회/분 (브루트포스 방어)
  rate_limit to: 10, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { render_rate_limited }

  def new
    @account_or_email = params[:account_or_email].to_s
  end

  def create
    raw = params.require(:account_or_email).to_s.strip
    password = params.require(:password).to_s
    account = Account.find_by(slug: raw) || User.find_by(email_address: raw)&.account
    user = account&.owner_user
    if user&.authenticate(password)
      start_user_session!(user)
      redirect_to app_root_path, notice: "로그인되었습니다."
    else
      AuditEvent.create!(
        account: account,
        action: "session.login_failed",
        resource_type: "User",
        resource_id: user&.id || 0,
        metadata: { ip: request.remote_ip, ua: request.user_agent.to_s[0, 100], account_or_email: raw[0, 100] },
        occurred_at: Time.current
      )
      flash.now[:alert] = "계정/이메일 또는 비밀번호가 올바르지 않습니다."
      render :new, status: :unauthorized
    end
  end

  def destroy
    close_session!
    redirect_to public_root_path, notice: "로그아웃되었습니다."
  end

  private

  def render_rate_limited
    response.headers["Retry-After"] = "60"
    render plain: "요청이 너무 많습니다. 잠시 후 다시 시도해주세요.", status: :too_many_requests
  end

  def start_user_session!(user)
    token = SecureRandom.hex(32)
    Session.create!(user: user, token_hash: token, ip_address: request.remote_ip, user_agent: request.user_agent.to_s[0, 200], last_seen_at: Time.current, expires_at: 30.days.from_now)
    cookies.signed[:workmori_user_token] = { value: token, httponly: true, expires: 30.days.from_now, same_site: :lax }
    AuditEvent.create!(account: user.account, actor_kind: "user", action: "session.start", resource_type: "User", resource_id: user.id, occurred_at: Time.current)
  end

  def close_session!
    if (s = user_session)
      s.update!(revoked_at: Time.current)
    end
    cookies.delete(:workmori_user_token)
  end
end
