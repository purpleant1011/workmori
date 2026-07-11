class AiEmployeeVersion < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :ai_employee
  belongs_to :changed_by_user, class_name: "User", optional: true

  validates :version_number, presence: true, numericality: { greater_than: 0 }
end
