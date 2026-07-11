class UsageRecord < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :ai_employee, optional: true
  belongs_to :automation_execution, optional: true
  belongs_to :content_item, optional: true
  belongs_to :message, optional: true
end
