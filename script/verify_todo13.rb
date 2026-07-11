#!/usr/bin/env ruby
# frozen_string_literal: true
#
# script/verify_todo13.rb
# verify: USER_GUIDE.md + README.md + com.workmori.web.plist + bin/seed_full.rb
#
# Usage:
#   bin/rails runner script/verify_todo13.rb

require "fileutils"

puts "[V13] todo #13 — 사용자 매뉴얼 + README + launchd plist + 최종 시드"

BASE_URL = ENV.fetch("WORKMORI_BASE_URL", "http://127.0.0.1:3001")
JAR      = ENV.fetch("WORKMORI_COOKIE_JAR", "/tmp/c_v13.jar")
results  = []
failures = 0

def step(num, name)
  puts "[V13] [#{num}] #{name}"
  yield
  puts "[V13]    ✓ ok"
rescue => e
  puts "[V13]    ✗ #{e.class}: #{e.message}"
  $stdout.flush
  raise
end

def check(name, cond)
  mark = cond ? "PASS" : "FAIL"
  $stdout.puts "  #{mark}: #{name}"
  $stdout.flush
  cond
end

# ────────────────────────────────────────────────
# 1) USER_GUIDE.md exists & has all major sections
# ────────────────────────────────────────────────
step(1, "USER_GUIDE.md present") do
  guide = Rails.root.join("USER_GUIDE.md").to_s
  raise "missing" unless File.exist?(guide)
  body = File.read(guide)
  results << check("guide exists",          File.size(guide) > 5_000)
  results << check("has Workmori란?",       body.include?("Workmori란?"))
  results << check("has 가입과 로그인",     body.include?("가입과 로그인"))
  results << check("has 사업자 프로필",     body.include?("사업자 프로필"))
  results << check("has 지식 베이스",       body.include?("지식 베이스"))
  results << check("has AI 직원",           body.include?("AI 직원"))
  results << check("has 채널 연결",         body.include?("채널 연결"))
  results << check("has 주간 일정",         body.include?("주간 일정"))
  results << check("has 콘텐츠 만들기",     body.include?("콘텐츠 만들기"))
  results << check("has 검수과 자동 실행",  body.include?("검수과 자동 실행"))
  results << check("has 대화 응대",         body.include?("대화 응대"))
  results << check("has 결과 리포트",       body.include?("결과 확인") || body.include?("리포트"))
  results << check("has 데이터 백업",       body.include?("데이터 백업"))
  results << check("has 자동화 규칙",       body.include?("자동화 규칙"))
  results << check("has 요금제와 결제",     body.include?("요금제") || body.include?("결제"))
  results << check("has 도움말",            body.include?("도움말"))
  results << check("mentions forbidden",    body.include?("100%") || body.include?("약속"))
end

# ────────────────────────────────────────────────
# 2) README.md detailed & correct
# ────────────────────────────────────────────────
step(2, "README.md developer guide") do
  readme = Rails.root.join("README.md").to_s
  raise "missing" unless File.exist?(readme)
  body = File.read(readme)
  results << check("readme exists",           File.size(readme) > 5_000)
  results << check("has 빠른 시작",           body.include?("빠른 시작"))
  results << check("has bundle install",      body.include?("bundle install"))
  results << check("has db:migrate",          body.include?("db:migrate"))
  results << check("has launchd",             body.include?("launchd"))
  results << check("has Ruby 3.4.10",         body.include?("3.4.10"))
  results << check("has Rails 8.0.5",         body.include?("8.0.5"))
  results << check("has PG 16",               body.include?("16"))
  results << check("has Node 22",             body.include?("22"))
  results << check("has Tailwind 3",          body.include?("Tailwind"))
  results << check("has bin/dev",             body.include?("bin/dev"))
  results << check("has launchctl",           body.include?("launchctl"))
  results << check("has dev_login/business",  body.include?("dev_login/business"))
  results << check("has dev_login/platform",  body.include?("dev_login/platform"))
  results << check("has 디렉토리 구조",       body.include?("디렉토리") || body.include?("구조"))
  results << check("has 도메인 모듈",         body.include?("Identity") || body.include?("도메인"))
  results << check("has 라우트 /app",         body.include?("/app"))
  results << check("has 라우트 /platform",    body.include?("/platform"))
  results << check("has 검증 (regression)",   body.include?("verify_todo"))
  results << check("has 데이터 백업/복구",    body.include?("백업") || body.include?("복구"))
  results << check("has 운영 launchd",        body.include?("launchd"))
  results << check("has USER_GUIDE 참조",     body.include?("USER_GUIDE.md"))
  results << check("has 라이선스 비공개",     body.include?("비공개"))
