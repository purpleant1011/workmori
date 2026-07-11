class Payment < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :invoice, optional: true
  encrypts :encrypted_metadata if respond_to?(:encrypts)
end
