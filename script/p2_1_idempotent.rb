# frozen_string_literal: true

# P2-1 멱등성 결정적 검증
account = Account.first
business = BusinessProfile.find_or_create_by!(account_id: account.id) do |bp|
  bp.trade_name = "P2-멱등테스트"
  bp.legal_name = "P2멱등 주식회사"
  bp.owner_name = "P2 멱등 테스터"
  bp.industry_code = "restaurant"
  bp.region_label = "서울"
end
ai = AiEmployee.find_or_create_by!(account_id: account.id, name: "P2 멱등 AI") do |a|
  a.role_label = "응대 직원"
  a.persona_preset = "warm_local"
  a.status = "active"
end
user = User.first

# 이전 검증 데이터 정리
RuntimeConfig.where(account_id: account.id).where("change_summary LIKE ?", "[자동]%").destroy_all
RuntimeSync.where(business_profile_id: business.id).destroy_all
ChangeProposal.where(business_profile_id: business.id).destroy_all

# 새 제안 + 승인
proposal = ChangeProposal.create!(
  business_profile_id: business.id,
  ai_employee_id: ai.id,
  target_kind: "business_profile",
  target_field: "business_hours_v2",
  proposed_payload: { mon_fri: "10:00-19:00", sat: "10:00-16:00" },
  previous_payload: {},
  reason: "P2 결정적 멱등성 검증",
  user_quote: "영업시간 변경",
  status: "pending"
)
proposal.approve!(actor: user, discord_id: "999000111222333")
proposal.reload
puts "[P2-1] proposal ##{proposal.id} status=#{proposal.status}"

# 게이트 ON
flag = FeatureFlag.find_by!(key: "discord_native_enabled", account_id: nil)
flag.update!(enabled: true)
FeatureFlags.flush_cache!
puts "[P2-1] flag enabled=#{flag.enabled}"

# 1차 실행
r1 = CompileRuntimeConfigJob.new.perform(proposal.id, user.id)
puts "[P2-1] run 1: id=#{r1&.id} version=#{r1&.version} checksum_prefix=#{r1&.checksum&.[](0, 12)}"

# 2차 실행 — 멱등
r2 = CompileRuntimeConfigJob.new.perform(proposal.id, user.id)
puts "[P2-1] run 2: id=#{r2&.id} version=#{r2&.version} checksum_prefix=#{r2&.checksum&.[](0, 12)}"
puts "[P2-1] match=#{r1&.id == r2&.id} (둘 다 같은 객체여야 함)"

# 3차 실행 — proposal status가 applied라서 early return (이건 별도 검증)
puts "[P2-1] proposal.status after both runs: #{proposal.reload.status} (applied 여야 함)"
r3 = CompileRuntimeConfigJob.new.perform(proposal.id, user.id)
puts "[P2-1] run 3 (after applied): id=#{r3&.id} (status==applied라 nil이어야 함)"

# RuntimeConfig 카운트 — 1개만 있어야 함 (멱등)
configs = RuntimeConfig.where(account_id: account.id, status: "draft", source_change_proposal_id: proposal.id)
puts "[P2-1] RuntimeConfig draft for this proposal: count=#{configs.count} (1개여야 함)"

# RuntimeSync 카운트 — 1개 (중복 생성 안 됨)
syncs = RuntimeSync.where(business_profile_id: business.id, direction: "rails_to_hermes", topic: "runtime_config_update")
puts "[P2-1] runtime_syncs: count=#{syncs.count} (1개여야 함, 2차 호출은 멱등 차단)"

# 게이트 복구
flag.update!(enabled: false)
FeatureFlags.flush_cache!
puts "[P2-1] flag restored enabled=#{flag.reload.enabled}"