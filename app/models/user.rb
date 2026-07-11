class User < ApplicationRecord
  has_secure_password

  belongs_to :account
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy

  validates :email_address, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :email_address, format: { with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/ }
  validates :role, inclusion: { in: %w[owner operator reviewer] }

  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase }

  def display_name
    name.presence || email_address.split("@").first
  end
end
