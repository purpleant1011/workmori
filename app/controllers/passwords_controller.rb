class PasswordsController < ApplicationController
  def new
    require_business_sign_in!
  end

  def edit
    require_business_sign_in!
  end

  def update
    require_business_sign_in!
    user = current_user
    if !user.authenticate(params[:current_password].to_s)
      flash.now[:alert] = "현재 비밀번호가 일치하지 않습니다."
      render :edit, status: :unprocessable_entity
    elsif user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      redirect_to app_root_path, notice: "비밀번호가 변경되었습니다."
    else
      flash.now[:alert] = user.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def forgot
  end

  def request_reset
    email = params[:email].to_s.strip
    user = User.find_by(email_address: email)
    if user
      token = SecureRandom.hex(32)
      $redis.setex("workmori:password_reset:#{token}", 30.minutes.to_i, user.id)
      AuditEvent.create!(account: user.account, actor_kind: "user", action: "password.reset.requested", resource_type: "User", resource_id: user.id, payload_json: { delivered: false }, occurred_at: Time.current)
      redirect_to public_root_path, notice: "입력하신 이메일로 안내드립니다. (개발 환경에선 콘솔 로그 확인)"
      Rails.logger.info "[PasswordReset] user=#{user.id} token=#{token}"
    else
      redirect_to public_root_path, notice: "등록된 이메일이 없을 경우 별도 안내가 발송되지 않습니다."
    end
  end
end
