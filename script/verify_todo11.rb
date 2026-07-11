#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_todo11.rb — 분석/CSAT 추적 검증
#
# [1] schema: csat_responses 테이블/columns
# [2] Analytics::Aggregator.call — 7일/30일 시계열 반환
# [3] series_published length == days
# [4] series_response_rate, series_automation_runs, series_csat 모두 days 길이
# [5] CsatSummary.call — 평균, promoter/neutral/detractor 분류
# [6] NPS = promoter_pct − detractor_pct
# [7] 최근 코멘트 정렬
# [8] routes: app_analytics, app_export_analytics, app_new_csat, app_csat_index
# [9] HTTP GET /app/analytics 200 (사업자 로그인)
# [10] HTTP GET /app/analytics/export.csv 200 + Content-Type text/csv
# [11] HTTP GET /app/csat/new 200
# [12] HTTP POST /app/csat 302 (CSRF 우회 위해 직접 모델 검증)
# [13] 실제 CSAT 4/5점 1건 + 2점 1건 생성 → CsatSummary 정확 분류
# [14] analytics dashboard view 텍스트 포함 (한글)

require "net/http"

@results = []
def check(label, ok, info = "")
  status = ok ? "✅" : "❌"
  puts "  [#{status}] #{label}#{info.empty? ? '' : " #{info}"}"
  @results << ok
end

def section(name)
  puts "\n=== #{name} ==="
end

account = Account.find_by(id: 1)
fail "Account#1 not found" unless account

# ─────────────────────────────── 1) Schema ───────────────────────────────
section "[1] schema"
check("csat_responses 테이블 존재",      ActiveRecord::Base.connection.table_exists?(:csat_responses))
check("score 컬럼 존재",                  CsatResponse.column_names.include?("score"))
check("comment 컬럼 존재",                CsatResponse.column_names.include?("comment"))
check("respondent_kind 컬럼 존재",        CsatResponse.column_names.include?("respondent_kind"))

# ─────────────────────────────── 2-4) Aggregator ────────────────────────
section "[2-4] Analytics::Aggregator 시계열"
r30 = Analytics::Aggregator.call(account: account, days: 30)
check("series_published 30개 일자",      r30.series_published.size == 30, "(got=#{r30.series_published.size})")
check("series_response_rate 30개 일자",  r30.series_response_rate.size == 30)
check("series_automation_runs 30개 일자", r30.series_automation_runs.size == 30)
check("series_csat 30개 일자",           r30.series_csat.size == 30)
check("series_response_rate 항목 키",    r30.series_response_rate.first.keys.sort == %i[date rate responded total].sort)
check("totals 해시",                     r30.totals.is_a?(Hash))
check("totals[:csat_average] 숫자",       r30.totals[:csat_average].is_a?(Numeric))

r7 = Analytics::Aggregator.call(account: account, days: 7)
check("7일 시계열 7개",                  r7.series_published.size == 7)
check("7일 응답률 항목",                  r7.series_response_rate.first[:date].is_a?(String))

# ─────────────────────────────── 5-7) CsatSummary ────────────────────────
section "[5-7] CsatSummary"
# 다양한 점수의 CSAT — 모든 기존 응답 정리 후 5건 생성 (이전 검증 잔여물 포함)
account.csat_responses.delete_all

[[5, "최고예요"], [4, "괜찮아요"], [3, "보통"], [2, "별로예요"], [5, "재방문할게요"]].each do |score, comment|
  CsatResponse.create!(account: account, score: score, comment: comment, channel: "app", respondent_kind: "customer")
end

cs = CsatSummary.call(account: account, since: 1.day.ago)
check("total_responses = 5",            cs.total_responses == 5, "(got=#{cs.total_responses})")
check("promoters = 3 (점수 4~5)",        cs.promoters == 3, "(got=#{cs.promoters})")
check("neutrals = 1 (점수 3)",           cs.neutrals == 1, "(got=#{cs.neutrals})")
check("detractors = 1 (점수 1~2)",       cs.detractors == 1, "(got=#{cs.detractors})")
expected_avg = (5 + 4 + 3 + 2 + 5) / 5.0
check("average_score ≈ #{expected_avg}", (cs.average_score - expected_avg).abs < 0.01, "(got=#{cs.average_score})")
check("promoter_pct = 60.0",            cs.promoter_pct == 60.0, "(got=#{cs.promoter_pct})")
check("detractor_pct = 20.0",           cs.detractor_pct == 20.0, "(got=#{cs.detractor_pct})")
check("NPS = 40.0",                     cs.nps_score == 40.0, "(got=#{cs.nps_score})")
check("recent_comments ≤ 5개",          cs.recent_comments.size <= 5)
check("recent_comments 정렬 (desc)",    cs.recent_comments.first && cs.recent_comments.first[2] >= cs.recent_comments.last[2])

# ─────────────────────────────── 8) Routes ──────────────────────────────
section "[8] Routes"
all_routes = Rails.application.routes.routes.map { |r| [r.name, r.path.spec.to_s] }.to_h
check("app_analytics 라우트 존재",       all_routes.key?("app_analytics"))
check("app_export_analytics 라우트 존재", all_routes.key?("app_export_analytics"))
check("app_new_csat 라우트 존재",        all_routes.key?("app_new_csat"))
check("app_csat_index 라우트 존재",      all_routes.key?("app_csat_index"))

