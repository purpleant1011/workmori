class DeliveryLog < ApplicationRecord
  include AccountScoped
  belongs_to :account
  KINDS = %w[daily_report weekly_report magic_link campaign welcome reset_password billing automation_summary scheduled_post manual_post inquiry_response system_notice channel_publish].freeze
  validates :kind, inclusion: { in: KINDS }
  validates :subject, presence: true
  validates :recipient_count, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(delivered_at: :desc).limit(50) }
end
