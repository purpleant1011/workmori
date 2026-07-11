class ChannelScope < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :channel_connection
  validates :scope, presence: true
end
