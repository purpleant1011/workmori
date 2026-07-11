class WebhookEndpoint < ApplicationRecord
  include AccountScoped
  belongs_to :account
end
