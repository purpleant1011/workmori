class Inquiry < ApplicationRecord
  SUBJECT_KINDS = %w[general onboarding pricing security legal other].freeze
  STATUSES = %w[new classified contacted closed].freeze

  validates :name, :email, :subject, :body, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }

  def classify!(kind:, score:)
    update!(subject_kind: kind, score: score, status: "classified")
  end
end
