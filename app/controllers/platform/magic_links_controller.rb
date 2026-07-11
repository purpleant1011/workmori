module Platform
  class MagicLinksController < ApplicationController
    skip_forgery_protection only: :create

    def create
      email = params[:email].to_s.downcase.strip
      if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
        return render json: { ok: false, error: "invalid_email" }, status: :unprocessable_entity
      end
      staff = PlatformStaff.find_by(email_address: email)
      unless staff
        return render json: { ok: true, hint: "if_email_exists_link_will_be_sent" }
      end
      link, raw = MagicLink.issue!(email: email, purpose: MagicLink::PURPOSE_PLATFORM_LOGIN, ip: request.remote_ip)
      PlatformMailer.magic_link(staff: staff, raw_token: raw, purpose: MagicLink::PURPOSE_PLATFORM_LOGIN).deliver_later
      render json: { ok: true, magic_link_id: link.id, dev_url: dev_only_url(raw, email) }
    end

    def show
      raw = params[:token].to_s
      email = params[:email].to_s
      ml = MagicLink.verify_and_consume(raw, email: email, purpose: MagicLink::PURPOSE_PLATFORM_LOGIN)
      unless ml
        flash[:alert] = "링크가 만료되었거나 이미 사용되었습니다."
        return redirect_to(platform_login_path)
      end
      staff = PlatformStaff.find_by(email_address: ml.email)
      unless staff
        flash[:alert] = "연결된 플랫폼 계정을 찾을 수 없습니다."
        return redirect_to(platform_login_path)
      end
      staff.update_column(:last_login_at, Time.current)
      AuditEvent.create!(action: "platform.login.magic", resource_type: "PlatformStaff", resource_id: staff.id, metadata: { method: "magic_link" }, occurred_at: Time.current)
      session[:platform_staff_id] = staff.id
      redirect_to(platform_root_path, notice: "매직링크로 로그인되었습니다.")
    end

    private

    def dev_only_url(raw, email)
      return nil unless Rails.env.development?
      token = CGI.escape(raw)
      Rails.application.routes.url_helpers.platform_magic_link_url(token: token, email: email, host: request.host_with_port)
    end
  end
end
