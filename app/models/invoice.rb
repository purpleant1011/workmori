class Invoice < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :contract_term, optional: true
  has_many :payments, dependent: :nullify

  STATES = %w[draft issued paid overdue void].freeze
  validates :invoice_number, presence: true, uniqueness: true
  validates :state, inclusion: { in: STATES }
end
