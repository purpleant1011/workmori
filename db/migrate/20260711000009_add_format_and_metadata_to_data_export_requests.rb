class AddFormatAndMetadataToDataExportRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :data_export_requests, :format, :string, default: "json", null: false
    add_column :data_export_requests, :kind, :string, default: "full"
    add_column :data_export_requests, :filters_json, :text
    add_column :data_export_requests, :file_size_bytes, :bigint
    add_column :data_export_requests, :row_counts_json, :text
    add_column :data_export_requests, :checksum_sha256, :string
    add_column :data_export_requests, :requested_at, :datetime
    add_column :data_export_requests, :started_at, :datetime
    add_column :data_export_requests, :error_message, :text
    add_index  :data_export_requests, :state
    add_index  :data_export_requests, :format
  end
end