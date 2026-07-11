class Product < ApplicationRecord
  include AccountScoped
  belongs_to :account
  validates :name, presence: true
end
