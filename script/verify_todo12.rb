#!/usr/bin/env ruby
# verify_todo12.rb — DataExport / DataExportBuilder / DataExportRetention / DataExportJob
require "net/http"
require "uri"
require "json"
require "csv"
require "zip"

ROOT        = Rails.root
BASE_URL    = "http://127.0.0.1:3001"
COOKIE_JAR  = "/tmp/c_ve12.jar"
LOG_PREFIX  = "[V12]"

def step(n, name)
  puts "#{LOG_PREFIX} [#{n}] #{name}"
  yield
  puts "#{LOG_PREFIX}    ✓ ok"
rescue => e
  puts "#{LOG_PREFIX}    ✗ #{e.class}: #{e.message}"
  puts e.backtrace.first(3).join("\n") if e.backtrace
  exit 1
end

def cookie_header(jar)
  return "" unless File.exist?(jar)
  # Netscape cookie file (curl-style with #HttpOnly_ prefix supported)
  line = `grep -E 'workmori_user_token' #{jar} | grep -vE '^# ' | head -1`.strip
  return "" if line.empty?
  line = line.sub(/^#HttpOnly_/, "")
  parts = line.split("\t")
  return "" if parts.length < 7
  "#{parts[5]}=#{parts[6]}"
end

def http_get(path, jar: COOKIE_JAR)
  uri = URI("#{BASE_URL}#{path}")
  req = Net::HTTP::Get.new(uri)
  ch = cookie_header(jar)
  req["Cookie"] = ch if ch.present?
  Net::HTTP.start(uri.host, uri.port) { |h| h.request(req) }
end

def http_post(path, body, jar: COOKIE_JAR)
  uri = URI("#{BASE_URL}#{path}")
  req = Net::HTTP::Post.new(uri)
  ch = cookie_header(jar)
  req["Cookie"] = ch if ch.present?
  req.set_form_data(body)
  Net::HTTP.start(uri.host, uri.port) { |h| h.request(req) }
end

def http_delete(path, jar: COOKIE_JAR, csrf_form_from: nil)
  uri = URI("#{BASE_URL}#{path}")
  req = Net::HTTP::Delete.new(uri)
  ch = cookie_header(jar)
  req["Cookie"] = ch if ch.present?
  if csrf_form_from
    page = http_get(csrf_form_from, jar: jar)
    forms = page.body.scan(/<form[^>]*action="([^"]+)"[^>]*>(.*?)<\/form>/m)
    target = csrf_form_from
    tok = nil
    forms.each do |act, fbody|
      next unless act == target || act.end_with?(target)
      m = fbody.match(/name="authenticity_token"[^>]*value="([^"]+)"/)
      tok = m[1] if m
      break
    end
    req["X-CSRF-Token"] = tok if tok
  end
  Net::HTTP.start(uri.host, uri.port) { |h| h.request(req) }
end

results = []
def check(name, cond)
  status = cond ? "PASS" : "FAIL"
  puts "  #{status}: #{name}"
  [name, cond]
end

# -------- step 1: dev login business (use curl-style cookie file) --------
step(1, "dev login (business)") do
  File.delete(COOKIE_JAR) if File.exist?(COOKIE_JAR)
  # Use curl to login + store proper Netscape cookie file
  out = `curl -s -c #{COOKIE_JAR} -X POST #{BASE_URL}/dev_login/business -d 'email=owner@demo.example' -o /dev/null -w '%{http_code}'`
  raise "login failed: #{out}" unless out.strip == "200"
  raise "no cookie file" unless File.exist?(COOKIE_JAR) && File.size(COOKIE_JAR) > 0
  # Verify token present
  content = File.read(COOKIE_JAR)
  raise "no workmori_user_token in cookie" unless content.include?("workmori_user_token")
end

# -------- step 2: GET /app/data_exports (index) --------
step(2, "GET /app/data_exports (index)") do
  res = http_get("/app/data_exports")
  raise "expected 200, got #{res.code}" unless res.code == "200"
  body = res.body.dup.force_encoding("UTF-8")
  results << check("index has '데이터 내보내기'", body.include?("데이터 내보내기"))
  results << check("index has kind select", body.include?("종류") && body.include?("형식"))
  results << check("index has CSRF meta", body.include?('name="csrf-token"'))
end

