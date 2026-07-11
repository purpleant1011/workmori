class Incident < ApplicationRecord
  belongs_to :account, optional: true
end
