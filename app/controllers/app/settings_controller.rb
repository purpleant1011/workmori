module App
  class SettingsController < BaseController
    MIN_PASSWORD_LENGTH = 8

    def show
      @settings = @current_account.settings_json
    end

    def update
      current = @current_account.settings_json || {}
      new_settings = params.fetch(:account, {}).fetch(:settings_json, {})
      current.merge!(new_settings)
      @current_account.update(settings_json: current)
      redirect_to app_settings_path, notice: "설정이 저장되었습니다."
    end

    # === 비밀번호 변경 ===
    def password
    end

    def update_password
      user = current_user
      current_pw = params.dig(:password_form, :current_password).to_s
      new_pw     = params.dig(:password_form, :new_password).to_s
      new_pw_cf  = params.dig(:password_form, :new_password_confirmation).to_s

      if current_pw.blank? || !user&.authenticate(current_pw)
        flash.now[:alert] = "현재 비밀번호가 일치하지 않습니다."
        return render :password, status: :unprocessable_entity
      end

      if new_pw.length < MIN_PASSWORD_LENGTH
        flash.now[:alert] = "새 비밀번호는 최소 #{MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
        return render :password, status: :unprocessable_entity
      end

      if new_pw != new_pw_cf
        flash.now[:alert] = "새 비밀번호와 확인 입력이 일치하지 않습니다."
        return render :password, status: :unprocessable_entity
      end

      if new_pw == current_pw
        flash.now[:alert] = "현재 비밀번호와 다른 새 비밀번호를 입력해 주세요."
        return render :password, status: :unprocessable_entity
      end

      if user.update(password: new_pw, password_confirmation: new_pw_cf)
        AuditEvent.create!(
          account: @current_account,
          actor_user: user,
          actor_kind: "user",
          action: "owner.password.changed",
          metadata: { changed_by: "self", login: user.email_address },
          occurred_at: Time.current
        )
        redirect_to app_settings_password_path, notice: "비밀번호가 변경되었습니다."
      else
        flash.now[:alert] = user.errors.full_messages.to_sentence.presence || "비밀번호 변경에 실패했습니다."
        render :password, status: :unprocessable_entity
      end
    end
  end
end
