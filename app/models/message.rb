class Message < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :conversation

  validates :body, presence: true
  validates :direction, inclusion: { in: %w[inbound outbound] }
  validates :author_kind, inclusion: { in: %w[customer ai operator] }
  validates :state, inclusion: { in: %w[received drafted sent escalated failed] }
end
