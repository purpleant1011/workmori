# frozen_string_literal: true

require "csv"
require "json"
require "fileutils"
require "digest"
require "zip"

# Builds a full export payload for a given Account and writes it to a local file.
# Formats: json (single JSON document), csv (ZIP archive of CSVs), zip (JSON bundle + CSVs).
class DataExportBuilder
  Result = Struct.new(:path, :size_bytes, :row_counts, :checksum, keyword_init: true)

  EXPORT_TABLES = {
    "accounts"          => ->(acct) { [acct] },
    "ai_employees"      => ->(acct) { acct.ai_employees.order(:id) },
    "products"          => ->(acct) { acct.products.order(:id) },
    "services"          => ->(acct) { acct.services.order(:id) },
    "faqs"              => ->(acct) { acct.faqs.order(:id) },
    "knowledge_sources" => ->(acct) { acct.knowledge_sources.order(:id) },
    "knowledge_documents" => ->(acct) { KnowledgeDocument.where(knowledge_source_id: acct.knowledge_sources.select(:id)).order(:id) },
    "conversations"     => ->(acct) { acct.conversations.order(:id) },
    "messages"          => ->(acct) { Message.where(conversation_id: acct.conversations.select(:id)).order(:id) },
    "content_items"     => ->(acct) { acct.content_items.order(:id) },
    "publication_attempts" => ->(acct) {
      PublicationAttempt.where(content_item_id: acct.content_items.select(:id)).order(:id)
    },
    "csat_responses"    => ->(acct) { acct.csat_responses.order(:id) },
    "delivery_logs"     => ->(acct) { DeliveryLog.where(account_id: acct.id).order(:id) },
    "channel_connections" => ->(acct) { acct.channel_connections.order(:id) },
    "automation_rules"  => ->(acct) { acct.automation_rules.order(:id) },
    "audit_events"      => ->(acct) { AuditEvent.where(account_id: acct.id).order(:id) },
    "subscriptions"     => ->(acct) { acct.subscriptions.order(:id) },
    "invoices"          => ->(acct) { acct.invoices.order(:id) },
    "payments"          => ->(acct) { Payment.where(account_id: acct.id).order(:id) },
    "contract_terms"    => ->(acct) { ContractTerm.where(account_id: acct.id).order(:id) }
  }.freeze

  KIND_TABLES = {
    "minimal"      => %w[accounts ai_employees],
    "conversations"=> %w[accounts conversations messages],
    "content"      => %w[accounts content_items publication_attempts csat_responses],
    "products"     => %w[accounts products services],
    "knowledge"    => %w[accounts knowledge_sources knowledge_documents faqs],
    "reports"      => %w[accounts delivery_logs audit_events csat_responses],
    "billing"      => %w[accounts subscriptions invoices payments contract_terms],
    "audit"        => %w[accounts audit_events delivery_logs],
    "full"         => EXPORT_TABLES.keys
  }.freeze

  def self.call(request)
    new(request).call
  end

  def initialize(request)
    @request    = request
    @account    = request.account
    @kind       = request.kind || "full"
    @format     = request.format || "json"
    @filters    = request.filters_hash || {}
    @out_dir    = Rails.root.join("storage", "exports", "account_#{@account.id}")
    FileUtils.mkdir_p(@out_dir)
  end

  def call
    @request.update!(state: "running", started_at: Time.current, error_message: nil)

    tables = KIND_TABLES[@kind] || KIND_TABLES["full"]
    payload = build_payload(tables)

    case @format
    when "json" then write_json(payload)
    when "csv"  then write_csv_archive(tables, payload)
    when "zip"  then write_zip_archive(tables, payload)
    else raise ArgumentError, "Unknown format: #{@format}"
    end
  end

  def build_payload(tables)
    payload = {
      "export_meta" => {
        "export_kind"      => @kind,
        "export_format"    => @format,
        "account_id"       => @account.id,
        "account_name"     => @account.name,
        "requested_at"     => @request.requested_at&.iso8601 || Time.current.iso8601,
        "requested_by"     => @request.requested_by_user&.email_address,
        "filters"          => @filters,
        "app_version"      => "WorkMori-0.1.0"
      },
      "tables" => {}
    }

    tables.each do |tname|
      rows = Array(EXPORT_TABLES[tname]&.call(@account))
      payload["tables"][tname] = rows.map { |r| serialize_row(r) }
    end

    payload
  end

  # Serialize a row with whitelist of attributes + jsonb fields.
  def serialize_row(rec)
    h = rec.attributes.dup
    # Convert jsonb columns from raw string to Hash when possible
    rec.class.columns_hash.each do |col_name, col|
      next unless %w[jsonb json].include?(col.type.to_s)
      raw = rec[col_name]
      next if raw.nil?
      h[col_name] = (JSON.parse(raw) rescue raw)
    end
    h["created_at"] = rec.created_at&.iso8601
    h["updated_at"] = rec.updated_at&.iso8601
    h
  end

  def write_json(payload)
    json_str = JSON.pretty_generate(payload)
    path = @out_dir.join(@request.filename)
    File.write(path, json_str)

    row_counts = payload["tables"].transform_values(&:length)
    finalize!(path, row_counts)
  end

  def write_csv_archive(tables, payload)
    tmp_zip = @out_dir.join("#{@request.filename}.tmp.zip")
    final   = @out_dir.join(@request.filename)
    row_counts = {}

    Zip::File.open(tmp_zip, create: true) do |zip|
      tables.each do |tname|
        rows = payload["tables"][tname] || []
        row_counts[tname] = rows.length

        csv_str = CSV.generate do |csv|
          keys = collect_keys(rows)
          csv << keys
          rows.each do |row|
            csv << keys.map { |k| stringify(row[k]) }
          end
        end

        zip.get_output_stream("#{tname}.csv") { |f| f.write(csv_str) }
      end

      # Manifest
      manifest = {
        "export_meta" => payload["export_meta"],
        "row_counts"  => row_counts
      }
      zip.get_output_stream("manifest.json") { |f| f.write(JSON.pretty_generate(manifest)) }
    end

    File.rename(tmp_zip, final)
    finalize!(final, row_counts)
  end

  def write_zip_archive(tables, payload)
    tmp_zip = @out_dir.join("#{@request.filename}.tmp.zip")
    final   = @out_dir.join(@request.filename)

    Zip::File.open(tmp_zip, create: true) do |zip|
      zip.get_output_stream("data.json") { |f| f.write(JSON.pretty_generate(payload)) }

      tables.each do |tname|
        rows = payload["tables"][tname] || []
        csv_str = CSV.generate do |csv|
          keys = collect_keys(rows)
          csv << keys
          rows.each do |row|
            csv << keys.map { |k| stringify(row[k]) }
          end
        end
        zip.get_output_stream("csv/#{tname}.csv") { |f| f.write(csv_str) }
      end
    end

    File.rename(tmp_zip, final)
    finalize!(final, payload["tables"].transform_values(&:length))
  end

  def collect_keys(rows)
    seen = []
    rows.each do |r|
      r.keys.each { |k| seen << k unless seen.include?(k) }
    end
    seen
  end

  def stringify(v)
    case v
    when nil then ""
    when Hash, Array then JSON.dump(v)
    when Time then v.iso8601
    else v.to_s
    end
  end

  def finalize!(path, row_counts)
    size = File.size(path)
    checksum = Digest::SHA256.hexdigest(File.read(path))
    @request.update!(
      state: "ready",
      ready_at: Time.current,
      storage_path: path.to_s,
      file_size_bytes: size,
      row_counts_hash: row_counts,
      checksum_sha256: checksum,
      expires_at: 30.days.from_now,
      error_message: nil
    )
    Result.new(path: path.to_s, size_bytes: size, row_counts: row_counts, checksum: checksum)
  rescue => e
    @request.update!(state: "failed", error_message: e.message[0, 1000])
    raise
  end
end