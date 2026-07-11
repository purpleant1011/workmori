class CsatResponse < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :conversation, optional: true

  SCORE_RANGE = 1..5

  validates :score, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :channel, presence: true
  validates :respondent_kind, inclusion: { in: %w[customer internal] }

  scope :recent, ->(days = 7) { where("created_at >= ?", days.days.ago) }
end