class MediaAsset < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :content_item, optional: true
end
