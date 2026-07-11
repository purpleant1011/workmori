class EscalationRule < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :ai_employee, optional: true

  TOPICS = %w[잔흔 피부 시술가능 클레임 가격 환불 민감사정 일반건강].freeze
  validates :topic, presence: true, inclusion: { in: TOPICS, allow_blank: true }
  validates :handoff_channel, inclusion: { in: %w[kakao phone email manual] }
end
