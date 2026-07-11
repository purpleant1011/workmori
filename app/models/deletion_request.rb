class DeletionRequest < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :requested_by_user, class_name: "User", optional: true
end
