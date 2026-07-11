class DevOverridesController < ActionController::Base
  skip_forgery_protection
  before_action :no_auth_checks

  def platform_login
    email = params.require(:email)
    staff = PlatformStaff.find_by!(email_address: email)
    token = SecureRandom.hex(32)
    PlatformSession.where(platform_staff_id: staff.id).update_all(revoked_at: Time.current)
    PlatformSession.create!(platform_staff_id: staff.id, token_hash: token, expires_at: 24.hours.from_now)
    cookies.signed[:workmori_platform_token] = { value: token, httponly: true, expires: 24.hours.from_now, same_site: :lax }
    render plain: "OK platform token=#{token}", status: :ok
  end

  def business_login
    email = params.require(:email)
    user  = User.find_by!(email_address: email)
    token = SecureRandom.hex(32)
    Session.where(user_id: user.id).update_all(revoked_at: Time.current)
    Session.create!(user_id: user.id, token_hash: token, expires_at: 30.days.from_now)
    cookies.signed[:workmori_user_token] = { value: token, httponly: true, expires: 30.days.from_now, same_site: :lax }
    render plain: "OK business user token=#{token}", status: :ok
  end

  private

  def no_auth_checks
    # noop — dev controller skips auth
  end
end
