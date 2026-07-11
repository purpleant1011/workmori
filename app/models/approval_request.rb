class ApprovalRequest < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :automation_execution, optional: true
  belongs_to :content_item, optional: true
  belongs_to :requested_from_user, class_name: "User", optional: true
  belongs_to :decided_by_user, class_name: "User", optional: true

  STATES = %w[pending approved rejected expired].freeze

  def approved?; state == "approved"; end
  def pending?; state == "pending"; end
  def rejected?; state == "rejected"; end

  def decide!(decision:, user:, notes: nil)
    update!(
      state: decision,
      decided_by_user: user,
      decided_at: Time.current,
      decision_notes: notes,
    )
  end
end
