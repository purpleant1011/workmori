class ModelCatalogEntry < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :provider, :kind, presence: true

  scope :active, -> { where(active: true) }

  def api_options
    capabilities.presence || {}
  end
end
