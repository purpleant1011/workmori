class ReferralReward < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :referral
end
