class PromptTemplate < ApplicationRecord
  validates :name, :version, presence: true
  validates :name, uniqueness: { scope: :version }
end
