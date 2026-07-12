# frozen_string_literal: true

# P2-1 검증 스크립트
# 1. 가짜 사업장·사업장프로필·AI직원·제안·승인 카드 생성
# 2. CompileRuntimeConfigJob.perform(...) 실행
# 3. RuntimeConfig draft 생성 + RuntimeSync pending 생성 + 멱등 확인
account = Account.first || Account.create!(
  email: "p2-test@example.com",
  password: "TestPass1234!",
  password_confirmation: "TestPass1234!"
)
business = BusinessProfile.find_or_create_by!(account_id: account.id) do |bp|
  bp.trade_name = "P2-테스트 사업장"
  bp.legal_name = "P2테스트 주식회사"
  bp.owner_name = "P2 테스터"
  bp.industry_code = "restaurant"
  bp.region_label = "서울"
  bp.brand_intro = "P2 단계 검증용"
end
ai = AiEmployee.find_or_create_by!(account_id: account.id) do |a|
  a.name = "P2 테스트 직원"
  a.role_label = "응대 직원"
  a.persona_preset = "warm_local"
  a.status = "active"
end

# 제안 생성
proposal = ChangeProposal.create!(
  business_profile_id: business.id,
  ai_employee_id: ai.id,
  target_kind: "business_profile",
  target_field: "business_hours",
  proposed_payload: { mon_fri: "09:00-18:00", sat: "10:00-15:00" },
  previous_payload: {},
  reason: "고객 응대 중 영업시간 문의가 많아 정식 등록 요청",
  user_quote: "영업시간을 좀 등록해줘요",
  status: "pending"
)
puts "[P2-1] proposal ##{proposal.id} status=#{proposal.status}"

# 승인 처리 (Discord 식별자 흉내)
user = User.first || User.create!(email: "p2-user@example.com", password: "TestPass1234!")
ok = proposal.approve!(actor: user, discord_id: "999000111222333")
puts "[P2-1] approve! => #{ok}, status=#{proposal.reload.status}"

# 게이트 ON 일시 활성
flag = FeatureFlag.find_by!(key: "discord_native_enabled", account_id: nil)
puts "[P2-1] before flag enabled=#{flag.enabled}"
flag.update!(enabled: true)
FeatureFlags.flush_cache!

# Job 실행
result = CompileRuntimeConfigJob.new.perform(proposal.id, user.id)
puts "[P2-1] runtime_config id=#{result&.id} version=#{result&.version} status=#{result&.status} checksum=#{result&.checksum&.[](0, 12)}"

# 멱등 재실행 — 동일 체크섬으로 중복 생성 안 됨
second = CompileRuntimeConfigJob.new.perform(proposal.id, user.id)
puts "[P2-1] idempotent retry => id=#{second&.id} (must equal previous=#{result&.id})"
puts "[P2-1] match=#{result&.id == second&.id}"

# RuntimeSync 확인
syncs = RuntimeSync.where(business_profile_id: business.id, direction: "rails_to_hermes")
puts "[P2-1] runtime_syncs count=#{syncs.count} status=#{syncs.first&.status} topic=#{syncs.first&.topic} idempotency_key=#{syncs.first&.idempotency_key}"

# 게이트 복구
flag.update!(enabled: false)
FeatureFlags.flush_cache!
puts "[P2-1] flag restored enabled=#{flag.reload.enabled}"

# 제안 status
puts "[P2-1] proposal.status=#{proposal.reload.status} applied_runtime_config_id=#{proposal.applied_runtime_config_id}"