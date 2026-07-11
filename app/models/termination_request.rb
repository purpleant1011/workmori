class TerminationRequest < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :requested_by_user, class_name: "User", optional: true
  include JsonAttr
  json_attr :revocation_checklist_json, default: ->{ [] }
  json_attr :export_requested_json, default: ->{ [] }
  json_attr :deletion_requested_json, default: ->{ [] }
end
