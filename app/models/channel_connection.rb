class ChannelConnection < ApplicationRecord
  include AccountScoped
  include JsonAttr
  json_attr :scopes_json, default: ->{ [] }
  encrypts :encrypted_token if respond_to?(:encrypts)

  belongs_to :account
  belongs_to :ai_employee, optional: true
  belongs_to :connected_by_user, class_name: "User", optional: true
  has_many :channel_scopes, dependent: :destroy

  KINDS = %w[discord instagram threads blog naver_place daangn kakao_channel email mastodon].freeze
  STATUSES = %w[planned ready active paused revoked error].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :connected_by_kind, inclusion: { in: %w[owner operator staff] }

  def ready_for_publish?
    status == "active" && channel_scopes.where(publish_allowed: true).exists?
  end
end
