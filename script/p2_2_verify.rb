# frozen_string_literal: true

# P2-2 검증: BusinessMemory + MCP recall_business_memory 도구
account = Account.first
business = BusinessProfile.find_or_create_by!(account_id: account.id) do |bp|
  bp.trade_name = "P2-메모리테스트"
  bp.legal_name = "P2메모리 주식회사"
  bp.owner_name = "P2 메모리"
  bp.industry_code = "restaurant"
  bp.region_label = "서울"
end

# 이전 메모리 정리
BusinessMemory.where(business_profile_id: business.id).destroy_all

# 메모리 5건 (다양한 scope/kind)
m1 = BusinessMemory.create!(business_profile_id: business.id, scope: "short_term", memory_kind: "inquiry_pattern",
  subject: "영업시간", content: "고객이 영업시간을 자주 묻는다 (월~금 10:00-19:00)", weight: 0.7)
m2 = BusinessMemory.create!(business_profile_id: business.id, scope: "long_term", memory_kind: "fact",
  subject: "대표 메뉴", content: "오늘의특선은 매일 11:30에 갱신", weight: 0.9)
m3 = BusinessMemory.create!(business_profile_id: business.id, scope: "long_term", memory_kind: "preference",
  subject: "고객 선호", content: "매운 음식을 선호함", weight: 0.6)
m4 = BusinessMemory.create!(business_profile_id: business.id, scope: "persona", memory_kind: "guardrail",
  subject: "응대 톤", content: "친근하지만 짧게 답변", weight: 1.0)
m5 = BusinessMemory.create!(business_profile_id: business.id, scope: "short_term", memory_kind: "frequent_request",
  subject: "주차", content: "주차 가능 여부 질문이 잦음", weight: 0.8)
puts "[P2-2] created 5 memories for business ##{business.id}"

# 다른 사업자에 격리 검증 메모리 (조회 안 되어야 함)
other_business = BusinessProfile.where.not(id: business.id).first || BusinessProfile.create!(
  account_id: account.id, trade_name: "다른 사업장", legal_name: "다른 사업장 주식회사",
  owner_name: "다른", industry_code: "other", region_label: "부산"
)
BusinessMemory.where(business_profile_id: other_business.id).destroy_all
BusinessMemory.create!(business_profile_id: other_business.id, scope: "long_term", memory_kind: "fact",
  subject: "격리 테스트", content: "이 메모리는 절대 조회되면 안 됨", weight: 1.0)
puts "[P2-2] isolation memory for other_business ##{other_business.id}"

# 1. 모델 직접 recall (모든 메모리)
all_recall = BusinessMemory.recall(business_profile: business, limit: 10)
puts "[P2-2] recall all: count=#{all_recall.size} (expected 5)"
puts "[P2-2] top 3 weights: #{all_recall.first(3).map { |m| "#{m.subject}=#{m.weight}" }.join(', ')}"

# 2. kind 필터
fact_only = BusinessMemory.recall(business_profile: business, kinds: %w[fact])
puts "[P2-2] recall facts only: count=#{fact_only.size} (expected 1: #{fact_only.first&.subject})"

# 3. touch_recall! 검증
before_count = m1.recall_count
BusinessMemory.recall(business_profile: business, kinds: %w[inquiry_pattern])
after_count = m1.reload.recall_count
puts "[P2-2] touch_recall: before=#{before_count} after=#{after_count} (after>before 여야 함)"

# 4. snapshot
snap = BusinessMemory.snapshot(business_profile: business, limit: 3)
puts "[P2-2] snapshot first 3 subjects: #{snap.map { |s| s[:subject] }.join(', ')}"

# 5. 격리 검증 — 다른 사업장 메모리는 안 보임
isolated = BusinessMemory.recall(business_profile: business)
puts "[P2-2] 격리 검증: count=#{isolated.size} (5개여야 함, 격리 메모리 1개 미포함)"

# 6. 만료 검증
m1.update!(expires_at: 1.minute.ago)
expired_check = BusinessMemory.recall(business_profile: business)
puts "[P2-2] 만료 후 recall: count=#{expired_check.size} (4개여야 함, m1 만료)"

# 7. MCP 도구 시뮬레이션 — 컨트롤러 recall_business_memory 호출 흉내
sync = RuntimeSync.new(business_profile_id: business.id, direction: "hermes_to_rails",
  topic: "health", agent_id: "sohee-control-mcp",
  payload: { kinds: %w[fact preference], limit: 5 }, idempotency_key: SecureRandom.uuid)
result = {}
# 직접 비즈니스 로직 호출
memories = BusinessMemory.recall(business_profile: business, kinds: %w[fact preference], limit: 5)
result = { memories: memories.map { |m| { id: m.id, scope: m.scope, kind: m.memory_kind, content: m.content, weight: m.weight } } }
puts "[P2-2] MCP recall_business_memory (kinds=[fact, preference]): count=#{result[:memories].size} subjects=#{result[:memories].map { |m| m[:kind] }.uniq.join(',')}"

# 정리
m1.update!(expires_at: nil)
puts "[P2-2] DONE"