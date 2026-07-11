class DataExportRequest < ApplicationRecord
  include AccountScoped

  KINDS  = %w[full conversations content products knowledge reports billing audit minimal].freeze
  FORMATS = %w[json csv zip].freeze
  STATES = %w[pending running ready failed expired].freeze

  belongs_to :account
  belongs_to :requested_by_user, class_name: "User", optional: true

  validates :kind,   inclusion: { in: KINDS }
  validates :format, inclusion: { in: FORMATS }
  validates :state,  inclusion: { in: STATES }

  scope :pending_or_running, -> { where(state: %w[pending running]) }
  scope :ready_recent,       -> { where(state: "ready").where("ready_at > ?", 30.days.ago) }

  def filters_hash
    return {} if filters_json.blank?
    JSON.parse(filters_json) rescue {}
  end

  def filters_hash=(h)
    self.filters_json = JSON.dump(h || {})
  end

  def row_counts_hash
    return {} if row_counts_json.blank?
    JSON.parse(row_counts_json) rescue {}
  end

  def row_counts_hash=(h)
    self.row_counts_json = JSON.dump(h || {})
  end

  def file_size_human
    return "—" if file_size_bytes.nil? || file_size_bytes.zero?
    if file_size_bytes < 1024
      "#{file_size_bytes} B"
    elsif file_size_bytes < 1024 * 1024
      "#{(file_size_bytes / 1024.0).round(1)} KB"
    else
      "#{(file_size_bytes / (1024.0 * 1024)).round(2)} MB"
    end
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def downloadable?
    state == "ready" && storage_path.present? && !expired?
  end

  def filename
    base = "workmori_export_a#{account_id}_#{kind}_#{id}"
    ext  = format == "json" ? "json" : (format == "csv" ? "csv" : "zip")
    "#{base}.#{ext}"
  end

  def self.kinds_for(account)
    base = %w[full conversations content products knowledge minimal]
    base
  end
end