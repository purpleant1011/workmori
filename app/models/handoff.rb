class Handoff < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :conversation
  belongs_to :message, optional: true
  belongs_to :assigned_to_user, class_name: "User", optional: true

  STATES = %w[open acknowledged resolved abandoned].freeze
  validates :reason, presence: true
  validates :state, inclusion: { in: STATES }
end
