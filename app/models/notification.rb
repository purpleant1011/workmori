class Notification < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :user, optional: true
  belongs_to :platform_staff, optional: true
end
