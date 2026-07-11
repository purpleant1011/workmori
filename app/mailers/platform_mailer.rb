class PlatformMailer < ApplicationMailer
  def magic_link(staff:, raw_token:, purpose:)
    @staff = staff
    @raw_token = raw_token
    @purpose = purpose
    addr = staff.respond_to?(:email_address) ? staff.email_address : staff.email
    url = Rails.application.routes.url_helpers.platform_magic_link_url(
      token: raw_token, email: addr, host: default_url_options[:host] || "127.0.0.1:3001"
    )
    @url = url
    @expiry_minutes = 30
    mail to: addr, subject: "[WorkMori] 운영자 매직 링크"
  end
end
