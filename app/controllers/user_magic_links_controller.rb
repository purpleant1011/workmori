class UserMagicLinksController < ApplicationController
  skip_forgery_protection only: :create

  # 매직링크 발급: IP당 5회/시간 (스팸 방지)
  rate_limit to: 5, within: 1.hour, only: :create, by: -> { request.remote_ip }, with: -> { render json: { ok: false, error: "rate_limited" }, status: :too_many_requests }

  def new
    @email = params[:email].to_s
  end

  def create
    email = params[:email].to_s.downcase.strip
    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      return render json: { ok: false, error: "invalid_email" }, status: :unprocessable_entity
    end
    user = User.find_by(email_address: email)
    unless user
      # Don't leak existence — pretend issuance succeeded.
      return render json: { ok: true, hint: "if_email_exists_link_will_be_sent" }
    end
    link, raw = MagicLink.issue!(email: email, purpose: MagicLink::PURPOSE_USER_LOGIN, ip: request.remote_ip)
    UserMailer.magic_link(user: user, raw_token: raw, purpose: MagicLink::PURPOSE_USER_LOGIN).deliver_later
    render json: { ok: true, magic_link_id: link.id, dev_url: dev_only_url(raw, email, MagicLink::PURPOSE_USER_LOGIN) }
  end

  def show
    raw   = params[:token].to_s
    email = params[:email].to_s
    purpose = MagicLink::PURPOSE_USER_LOGIN
    ml = MagicLink.verify_and_consume(raw, email: email, purpose: purpose)
    unless ml
      flash[:alert] = "링크가 만료되었거나 이미 사용되었습니다."
      return redirect_to(new_user_session_path)
    end
    user = User.find_by(email_address: ml.email)
    unless user
      flash[:alert] = "연결된 사용자 계정을 찾을 수 없습니다."
      return redirect_to(new_user_session_path)
    end
    user.update_column(:last_login_at, Time.current)
    AuditEvent.create!(account: user.account, action: "user.login.magic", resource_type: "User", resource_id: user.id, metadata: { method: "magic_link" }, occurred_at: Time.current)
    session[:user_id] = user.id
    session[:account_id] = user.account_id
    redirect_to(app_root_path, notice: "매직링크로 로그인되었습니다.")
  end

  private

  def dev_only_url(raw, email, purpose)
    return nil unless Rails.env.development?
    token = CGI.escape(raw)
    Rails.application.routes.url_helpers.user_magic_link_url(token: token, email: email, host: request.host_with_port)
  end
end
