class IndustryTemplate < ApplicationRecord
  validates :industry_code, :version, presence: true
  validates :industry_code, uniqueness: { scope: :version }

  scope :active, -> { all.order(:industry_code) }

  def to_param = "#{id}-#{industry_code&.parameterize}"
end
