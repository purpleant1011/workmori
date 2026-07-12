class BusinessProfile < ApplicationRecord
  include AccountScoped
  include JsonAttr

  INDUSTRY_CODE_LABELS = {
    "beauty"  => "💄 뷰티",
    "nail"    => "💅 네일",
    "skin"    => "✨ 피부관리",
    "waxing"  => "🧴 왁싱",
    "brow"    => "👁 눈썹",
    "lash"    => "👁 속눈썹",
    "scalp"   => "💆 두피",
    "food"    => "🍽 외식/카페",
    "retail"  => "🛍 소매",
    "medical" => "🏥 의료",
    "other"   => "기타"
  }.freeze

  def self.industry_code_labels
    INDUSTRY_CODE_LABELS.map { |code, label| [label, code] }
  end

  json_attr :business_hours_json, default: {}
  json_attr :holidays_json, default: ->{ [] }
  json_attr :products_json, default: ->{ [] }
  json_attr :services_json, default: ->{ [] }
  json_attr :faqs_json, default: ->{ [] }
  json_attr :customer_anxieties_json, default: ->{ [] }
  json_attr :forbidden_phrases_json, default: ->{ [] }
  json_attr :forbidden_topics_json, default: ->{ [] }
  json_attr :escalation_rules_json, default: ->{ [] }
  json_attr :preferred_channels_json, default: ->{ [] }
  json_attr :settings_json, default: ->{ {} }

  belongs_to :account

  # ActiveStorage 첨부
  has_one_attached :logo
  has_one_attached :cover_image

  validates :legal_name, presence: true
  validates :industry_code, inclusion: {
    in: %w[beauty nail skin waxing brow lash scalp food retail medical other],
    allow_blank: true,
  }

  def onboarding_progress_percent
    required = %i[legal_name industry_code owner_name phone region_label brand_intro]
    present = required.count { |k| send(k).present? }
    ((present.to_f / required.size) * 100).round
  end

  def forbidden_topics_list
    Array(forbidden_topics_json)
  end

  def faq_items
    Array(faqs_json)
  end
end
