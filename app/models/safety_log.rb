class SafetyLog < ApplicationRecord
  STAGES    = %w[pre_publish post_publish inquiry_reply escalation].freeze
  VERDICTS  = %w[passed blocked needs_review warn].freeze

  belongs_to :account, optional: true
  belongs_to :content_item, optional: true
  belongs_to :conversation, optional: true

  validates :stage, inclusion: { in: STAGES }
  validates :verdict, inclusion: { in: VERDICTS }

  scope :recent, -> { order(created_at: :desc) }
  scope :open,   -> { where(verdict: %w[blocked needs_review warn]) }
end
