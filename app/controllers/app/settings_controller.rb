module App
  class SettingsController < BaseController
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
  end
end
