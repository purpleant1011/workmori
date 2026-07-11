#!/usr/bin/env ruby
# Smoke test for DataExportBuilder / DataExportRetention
acct = Account.find_by!(slug: "demo-skincare")
owner = User.find_by(email_address: "owner@demo.example")
DataExportRequest.where(account_id: acct.id).delete_all

puts "[1] JSON full"
r1 = DataExportRequest.create!(
  account: acct, requested_by_user_id: owner.id, requested_at: Time.current,
  state: "pending", kind: "full", format: "json", expires_at: 30.days.from_now
)
DataExportBuilder.call(r1)
puts "  state=#{r1.reload.state} size=#{r1.file_size_bytes} tables=#{r1.row_counts_hash.size} rows_total=#{r1.row_counts_hash.values.sum}"

puts "[2] CSV full (ZIP)"
r2 = DataExportRequest.create!(
  account: acct, requested_by_user_id: owner.id, requested_at: Time.current,
  state: "pending", kind: "full", format: "csv", expires_at: 30.days.from_now
)
DataExportBuilder.call(r2)
puts "  state=#{r2.reload.state} size=#{r2.file_size_bytes} tables=#{r2.row_counts_hash.size}"

puts "[3] ZIP bundle"
r3 = DataExportRequest.create!(
  account: acct, requested_by_user_id: owner.id, requested_at: Time.current,
  state: "pending", kind: "full", format: "zip", expires_at: 30.days.from_now
)
DataExportBuilder.call(r3)
puts "  state=#{r3.reload.state} size=#{r3.file_size_bytes} tables=#{r3.row_counts_hash.size}"

puts "[4] invalid kind"
r4 = DataExportRequest.new(account: acct, kind: "bad_kind", format: "json")
puts "  valid?=#{r4.valid?} errs=#{r4.errors.full_messages.inspect}"

puts "[5] invalid format"
r5 = DataExportRequest.new(account: acct, kind: "full", format: "xml")
puts "  valid?=#{r5.valid?} errs=#{r5.errors.full_messages.inspect}"

puts "[6] retention"
DataExportRequest.where(id: r1.id).update_all(expires_at: 1.day.ago)
res = DataExportRetention.call
puts "  scanned=#{res.scanned} expired=#{res.expired} removed=#{res.removed} bytes=#{res.bytes_reclaimed}"
puts "  r1 after retention: state=#{r1.reload.state} path_exists=#{File.exist?(r1.storage_path || "")}"

puts "[7] File: json content sample"
sample = File.read(r1.storage_path)
puts "  contains export_meta: #{sample.include?('"export_meta"')}"
puts "  contains tables: #{sample.include?('"tables"')}"
puts "  contains accounts: #{sample.include?('"accounts"')}"
puts "  contains ai_employees: #{sample.include?('"ai_employees"')}"
puts "  total bytes: #{sample.bytesize}"