class ApiToken < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :service_account, optional: true
  belongs_to :user, optional: true

  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.digest_for(raw)
    require "digest"
    Digest::SHA256.hexdigest(raw.to_s)
  end

  def self.find_by_raw(raw)
    active.find_by(token_digest: digest_for(raw))
  end

  def touch_usage!(ip)
    update_columns(last_used_at: Time.current, last_used_ip: ip)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def masked_value
    "#{token_prefix}••••••••"
  end
end
