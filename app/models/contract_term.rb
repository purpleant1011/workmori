class ContractTerm < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :plan, optional: true
  has_many :deposits, dependent: :destroy
  has_many :invoices, dependent: :destroy

  STATUSES = %w[draft signed active terminated].freeze
  validates :contract_code, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
end
