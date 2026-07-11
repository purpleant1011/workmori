class Referral < ApplicationRecord
  belongs_to :referral_link
  belongs_to :referrer_account, class_name: "Account"
  has_many :referral_rewards, dependent: :destroy
end
