class Deposit < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :contract_term, optional: true
  encrypts :refund_bank_info_encrypted if respond_to?(:encrypts)
end
