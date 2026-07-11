class App::BaseController < ApplicationController
  layout "app"
  before_action :require_business_sign_in!
  before_action :load_account_context

  private

  def load_account_context
    @current_account = current_account
    @current_business_profile = @current_account.business_profile || @current_account.build_business_profile
    @current_ai_employees = @current_account.ai_employees
    redirect_to new_user_session_path and return unless @current_account
  end

  def render_business_forbidden
    render plain: "권한이 없습니다", status: :forbidden
  end

  def require_owner_or_admin!
    return if @current_account && current_user&.account_id == @current_account.id
    render_business_forbidden
  end

  def require_owner_or_manager!
    return if @current_account && current_user&.account_id == @current_account.id
    render_business_forbidden
  end
end
