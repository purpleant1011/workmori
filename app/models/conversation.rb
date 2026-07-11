class Conversation < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :ai_employee
  belongs_to :channel_connection, optional: true

  has_many :conversation_participants, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :handoffs, dependent: :destroy

  STATES = %w[open escalated closed].freeze
  RISK_LEVELS = %w[low medium high].freeze

  validates :channel_kind, presence: true
  validates :state, inclusion: { in: STATES }
  validates :risk_level, inclusion: { in: RISK_LEVELS }
end
