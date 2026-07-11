class KnowledgeSource < ApplicationRecord
  include AccountScoped
  include JsonAttr
  json_attr :tags_json, default: ->{ [] }

  belongs_to :account
  belongs_to :ai_employee, optional: true
  has_many :knowledge_documents, dependent: :destroy

  # ActiveStorage 첨부 (PDF/문서/이미지)
  has_one_attached :file
  has_many_attached :reference_files

  validates :kind, inclusion: { in: %w[upload text url faq product] }
  validates :status, inclusion: { in: %w[pending processing ready failed disabled] }
end
