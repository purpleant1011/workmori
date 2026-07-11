class Embedding < ApplicationRecord
  include AccountScoped

  belongs_to :account
  belongs_to :document_chunk

  validates :provider, presence: true
  validates :model_code, presence: true
end
