class PublicationAttempt < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :content_item
  belongs_to :channel_connection, optional: true

  validates :idempotency_key, presence: true, uniqueness: true
end
