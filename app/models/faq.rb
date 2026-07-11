class Faq < ApplicationRecord
  include AccountScoped
  include JsonAttr
  json_attr :tags_json, default: ->{ [] }

  belongs_to :account
  belongs_to :ai_employee, optional: true

  validates :question, :answer, presence: true
  validates :risk_level, inclusion: { in: %w[low medium high] }
end
