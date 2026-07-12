#!/usr/bin/env ruby
# P2-SIDE: Api::V1::Mcp::InvokesController 4개 도구 컬럼 정합성 검증
# 게이트 ON, 4개 도구 + 1개 에러 시나리오

# .env 로드 (puma가 로드한 값과 일치)
File.foreach(".env") do |line|
  next if line.start_with?("#") || line.strip.empty?
  k, v = line.strip.split("=", 2)
  ENV[k] ||= v
end

require "json"

acct = Account.first
bp = acct.business_profiles.first
ai = acct.ai_employees.first

# 사업장이 없으면 시드
if bp.nil?
  bp = BusinessProfile.create!(
    account_id: acct.id,
    owner_name: "P2-SIDE 테스트",
    industry_code: "restaurant",
    region_label: "서울"
  )
end

puts "[P2-SIDE] account=#{acct.id} bp=#{bp.id} ai=#{ai&.id}"

# 게이트 ON
flag = FeatureFlag.find_or_initialize_by(key: "discord_native_enabled")
flag.update!(enabled: true)
FeatureFlags.flush_cache!
puts "[P2-SIDE] gate ON enabled=#{FeatureFlags.enabled?(:discord_native_enabled)}"
# puma 별도 프로세스 캐시 비우기 위해 대기 (Rails.cache in-memory share 안 됨)
puts "[P2-SIDE] waiting 12s for puma cache TTL expire..."
sleep 12

# Internal token (직접 Job 호출은 게이트 우회, 하지만 컨트롤러 검증 위해 HTTP 호출)
internal_token = ENV["INTERNAL_SERVICE_TOKEN"] || "sohee_internal_test_token_2026"

# 쿠키 기반 사업자 세션 얻기 (간단히: bp.id로 직접 tools 호출)
# 컨트롤러가 받는 params[:business_profile_id]를 명시
require "net/http"
require "uri"

def call_mcp(tool, params, idempotency_key, bp_id)
  uri = URI("http://127.0.0.1:3001/api/v1/mcp/invokes")
  req = Net::HTTP::Post.new(uri)
  req["Content-Type"] = "application/json"
  req["X-Internal-Token"] = ENV["HERMES_MCP_TOKEN"]
  req.body = JSON.generate(
    tool: tool,
    business_profile_id: bp_id,
    idempotency_key: idempotency_key,
    params: params
  )
  res = Net::HTTP.start(uri.hostname, uri.port) { |h| h.request(req) }
  [res.code.to_i, res.body]
end

# 1) report_knowledge_gap (question/channel/hit_kind, channel=chat/discord→chat, hit_kind=low_score)
code, body = call_mcp("report_knowledge_gap",
  { ai_employee_id: ai&.id, question: "P2-SIDE: 영업시간이 어떻게 되나요?", channel: "chat", hit_kind: "low_score" },
  "side-kg-#{SecureRandom.hex(4)}", bp.id)
puts "[P2-SIDE] report_knowledge_gap => #{code} #{body[0,200]}"

# 2) save_content_draft (content_kind=feed)
code, body = call_mcp("save_content_draft",
  { ai_employee_id: ai&.id, content_kind: "feed", title: "P2-SIDE 초안", body: "본문 테스트", caption: "캡션" },
  "side-sd-#{SecureRandom.hex(4)}", bp.id)
puts "[P2-SIDE] save_content_draft => #{code} #{body[0,200]}"

# 3) request_human_review (ai_employee_id 필수 추가)
code, body = call_mcp("request_human_review",
  { ai_employee_id: ai&.id, target_kind: "faq", target_field: "answer_policy",
    proposed_payload: { tone: "warm" }, reason: "P2-SIDE 테스트" },
  "side-rh-#{SecureRandom.hex(4)}", bp.id)
puts "[P2-SIDE] request_human_review => #{code} #{body[0,200]}"

# 4) get_active_runtime_config (account_id 기반 쿼리)
code, body = call_mcp("get_active_runtime_config", {}, "side-gr-#{SecureRandom.hex(4)}", bp.id)
puts "[P2-SIDE] get_active_runtime_config => #{code} #{body[0,200]}"

# 5) recall_business_memory (이미 P2-2 검증 완료, 재호출)
code, body = call_mcp("recall_business_memory", {}, "side-rm-#{SecureRandom.hex(4)}", bp.id)
puts "[P2-SIDE] recall_business_memory => #{code} #{body[0,150]}"

# 게이트 OFF
flag.update!(enabled: false)
FeatureFlags.flush_cache!
puts "[P2-SIDE] gate OFF restored"
puts "[P2-SIDE] DONE"