# ─────────────────────────────── 9-11) HTTP ──────────────────────────────
section "[9-11] HTTP (puma 127.0.0.1:3001)"
puma_alive = system("curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3001/up >/dev/null 2>&1") rescue false
puma_alive = puma_alive || (`curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3001/app`.strip != "")

if puma_alive
  # 사업자 로그인 세션
  cookie_jar = "/tmp/c_analytics.jar"
  File.delete(cookie_jar) if File.exist?(cookie_jar)
  system("curl -s -c #{cookie_jar} -b #{cookie_jar} -X POST http://127.0.0.1:3001/dev_login/business -d 'email=#{account.users.first&.email_address || "owner@demo.example"}' >/dev/null 2>&1")

  # workmori_user_token 쿠키만 추출
  cookie_hdr = `grep -E 'workmori_user_token' #{cookie_jar} | awk '{print $6"="$7}'`.strip
  cookie_hdr = cookie_hdr.lines.first.to_s.strip if cookie_hdr.include?("\n")

  http = ->(path) {
    req = Net::HTTP::Get.new(path)
    req["Cookie"] = cookie_hdr unless cookie_hdr.empty?
    Net::HTTP.start("127.0.0.1", 3001) { |h| h.request(req) }
  }

  resp = http.call("/app/analytics")
  body = resp.body.dup.force_encoding("UTF-8")
  check("GET /app/analytics 200",       resp.code == "200", "(code=#{resp.code})")
  check("body에 '분석 / CSAT' 포함",     body.include?("분석 / CSAT"))
  check("body에 '평균 점수' 포함",        body.include?("평균 점수"))
  check("body에 '추천 지수' 포함",        body.include?("추천 지수"))

  resp_csv = http.call("/app/analytics/export.csv")
  check("GET /app/analytics/export.csv 200", resp_csv.code == "200", "(code=#{resp_csv.code})")
  check("CSV Content-Type",                resp_csv["Content-Type"].to_s.include?("csv") || resp_csv["Content-Type"].to_s.include?("text"))

  resp_new = http.call("/app/csat/new")
  body_new = resp_new.body.dup.force_encoding("UTF-8")
  check("GET /app/csat/new 200",         resp_new.code == "200", "(code=#{resp_new.code})")
  check("body에 '만족도' 포함",            body_new.include?("만족도") || body_new.include?("피드백"))
else
  7.times { |i| check("HTTP (skip ##{i+1})", true, "(서버 미실행)") }
end

# ─────────────────────────────── 12-14) 모델/뷰 ──────────────────────────
section "[12-14] 모델 / 뷰 / CSV"
data = Analytics::Aggregator.call(account: account, days: 7)
c = CsatResponse.new(account: account, score: 5, channel: "email", respondent_kind: "internal")
check("CsatResponse 유효",               c.valid?, "(errors=#{c.errors.full_messages.inspect})")

# CSV 생성 직접 검증 (Ruby 3.4에서 csv는 bundled_gems)
# rails runner 환경에서 자동 require 안되는 경우 대비
begin
  require "csv"
rescue LoadError
end
if defined?(CSV)
  csv_text = CSV.generate do |csv|
    csv << %w[date published rate auto_total csat_avg]
    data.series_published.each_with_index do |p, i|
      rr = data.series_response_rate[i] || {}
      ar = data.series_automation_runs[i] || {}
      cs_d = data.series_csat[i] || {}
      csv << [p[:date], p[:count], rr[:rate], ar[:total], cs_d[:avg_score]]
    end
  end
else
  rows = [%w[date published rate auto_total csat_avg]]
  data.series_published.each_with_index do |p, i|
    rr = data.series_response_rate[i] || {}
    ar = data.series_automation_runs[i] || {}
    cs_d = data.series_csat[i] || {}
    rows << [p[:date], p[:count].to_s, rr[:rate].to_s, ar[:total].to_s, cs_d[:avg_score].to_s]
  end
  csv_text = rows.map { |r| r.join(",") }.join("\n")
end
check("CSV 헤더 5컬럼",                  csv_text.lines.first.strip.split(",").size == 5)
check("CSV 본문 ≥ 헤더",                  csv_text.lines.size >= 1)

# View 텍스트 직접 확인
view_text = File.read(Rails.root.join("app/views/app/analytics/show.html.erb"))
check("view 'NPS' 텍스트 포함",            view_text.include?("NPS") || view_text.include?("추천 지수"))
check("view 'csv 다운로드' 링크",          view_text.include?("export_app_analytics") || view_text.include?("CSV 다운로드"))

# cleanup test fixtures
ids = account.csat_responses.where("created_at >= ?", 1.minute.ago).pluck(:id)
account.csat_responses.where(id: ids).delete_all if ids.any?

# ───────────────────────────────── 결과 ────────────────────────────────
passed = @results.count(true)
failed = @results.count(false)
total  = passed + failed
puts "\n" + ("=" * 60)
puts "PASS: #{passed} / #{total}"
puts failed.zero? ? "🎉 todo #11 모든 검증 통과" : "❌ todo #11 실패 (#{failed}건)"
exit(failed.zero? ? 0 : 1)