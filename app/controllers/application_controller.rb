class ApplicationController < ActionController::Base
  helper_method :brand
  helper_method :current_user, :signed_in?, :current_account, :current_platform_staff
  helper_method :signed_in_as_business?, :signed_in_as_platform?

  before_action :set_locale

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ApplicationPolicy::Forbidden, with: :render_forbidden

  private

  def brand
    @brand ||= BrandConfig.instance
  end

  def set_locale
    I18n.locale = %w[ko en].include?(params[:locale]) ? params[:locale] : (current_user&.locale.presence || I18n.default_locale)
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = user_session&.user&.tap { |u| u.touch(:last_login_at) rescue nil }
  end

  def current_account
    current_user&.account
  end

  def current_platform_staff
    return @current_platform_staff if defined?(@current_platform_staff)
    @current_platform_staff = platform_session&.platform_staff
  end

  def user_session
    return nil unless cookies.signed[:workmori_user_token].present?
    Session.find_by(token_hash: cookies.signed[:workmori_user_token])
  end

  def platform_session
    return nil unless cookies.signed[:workmori_platform_token].present?
    PlatformSession.find_by(token_hash: cookies.signed[:workmori_platform_token])
  end

  def signed_in?
    current_user.present?
  end

  def signed_in_as_business?
    signed_in?
  end

  def signed_in_as_platform?
    current_platform_staff.present?
  end

  def require_business_sign_in!
    unless signed_in?
      redirect_to new_user_session_path, alert: "로그인이 필요합니다."
    end
  end

  def require_platform_sign_in!
    unless signed_in_as_platform?
      redirect_to new_platform_session_path, alert: "운영자 로그인이 필요합니다."
    end
  end

  def require_platform_super_admin!
    require_platform_sign_in!
    unless current_platform_staff&.super_admin?
      render_forbidden
    end
  end

  def render_not_found
    render "public/errors/not_found", status: :not_found
  end

  def render_forbidden
    render "public/errors/forbidden", status: :forbidden
  end
end
