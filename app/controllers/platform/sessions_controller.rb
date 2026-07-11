class Platform::SessionsController < ApplicationController
  def new
  end

  def create
    raw = params.require(:email).to_s.strip
    password = params.require(:password).to_s
    staff = PlatformStaff.find_by(email_address: raw)
    if staff && staff.authenticate(password)
      token = SecureRandom.hex(32)
      PlatformSession.create!(platform_staff: staff, token_hash: token, ip: request.remote_ip, user_agent: request.user_agent.to_s[0, 200], last_seen_at: Time.current, expires_at: 24.hours.from_now)
      cookies.signed[:workmori_platform_token] = { value: token, httponly: true, expires: 24.hours.from_now, same_site: :lax, secure: Rails.env.production? }
      redirect_to platform_root_path, notice: "운영자 로그인 되었습니다."
    else
      flash.now[:alert] = "이메일 또는 비밀번호가 올바르지 않습니다."
      render :new, status: :unauthorized
    end
  end

  def destroy
    if (s = platform_session)
      s.update!(revoked_at: Time.current)
    end
    cookies.delete(:workmori_platform_token)
    redirect_to public_root_path, notice: "운영자 로그아웃"
  end
end
