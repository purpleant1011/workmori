class AutomationExecution < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :automation_rule
  belongs_to :ai_employee
  has_many :execution_events, dependent: :destroy

  STATES = %i[
    draft ready queued claimed running awaiting_approval
    approved publishing succeeded
    retry_scheduled failed cancelled paused quarantined expired
  ].freeze

  validates :idempotency_key, presence: true, uniqueness: true
  validates :state, presence: true

  scope :due_now, -> { where(state: %w[ready queued retry_scheduled]).where("scheduled_at <= ?", Time.current) }

  def transition!(new_state, actor: nil, message: nil)
    update!(state: new_state.to_s)
    execution_events.create!(
      account_id: account_id,
      event_type: "state_change",
      message: message || "-> #{new_state}",
      actor_kind: actor.is_a?(User) ? "user" : (actor || "system"),
    )
  end

  def succeeded?; state.to_s == "succeeded"; end
  def failed?;    state.to_s == "failed"; end
  def running?;   state.to_s == "running"; end
end
