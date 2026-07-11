class ContentVersion < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :content_item
  belongs_to :changed_by_user, class_name: "User", optional: true
end
