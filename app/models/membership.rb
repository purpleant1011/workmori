class Membership < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :role, inclusion: { in: %w[owner admin reviewer] }

  def owner?; role == "owner"; end
  def reviewer?; role == "reviewer"; end
end
