class FeatureFlag < ApplicationRecord
  belongs_to :account, optional: true
end
