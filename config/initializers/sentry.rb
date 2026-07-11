# frozen_string_literal: true

# Sentry — 에러 추적 (무료 tier: 5K events/month)
# DSN이 없으면 자동 비활성화 → 비용 0
# Sentry 가입: https://sentry.io (free developer 계정)
# DSN 발급 후 .env에 SENTRY_DSN= 추가하면 자동 활성화

if ENV["SENTRY_DSN"].present? && ENV["SENTRY_DSN"] != "disabled"
  require "sentry-ruby"
  require "sentry-rails"

  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = Rails.env
    config.release = ENV.fetch("WORKMORI_RELEASE", "workmori@#{Rails.application.class.module_parent_name.downcase}")
    config.send_default_pii = false
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f
    config.profiles_sample_rate = 0.05
    config.enabled_environments = %w[production staging]
    config.excluded_exceptions = [
      "ActiveRecord::RecordNotFound",
      "ActionController::RoutingError",
      "ActionDispatch::HostAuthorization::Error"
    ]
    # ActiveJob 통합
    config.async_event_send_timeout = 5
  end

  Rails.logger.info("[sentry] enabled (env=#{Rails.env}, traces_sample_rate=#{ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', '0.1')})")
else
  Rails.logger.info("[sentry] disabled (SENTRY_DSN not set)")
end