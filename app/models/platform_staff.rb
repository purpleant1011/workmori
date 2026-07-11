class PlatformStaff < ApplicationRecord
  self.table_name = "platform_staff"
  has_secure_password

  has_many :platform_sessions, dependent: :destroy
  has_many :audit_events, dependent: :nullify

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase }

  def super_admin?; role == "super_admin"; end
  def staff?; role == "staff"; end
end
