class Announcement < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :created_by_platform_staff, class_name: "PlatformStaff", optional: true

  KINDS = %w[info warning critical promo internal changelog].freeze
  AUDIENCES = %w[all business_owner platform_staff].freeze
  STATUSES = %w[draft published archived].freeze

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :audience, inclusion: { in: AUDIENCES }
  validates :status, inclusion: { in: STATUSES }

  scope :visible_to_business, -> {
    where(status: "published", audience: %w[all business_owner])
      .where("published_at IS NULL OR published_at <= ?", Time.current)
  }
  scope :for_account, ->(account) {
    visible_to_business.where("account_id IS NULL OR account_id = ?", account&.id)
  }
  scope :recent, -> { order(priority: :desc, published_at: :desc, created_at: :desc) }

  def publish!
    update!(status: "published", published_at: Time.current)
  end

  def archive!
    update!(status: "archived")
  end

  def global?
    account_id.nil?
  end

  def kind_color
    {
      "info" => "blue",
      "warning" => "amber",
      "critical" => "rose",
      "promo" => "emerald",
      "internal" => "slate",
      "changelog" => "indigo"
    }[kind] || "slate"
  end

  def kind_label
    {
      "info" => "안내",
      "warning" => "주의",
      "critical" => "긴급",
      "promo" => "프로모션",
      "internal" => "내부",
      "changelog" => "업데이트"
    }[kind] || "안내"
  end
end