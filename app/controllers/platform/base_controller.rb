class Platform::BaseController < ApplicationController
  layout "platform"
  before_action :require_platform_sign_in!

  private

  def require_platform_sign_in!
    redirect_to platform_login_path unless signed_in_as_platform?
  end
end
