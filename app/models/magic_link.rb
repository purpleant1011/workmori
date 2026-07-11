class MagicLink < ApplicationRecord
  PURPOSE_USER_LOGIN  = "user_login".freeze
  PURPOSE_PLATFORM_LOGIN = "platform_login".freeze
  PURPOSES = [PURPOSE_USER_LOGIN, PURPOSE_PLATFORM_LOGIN].freeze

  validates :email, presence: true
  validates :token_hash, presence: true, uniqueness: true
  validates :purpose, inclusion: { in: PURPOSES }
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current).where(consumed_at: nil) }

  def consume!
    update!(consumed_at: Time.current)
  end

  def consumed?
    consumed_at.present?
  end

  def self.issue!(email:, purpose: PURPOSE_USER_LOGIN, ttl: 30.minutes, ip: nil)
    raw = SecureRandom.urlsafe_base64(32)
    rec = create!(email: email.to_s.downcase.strip, purpose: purpose, token_hash: BCrypt::Password.create(raw),
                  expires_at: ttl.from_now, ip_address: ip)
    [rec, raw]
  end

  def self.verify_and_consume(raw_token, email:, purpose:)
    active.where(email: email.to_s.downcase.strip, purpose: purpose)
          .order(created_at: :desc)
          .detect { |ml| BCrypt::Password.new(ml.token_hash) == raw_token.to_s }
          &.tap { |ml| ml.consume! }
  end
end
