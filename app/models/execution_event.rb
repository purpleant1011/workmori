class ExecutionEvent < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :automation_execution
end