# -------- step 3: POST create (json) --------
step(3, "POST create json full") do
  res = http_post("/app/data_exports", { kind: "full", format: "json" })
  raise "expected 302, got #{res.code} body=#{res.body[0,200]}" unless res.code == "302"
  loc = res["location"] || res["Location"]
  raise "no location" unless loc
  puts "    location: #{loc}"
end

# -------- step 4: POST create (zip) --------
step(4, "POST create zip minimal") do
  res = http_post("/app/data_exports", { kind: "minimal", format: "zip" })
  raise "expected 302, got #{res.code}" unless res.code == "302"
end

# -------- step 5: POST invalid kind --------
step(5, "POST create invalid kind (redirect with alert)") do
  res = http_post("/app/data_exports", { kind: "bad_kind", format: "json" })
  raise "expected 302, got #{res.code}" unless res.code == "302"
end

# -------- step 6: Wait for jobs to complete and verify in DB --------
step(6, "Job completed in DB") do
  sleep 4
  acct = Account.find_by!(slug: "demo-skincare")
  recent = acct.data_export_requests.order(id: :desc).limit(3)
  raise "no recent exports" if recent.empty?
  results << check("most recent is ready or failed", %w[ready failed].include?(recent.first.state))
  results << check("at least 1 json", recent.any? { |r| r.format == "json" })
  results << check("at least 1 zip",  recent.any? { |r| r.format == "zip" })
  ready_count = recent.count(&:downloadable?)
  results << check("at least 2 downloadable", ready_count >= 2)
end

# -------- step 7: Verify file contents --------
step(7, "Files exist & contain expected sections") do
  acct = Account.find_by!(slug: "demo-skincare")
  js = acct.data_export_requests.where(format: "json", state: "ready").order(id: :desc).first
  zp = acct.data_export_requests.where(format: "zip", state: "ready").order(id: :desc).first
  raise "no json ready" unless js
  raise "no zip ready" unless zp
  raise "json file missing: #{js.storage_path}" unless File.exist?(js.storage_path)
  raise "zip file missing: #{zp.storage_path}" unless File.exist?(zp.storage_path)

  json_body = File.read(js.storage_path)
  parsed = JSON.parse(json_body)
  results << check("json has export_meta", parsed["export_meta"].is_a?(Hash))
  results << check("json has tables key", parsed["tables"].is_a?(Hash))
  results << check("json tables include accounts", parsed["tables"].key?("accounts"))
  results << check("json tables include ai_employees", parsed["tables"].key?("ai_employees"))
  results << check("json sha256 matches", js.checksum_sha256 == Digest::SHA256.hexdigest(json_body))

  # Inspect zip
  entries = []
  Zip::File.open(zp.storage_path) do |zip|
    zip.each { |e| entries << e.name }
  end
  results << check("zip has data.json", entries.include?("data.json"))
  results << check("zip has csv/accounts.csv", entries.include?("csv/accounts.csv"))
end

# -------- step 8: GET show detail page --------
step(8, "GET show detail page") do
  acct = Account.find_by!(slug: "demo-skincare")
  rec = acct.data_export_requests.where(state: "ready").order(id: :desc).first
  raise "no ready export" unless rec
  res = http_get("/app/data_exports/#{rec.id}")
  raise "expected 200, got #{res.code}" unless res.code == "200"
  body = res.body.dup.force_encoding("UTF-8")
  results << check("show has '내보내기 상세'", body.include?("내보내기 상세"))
  results << check("show has SHA-256", body.include?("SHA-256"))
  results << check("show has row counts table", body.include?("테이블별 행 수"))
end

# -------- step 9: GET download file --------
step(9, "GET download file") do
  acct = Account.find_by!(slug: "demo-skincare")
  rec = acct.data_export_requests.where(state: "ready").where.not(storage_path: nil).order(id: :desc).first
  raise "no downloadable" unless rec
  res = http_get("/app/data_exports/#{rec.id}/download")
  raise "expected 200, got #{res.code}" unless res.code == "200"
  ct = res["content-type"] || res["Content-Type"]
  results << check("download content-type ok", ct.start_with?("application/") || ct.start_with?("text/"))
  results << check("download body non-empty", res.body.bytesize > 100)
end

