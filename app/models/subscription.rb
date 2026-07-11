class Subscription < ApplicationRecord
  include AccountScoped

  STATES = %w[active paused canceled expired pending].freeze
  BILLING_INTERVAL = 30

  belongs_to :account
  belongs_to :plan
  belongs_to :contract_term, optional: true
  has_many :invoices, foreign_key: :account_id, primary_key: :account_id, dependent: :nullify

  validates :state, inclusion: { in: STATES }
  validates :started_on, presence: true

  before_validation :apply_defaults

  scope :active_for, ->(today = Date.current) {
    where(state: "active").where("current_period_end >= ?", today)
  }

  def active?; state == "active"; end
  def overdue_for_billing?(today = Date.current)
    return false unless active?
    next_billing_on.present? && next_billing_on <= today
  end

  def total_monthly_krw
    (monthly_price_krw || 0) + (monthly_price_vat_krw || 0)
  end

  def advance_period!(today = Date.current)
    new_end = current_period_end + BILLING_INTERVAL
    new_billing = next_billing_on || (new_end + 1.day)
    update!(
      current_period_start: current_period_end + 1,
      current_period_end: new_end,
      next_billing_on: auto_renew? ? new_billing : nil
    )
  end

  private
  def apply_defaults
    self.current_period_start ||= started_on if started_on
    self.current_period_end ||= (started_on + BILLING_INTERVAL) if started_on
    self.next_billing_on ||= current_period_end + 1 if current_period_end
  end
end
