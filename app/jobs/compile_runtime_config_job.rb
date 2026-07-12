# frozen_string_literal: true

# CompileRuntimeConfigJob — 승인된 ChangeProposal → RuntimeConfig(v2 호환) Draft 컴파일
# 원칙 3: RuntimeConfig v1과 호환 (account_id 기반, Draft → Active 2-step)
# 원칙 4: Discord 메시지 신뢰 불가 → status=approved 만 컴파일 (제안→확인→적용)
# 원칙 9: 영구 변경은 제안 → 확인 → 적용 3단계. 이 Job은 "적용" 단계 (Draft 생성).
class CompileRuntimeConfigJob < DiscordNativeJob
  queue_as :default

  def perform(proposal_id, actor_user_id)
    return unless FeatureFlags.enabled?(:discord_native_enabled)

    proposal = ChangeProposal.find(proposal_id)

    # 멱등 1: 이미 적용된 제안이면 기존 RuntimeConfig 반환
    if proposal.applied? && proposal.applied_runtime_config_id.present?
      existing = RuntimeConfig.find_by(id: proposal.applied_runtime_config_id)
      return existing if existing
    end

    return unless proposal.status == "approved"

    business = proposal.business_profile
    account  = business.account

    # 1. SHA256 멱등 키 — 동일 입력 → 동일 체크섬 → 중복 생성 방지
    current = RuntimeConfig.where(account_id: account.id, status: "active").order(version: :desc).first
    new_bundle = compose_bundle(current&.bundle_json, proposal)
    new_checksum = Digest::SHA256.hexdigest(new_bundle.to_json)

    # 멱등: 동일 체크섬 active가 이미 있으면 그대로 반환
    existing = RuntimeConfig.where(account_id: account.id, checksum: new_checksum).first
    if existing
      AuditEvent.create!(
        account_id: account.id,
        action: "compile_runtime_config.skipped_duplicate",
        resource_type: "ChangeProposal",
        resource_id: proposal.id,
        actor_kind: "system",
        metadata: { existing_runtime_config_id: existing.id, checksum_prefix: new_checksum[0, 12] },
        occurred_at: Time.current
      )
      return existing
    end

    # 2. Draft 생성
    next_version = (current&.version&.to_s&.delete("v")&.to_i || 0) + 1
    config = RuntimeConfig.create!(
      account_id: account.id,
      version: "v#{next_version}",
      status: "draft",
      bundle_json: new_bundle,
      checksum: new_checksum,
      change_summary: "[자동] #{proposal.target_kind}.#{proposal.target_field} — #{proposal.reason.to_s.truncate(120)}",
      compiled_at: Time.current,
      compiled_by_agent_id: "sohee-control-mcp",
      source_change_proposal_id: proposal.id
    )

    proposal.mark_applied!(runtime_config_id: config.id)

    # 3. RuntimeSync 기록 (Rails → Hermes 전달 큐)
    sync = RuntimeSync.create!(
      business_profile_id: business.id,
      direction: "rails_to_hermes",
      topic: "runtime_config_update",
      agent_id: "sohee-control-mcp",
      payload: {
        runtime_config_id: config.id,
        version: config.version,
        status: "draft",
        checksum: new_checksum[0, 12],
        source_change_proposal_id: proposal.id
      },
      status: "pending",
      idempotency_key: "compile:#{proposal.id}:#{new_checksum[0, 16]}"
    )

    # 4. Hermes에 알림 (실제 Hermes가 가동되면 사용)
    DispatchHermesJob.perform_later(
      business.id,
      "runtime_config_update",
      { runtime_config_id: config.id, version: config.version, runtime_sync_id: sync.id }
    )

    # 5. Discord에 결과 보고 (워크스페이스 연결된 경우)
    workspace = business.discord_workspaces.active.first
    if workspace
      DiscordOutboundJob.perform_later(
        business.id,
        workspace.default_channel_id,
        "✅ 새 설정 초안이 만들어졌어요. 검토 후 운영팀이 적용합니다.\n설정 #{config.version} (#{proposal.target_kind}.#{proposal.target_field})"
      )
    end

    config
  end

  private

  def compose_bundle(current_bundle, proposal)
    base = current_bundle.is_a?(Hash) ? current_bundle.deep_dup : {}
    base["schema_version"] ||= "sohee.runtime/v1"
    base["generated_at"] = Time.current.iso8601
    field_key = proposal.target_field.presence || "unspecified"
    base[field_key.to_s] = proposal.proposed_payload
    base
  end
end