# -------- step 10: Retention sweeper --------
step(10, "Retention sweeper") do
  acct = Account.find_by!(slug: "demo-skincare")
  # Pick a current ready export, expire it
  target = acct.data_export_requests.where(state: "ready").order(id: :desc).first
  raise "no target" unless target
  path = target.storage_path
  DataExportRequest.where(id: target.id).update_all(expires_at: 1.day.ago)
  res = DataExportRetention.call
  results << check("retention expired >= 1", res.expired >= 1)
  results << check("retention removed >= 1", res.removed >= 1)
  target.reload
  results << check("target state is expired", target.state == "expired")
  results << check("file deleted", !File.exist?(path))
end

# -------- step 11: Destroy action --------
step(11, "DELETE /app/data_exports/:id") do
  acct = Account.find_by!(slug: "demo-skincare")
  rec = acct.data_export_requests.where(state: "ready").order(id: :desc).first
  raise "no ready to destroy" unless rec
  res = http_delete("/app/data_exports/#{rec.id}", csrf_form_from: "/app/data_exports/#{rec.id}")
  raise "expected 302, got #{res.code}" unless res.code == "302"
  rec.reload
  results << check("destroyed state expired", rec.state == "expired")
end

# -------- step 12: Model validations --------
step(12, "Model validations") do
  r1 = DataExportRequest.new(kind: "bad_kind", format: "json")
  results << check("invalid kind rejected", !r1.valid?)
  r2 = DataExportRequest.new(kind: "full", format: "xml")
  results << check("invalid format rejected", !r2.valid?)
  r3 = DataExportRequest.new(kind: "full", format: "json")
  results << check("valid request (no account) invalid?", !r3.valid?) # requires account
end

# -------- step 13: Filename helper --------
step(13, "Filename helper") do
  r = DataExportRequest.new(account_id: 1, kind: "full", format: "json", id: 99)
  results << check("json filename", r.filename == "workmori_export_a1_full_99.json")
  r.format = "csv"
  results << check("csv filename", r.filename == "workmori_export_a1_full_99.csv")
end

# -------- step 14: file_size_human --------
step(14, "file_size_human") do
  r = DataExportRequest.new
  results << check("nil human", r.file_size_human == "—")
  r.file_size_bytes = 500
  results << check("B human", r.file_size_human == "500 B")
  r.file_size_bytes = 5_000
  results << check("KB human", r.file_size_human.end_with?("KB"))
  r.file_size_bytes = 5_000_000
  results << check("MB human", r.file_size_human.end_with?("MB"))
end

# -------- step 15: row_counts_hash getter/setter --------
step(15, "row_counts_hash") do
  r = DataExportRequest.new
  results << check("default empty", r.row_counts_hash == {})
  r.row_counts_hash = { "x" => 3 }
  results << check("setter stores json", r.row_counts_json.include?("\"x\""))
  r2 = DataExportRequest.new(row_counts_json: '{"a":1}')
  results << check("getter parses", r2.row_counts_hash == { "a" => 1 })
end

# -------- step 16: downloadable? predicate --------
step(16, "downloadable?") do
  r = DataExportRequest.new(state: "ready", storage_path: "/tmp/foo")
  results << check("ready + path → downloadable", r.downloadable?)
  r.state = "failed"
  results << check("failed not downloadable", !r.downloadable?)
  r.state = "ready"; r.expires_at = 1.day.ago
  results << check("expired not downloadable", !r.downloadable?)
end

# -------- step 17: routes registered --------
step(17, "Routes registered") do
  routes = Rails.application.routes.routes.map { |r| "#{r.verb} #{r.path.spec.to_s}" }.join("\n")
  results << check("GET /app/data_exports", routes.include?("/app/data_exports(.:format)"))
  results << check("POST /app/data_exports", routes.include?("POST") && routes.include?("/app/data_exports(.:format)"))
  results << check("GET /app/data_exports/:id/download", routes.include?("/app/data_exports/:id/download(.:format)"))
  results << check("DELETE /app/data_exports/:id", routes.include?("DELETE") && routes.include?("/app/data_exports/:id(.:format)"))
end

# -------- summary --------
puts
total = results.size
passed = results.count { |_, ok| ok }
failed = total - passed
puts "#{LOG_PREFIX} PASS: #{passed} / #{total}"
if failed > 0
  puts "#{LOG_PREFIX} FAILED:"
  results.reject { |_, ok| ok }.each { |n, _| puts "  - #{n}" }
  exit 1
else
  puts "#{LOG_PREFIX} 🎉 todo #12 모든 검증 통과"
end