# frozen_string_literal: true

# Periodically delete expired export files (storage_path on disk) and mark rows expired.
class DataExportRetention
  Result = Struct.new(:scanned, :expired, :removed, :bytes_reclaimed, keyword_init: true)

  def self.call(now: Time.current)
    new(now).call
  end

  def initialize(now)
    @now = now
  end

  def call
    scanned = 0
    expired = 0
    removed = 0
    bytes_reclaimed = 0

    DataExportRequest.where.not(state: "expired").find_each(batch_size: 100) do |req|
      scanned += 1
      next unless req.expires_at.present? && req.expires_at < @now

      expired += 1
      if req.storage_path.present? && File.exist?(req.storage_path)
        bytes_reclaimed += File.size(req.storage_path)
        File.delete(req.storage_path)
        removed += 1
      end
      req.update!(state: "expired", storage_path: nil)
    end

    Result.new(scanned: scanned, expired: expired, removed: removed, bytes_reclaimed: bytes_reclaimed)
  end
end