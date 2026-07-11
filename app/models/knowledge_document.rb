class KnowledgeDocument < ApplicationRecord
  include AccountScoped

  belongs_to :account
  belongs_to :knowledge_source
  has_many :document_chunks, dependent: :destroy

  validates :version, presence: true
  validates :checksum_sha256, presence: true

  def ready?; status == "indexed"; end
end
