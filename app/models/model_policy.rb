class ModelPolicy < ApplicationRecord
  belongs_to :account, optional: true
  include JsonAttr
  json_attr :masking_rules_json, default: ->{ [] }
end
