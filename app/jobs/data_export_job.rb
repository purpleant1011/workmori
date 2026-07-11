# frozen_string_literal: true

class DataExportJob < ApplicationJob
  queue_as :default

  def perform(data_export_request_id)
    req = DataExportRequest.find_by(id: data_export_request_id)
    return unless req
    return if %w[ready running].include?(req.state)

    DataExportBuilder.call(req)
  rescue => e
    req&.update(state: "failed", error_message: e.message[0, 1000])
    Rails.logger.error("[DataExportJob] failed for #{data_export_request_id}: #{e.class}: #{e.message}")
    raise
  end
end