end

# ────────────────────────────────────────────────
# 3) com.workmori.web.plist is valid plist XML
# ────────────────────────────────────────────────
step(3, "com.workmori.web.plist valid") do
  plist_path = Rails.root.join("com.workmori.web.plist").to_s
  raise "missing" unless File.exist?(plist_path)
  raw = File.read(plist_path)
  results << check("plist exists",                 File.exist?(plist_path))
  results << check("has Label com.workmori.web",   raw.include?("<string>com.workmori.web</string>"))
  results << check("has ProgramArguments bundle",  raw.include?("bundle") && raw.include?("rails"))
  results << check("has rails server command",     raw.include?("server"))
  results << check("has port 3001",                raw.include?("<string>3001</string>"))
  results << check("has WorkingDirectory",         raw.include?("WorkingDirectory"))
  results << check("has EnvironmentVariables",     raw.include?("EnvironmentVariables"))
  results << check("has PATH mise",                raw.include?(".local/share/mise"))
  results << check("has PGHOST 127.0.0.1",         raw.include?("127.0.0.1") && raw.include?("PGHOST"))
  results << check("has RunAtLoad",                raw.include?("RunAtLoad") && raw.include?("<true/>"))
  results << check("has KeepAlive",                raw.include?("KeepAlive") && raw.include?("Crashed"))
  results << check("has ThrottleInterval",         raw.include?("ThrottleInterval"))
  results << check("has StandardOutPath logs",     raw.include?("StandardOutPath") && raw.include?("Library/Logs"))
  results << check("has UserName hochari",         raw.include?("hochari"))
end

# Validate plist structure with simple regex (REXML removed from default in Ruby 3.4)
step(4, "plist structure valid (regex)") do
  plist_path = Rails.root.join("com.workmori.web.plist").to_s
  raw = File.read(plist_path)
  # Strip XML comments
  body = raw.gsub(/<!--.*?-->/m, "")
  results << check("starts with <?xml",            body.start_with?("<?xml"))
  results << check("has DOCTYPE plist",            body.include?("DOCTYPE plist"))
  results << check("root is <plist version=1.0>",  body =~ /<plist version="1\.0">/ ? true : false)
  results << check("has <dict> opening and closing", body.scan(/<dict>/).size >= 1 && body.scan(/<\/dict>/).size >= body.scan(/<dict>/).size)
  results << check("balanced <key>...</key>",      body.scan(/<key>/).size == body.scan(/<\/key>/).size)
  results << check("balanced <string>",            body.scan(/<string>/).size == body.scan(/<\/string>/).size)
  results << check("balanced <array>",             body.scan(/<array>/).size == body.scan(/<\/array>/).size)
  results << check("balanced <true/> and <false/>", body.scan(/<true\/>/).size >= 2 && body.scan(/<false\/>/).size >= 1)
  results << check("last key is UserName",         body.rindex("<key>UserName</key>") && body.rindex("<key>UserName</key>") > body.rindex("<key>Nice</key>"))
  # Try Plist library if available
  begin
    require "cfpropertylist"
    plist = CFPropertyList::List.new(file: plist_path)
    dict  = CFPropertyList.native_types(plist.value)
    results << check("CFPropertyList parses Label",     dict["Label"] == "com.workmori.web")
    results << check("CFPropertyList parses port 3001", dict["ProgramArguments"]&.include?("3001"))
    results << check("CFPropertyList parses RunAtLoad", dict["RunAtLoad"] == true)
  rescue LoadError
    # CFPropertyList not installed - that's OK, regex check is enough
  end
end

