class GuardrailPolicy < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :ai_employee

  validates :kind, inclusion: { in: %w[forbidden_phrase forbidden_topic must_handoff pricing_claim guarantee_no_risk] }
  validates :severity, inclusion: { in: %w[block warn handoff] }

  KINDS = {
    forbidden_phrase: "특정 표현 차단",
    forbidden_topic: "특정 주제 차단",
    must_handoff: "사람 연결",
    pricing_claim: "가격 단정 차단",
    guarantee_no_risk: "완벽/무조건 표현 차단",
  }.freeze
end
