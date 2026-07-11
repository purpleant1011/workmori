class DocumentChunk < ApplicationRecord
  include AccountScoped

  belongs_to :account
  belongs_to :knowledge_document
  has_one :embedding, dependent: :destroy

  validates :position, presence: true
  validates :content, presence: true
  validates :content_sha256, presence: true

  scope :search_keyword, ->(q) {
    return none if q.blank?
    where("to_tsvector('simple', content) @@ plainto_tsquery('simple', ?)", q.to_s)
  }
end
