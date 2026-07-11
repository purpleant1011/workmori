class ContentItem < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :ai_employee
  belongs_to :automation_rule, optional: true
  belongs_to :target_channel_connection, class_name: "ChannelConnection", optional: true

  # ActiveStorage 첨부 (이미지/동영상/문서)
  has_many_attached :media
  has_many_attached :attachments
  has_many :content_versions, dependent: :destroy
  has_many :publication_attempts, dependent: :destroy
  has_one :approval_request, dependent: :nullify

  STATES = %w[draft generated needs_review approved scheduled published failed archived].freeze
  SAFETY_STATES = %w[unchecked passed needs_review blocked].freeze
  KINDS = %w[feed reel_script blog thread place_post daangn_post cardnews shortform].freeze

  validates :title, presence: true
  validates :state, inclusion: { in: STATES }
  validates :safety_state, inclusion: { in: SAFETY_STATES }
  validates :content_kind, inclusion: { in: KINDS }

  scope :pending_for_review, -> { where(state: %w[generated needs_review]) }
  scope :scheduled, -> { where(state: "scheduled").where("scheduled_at > ?", Time.current) }

  def safety_blocked?
    safety_state == "blocked"
  end
end
