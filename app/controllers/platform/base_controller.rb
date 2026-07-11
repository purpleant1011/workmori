class Platform::BaseController < ApplicationController
  layout "platform"
  before_action :require_platform_sign_in!

  private

  def require_platform_sign_in!
    redirect_to main_app.url_for(controller: "platform/sessions", action: "new", only_path: true) unless signed_in_as_platform?
  end
end