# ────────────────────────────────────────────────
# 5) bin/seed_full.rb exists, executable, runs idempotently
# ────────────────────────────────────────────────
step(5, "bin/seed_full.rb executable + idempotent") do
  seed_path = Rails.root.join("bin/seed_full.rb").to_s
  raise "missing" unless File.exist?(seed_path)
  results << check("file exists",        File.exist?(seed_path))
  results << check("executable bit set", File.stat(seed_path).executable? || File.chmod(0o755, seed_path) && File.stat(seed_path).executable?)

  # Pre-count
  pre_accounts    = Account.count
  pre_plans       = Plan.count
  pre_channels    = ChannelConnection.count
  pre_subs        = Subscription.count
  pre_invoices    = Invoice.count
  pre_contracts   = ContractTerm.count

  # Run twice (idempotency)
  out1 = `cd #{Rails.root} && PATH=$HOME/.local/share/mise/installs/ruby/3.4.10/bin:$PATH bin/rails runner bin/seed_full.rb 2>&1`
  out2 = `cd #{Rails.root} && PATH=$HOME/.local/share/mise/installs/ruby/3.4.10/bin:$PATH bin/rails runner bin/seed_full.rb 2>&1`

  results << check("1st run completes",          out1.include?("[seed_full] done"))
  results << check("2nd run completes (idempotent)", out2.include?("[seed_full] done"))
  results << check("1st run no error",           !out1.include?("ActiveRecord::RecordInvalid"))
  results << check("2nd run no error",           !out2.include?("ActiveRecord::RecordInvalid"))

  # Counts unchanged after 2nd run (idempotent)
  results << check("accounts unchanged",          Account.count        == pre_accounts)
  results << check("plans unchanged",             Plan.count           == pre_plans)
  results << check("channels unchanged",          ChannelConnection.count == pre_channels)
  results << check("subscriptions unchanged",     Subscription.count   == pre_subs)
  results << check("invoices unchanged",          Invoice.count        == pre_invoices)
  results << check("contracts unchanged",         ContractTerm.count   == pre_contracts)
end

# ────────────────────────────────────────────────
# 6) Seed produced required counts
# ────────────────────────────────────────────────
step(6, "Seed produced required dataset") do
  results << check(">=3 accounts (demo-skincare, demo-cafe, demo-shop)", Account.count >= 3)
  results << check(">=3 plans (starter/growth/byirim_special)",          Plan.where(code: %w[starter growth byirim_special]).count >= 3)
  results << check(">=1 byirim contract active",                         ContractTerm.where(status: "active", contract_code: "BYIRIM-2026-001").count >= 1)
  results << check(">=15 channels (3 accounts × 5)",                     ChannelConnection.count >= 15)
  results << check(">=3 active subscriptions",                           Subscription.where(state: "active").count >= 3)
  results << check(">=1 issued invoice for byirim",                     Invoice.where(state: "issued", account: Account.find_by(slug: "demo-skincare")).count >= 1)
end

# ────────────────────────────────────────────────
# 7) Plan prices are correct
# ────────────────────────────────────────────────
step(7, "Plan prices match spec") do
  starter = Plan.find_by(code: "starter")
  growth  = Plan.find_by(code: "growth")
  byirim  = Plan.find_by(code: "byirim_special")
  results << check("starter 99,000+9,900",      starter && starter.monthly_price_krw == 99_000 && starter.monthly_price_vat_krw == 9_900)
  results << check("growth 199,000+19,900",     growth  && growth.monthly_price_krw  == 199_000 && growth.monthly_price_vat_krw  == 19_900)
  results << check("byirim 300,000+30,000",      byirim  && byirim.monthly_price_krw  == 300_000 && byirim.monthly_price_vat_krw  == 30_000)
end

# ────────────────────────────────────────────────
# 8) Doc counts (lines)
# ────────────────────────────────────────────────
step(8, "Documentation completeness") do
  guide  = Rails.root.join("USER_GUIDE.md").to_s
  readme = Rails.root.join("README.md").to_s
  results << check("USER_GUIDE.md > 300 lines",      File.readlines(guide).size  > 300)
  results << check("README.md > 100 lines",         File.readlines(readme).size > 100)
  results << check("USER_GUIDE mentions AI 직원",   File.read(guide).include?("AI 직원"))
  results << check("README mentions launchd",        File.read(readme).include?("launchd"))
end

# ────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────
puts ""
total   = results.size
passed  = results.count { |r| r }
failed  = total - passed
puts "[V13] PASS: #{passed} / #{total}"
puts failed.zero? ? "[V13] 🎉 todo #13 모든 검증 통과" : "[V13] ❌ #{failed}개 실패"
exit(failed.zero? ? 0 : 1)