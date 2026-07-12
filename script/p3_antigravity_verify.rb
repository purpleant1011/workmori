#!/usr/bin/env ruby
# frozen_string_literal: true
#
# script/p3_antigravity_verify.rb
# P3 Antigravity CLI OAuth 통합 검증 (2026-07-12)
#
# 1. agy CLI OAuth 인증 상태 확인 (agy -p "ping" 200 응답)
# 2. FeatureFlag antigravity_cli_enabled 토글 ON
# 3. /api/v1/health 에서 feature_flags 반영 확인
# 4. workers/gemini-conversation 재빌드 + antigravity_cli_dev provider 등록 확인
# 5. /invoke 호출 → provider=antigravity_cli_dev → agy spawn 응답 확인
# 6. gate OFF (원상복구)

require "net/http"
require "json"
require "uri"

RAILS_BASE = ENV["RAILS_INTERNAL_API_BASE"] || "http://localhost:3001"
WORKER_BASE = ENV["WORKER_BASE"] || "http://localhost:7100"
ACCOUNT_ID = 1
PROMPT_TEST = "ping 한 줄로 답해"

def log(label, msg)
  puts "[P3-ANTIGRAVITY] #{label} #{msg}"
end

def feature_flag_toggle(key, enabled)
  flag = FeatureFlag.find_by!(key: key)
  flag.update!(enabled: enabled)
  flag.reload
end

def http_get(path, headers = {})
  uri = URI.join(RAILS_BASE, path)
  res = Net::HTTP.get_response(uri, headers)
  [res.code.to_i, res.body]
end

def http_post_json(path, body, headers = {})
  uri = URI.join(RAILS_BASE, path)
  req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", **headers)
  req.body = body.to_json
  res = Net::HTTP.start(uri.host, uri.port) { |h| h.request(req) }
  [res.code.to_i, res.body]
end

def worker_post_json(path, body, headers = {})
  uri = URI.join(WORKER_BASE, path)
  req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", **headers)
  req.body = body.to_json
  res = Net::HTTP.start(uri.hostname, uri.port) { |h| h.request(req) }
  [res.code.to_i, res.body]
end

# 0. agy CLI 직접 호출 — OAuth 토큰 살아있는지 확인
log "step 0", "agy CLI direct check..."
out = `agy -p "#{PROMPT_TEST}" 2>&1`.strip
log "agy direct", out[0, 200]
abort "[P3-ANTIGRAVITY] FAIL: agy CLI not responsive" if out.empty? || out.downcase.include?("error")

# 1. FeatureFlag ON
log "step 1", "FeatureFlag antigravity_cli_enabled ON..."
feature_flag_toggle("antigravity_cli_enabled", true)
log "  flag=", "antigravity_cli_enabled=#{FeatureFlag.find_by(key: 'antigravity_cli_enabled').enabled}"

# 2. /api/v1/health 에서 feature_flags 확인
log "step 2", "/api/v1/health feature_flags check..."
sleep 12 # FeatureFlags 10초 TTL puma 캐시 만료 대기
code, body = http_get("/api/v1/health")
log "  health", "#{code} #{body[0, 250]}"
abort "[P3-ANTIGRAVITY] FAIL: antigravity_cli_enabled not true in /health" unless body.include?('"antigravity_cli_enabled":true')

# 3. 워커 antigravity_cli_dev provider 등록 확인
log "step 3", "worker /invoke antigravity_cli_dev check..."
code, body = worker_post_json("/invoke", {
  provider: "antigravity_cli_dev",
  payload: {
    businessProfileId: 1,
    messages: [
      { role: "system", content: "한 줄로 짧게 답해." },
      { role: "user", content: "테스트: 너는 누구야?" }
    ],
    structuredOutput: "free"
  }
})
log "  worker invoke", "#{code} #{body[0, 400]}"

unless code == 200
  log "step 4 (cleanup)", "aborting — gate OFF"
  feature_flag_toggle("antigravity_cli_enabled", false)
  abort "[P3-ANTIGRAVITY] FAIL: worker invoke returned #{code}"
end

parsed = JSON.parse(body)
log "  worker provider", parsed["provider"]
log "  worker model", parsed["model"]
log "  worker text", parsed["text"][0, 200]

# 4. provider != gemini_api 확인 (antigravity_cli_dev 로 갔는지)
unless parsed["provider"] == "antigravity_cli_dev"
  feature_flag_toggle("antigravity_cli_enabled", false)
  abort "[P3-ANTIGRAVITY] FAIL: expected provider=antigravity_cli_dev, got #{parsed['provider']}"
end

# 4-1. Rails 측 AntigravityClient 통합 검증
log "step 4-1", "Rails AntigravityClient.invoke (Discord 시뮬레이션)..."
r = AntigravityClient.invoke(
  business_profile_id: 1,
  messages: [
    { role: "system", content: "한 줄로 답해." },
    { role: "user", content: "테스트: 영업시간 알려줘" }
  ],
  structured_output: "free"
)
log "  antigravity_client", "provider=#{r['provider']} model=#{r['model']}"
log "  antigravity_client text", r["text"].to_s[0, 200]
abort "[P3-ANTIGRAVITY] FAIL: AntigravityClient provider mismatch" unless r["provider"] == "antigravity_cli_dev"

# 4-2. SNS 글 작성 통합 검증 (Content::Pipeline)
log "step 4-2", "Content::Pipeline (SNS 글 작성 antigravity 경로)..."
acc = Account.first
ai = AiEmployee.first
result = Content::Pipeline.run(account: acc, ai_employee: ai, intent: "feed", schedule_kind: "manual")
ci = result.content_item
log "  content_item", "id=#{ci.id} title=#{ci.title[0,80]}"
log "  content body", ci.body.to_s[0, 200]
log "  content hashtags", ci.hashtags_json
log "  content state", "#{ci.state} safety=#{result.safety_result[:verdict]}"
abort "[P3-ANTIGRAVITY] FAIL: Content::Pipeline body empty" if ci.body.to_s.strip.empty?

# 5. gate OFF (원상복구)
log "step 5", "FeatureFlag antigravity_cli_enabled OFF..."
feature_flag_toggle("antigravity_cli_enabled", false)
log "  flag=", "antigravity_cli_enabled=#{FeatureFlag.find_by(key: 'antigravity_cli_enabled').enabled}"

log "DONE", "✅ Antigravity CLI OAuth 통합 검증 완료"
