module Automation
  class FakeHermesAdapter < Provider
    def name = "fake"

    # Always returns success with deterministic stub outputs.
    # Real adapter should be a thin wrapper around the real Hermes runtime.
    def execute(rule:, payload:)
      kind = rule.intent_kind || rule.action_kind || "custom"
      log = AuditEvent.create!(
        account: rule.account,
        action: "automation.execute.fake",
        resource_type: "AutomationRule",
        resource_id: rule.id,
        metadata: { kind: kind, actor_kind: "automation", payload: payload },
        occurred_at: Time.current
      )
      result = stub_for(kind, payload)
      log.update!(metadata: log.metadata.merge(result: result))
      { ok: true, kind: kind, output: result, executed_by: "fake_hermes_adapter" }
    end

    private

    def stub_for(kind, payload)
      case kind
      when "generate_draft"
        { title: "(초안) #{payload[:topic] || "AI 직원 초안"}", body: "이 본문은 가짜 어댑터가 생성한 더미 텍스트입니다. 실제 운영 어댑터 연결 시 교체됩니다." }
      when "compose_reply"
        { body: "안녕하세요, #{payload[:intent] || "문의"}에 대해 안내드립니다. ..." }
      when "search_knowledge"
        { hits: [{ document_id: nil, snippet: "RAG 어댑터 미연결 상태", score: 1.0 }] }
      when "schedule_post"
        { scheduled_at: payload[:run_at] || (Time.current + 1.hour).iso8601 }
      when "publish_now"
        { published_at: Time.current.iso8601, status: "succeeded" }
      when "run_analysis"
        { metric: payload[:metric_name] || "engagement_rate", value: 0.0 }
      when "custom"
        { ok: true }
      else
        { ok: true }
      end
    end
  end
end
