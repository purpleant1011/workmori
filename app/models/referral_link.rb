class ReferralLink < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :created_by_user, class_name: "User", optional: true
  has_many :referrals, dependent: :destroy
  validates :code, presence: true, uniqueness: true
end
