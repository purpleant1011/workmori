class Plan < ApplicationRecord
  validates :code, presence: true, uniqueness: true
end
