class UserMailer < ApplicationMailer
  def magic_link(user:, raw_token:, purpose:)
    @user = user
    @raw_token = raw_token
    @purpose = purpose
    addr = user.respond_to?(:email_address) ? user.email_address : user.email
    url = Rails.application.routes.url_helpers.user_magic_link_url(
      token: raw_token, email: addr, host: default_url_options[:host] || "127.0.0.1:3001"
    )
    @url = url
    @expiry_minutes = 30
    mail to: addr, subject: "[WorkMori] 매직 링크로 로그인"
  end
end
