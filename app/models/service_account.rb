class ServiceAccount < ApplicationRecord
  belongs_to :account, optional: true
  has_many :api_tokens, dependent: :destroy
  has_many :audit_events, dependent: :nullify
end
