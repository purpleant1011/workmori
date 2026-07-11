module Automation
  # Real Hermes adapter — calls the actual Hermes Agent runtime via HTTP.
  #
  # Contract:
  #   POST {HERMES_AGENT_URL}/v1/automation/execute
  #   Headers: Authorization: Bearer {HERMES_AGENT_TOKEN}, Content-Type: application/json
  #   Body: {
  #     "rule": { "id": ..., "account_id": ..., "intent_kind": ..., "name": ...,
  #               "schedule_json": ..., "guardrails_json": ..., "knowledge_source_ids": [...] },
  #     "payload": { ... arbitrary per-kind payload ... },
  #     "context": {
  #       "ai_employee_id": ..., "conversation_id": ..., "content_item_id": ...,
  #       "channel_connection_id": ..., "brand_profile": { ... },
  #       "knowledge_snapshot": [ { id, title, snippet } ],
  #       "tone_guidelines": "...", "compliance_constraints": [ ... ]
  #     }
  #   }
  #   Response: { "ok": true, "kind": "...", "output": {...}, "executed_by": "hermes-agent", "trace_id": "..." }
  #
  # Failure modes:
  #   - HERMES_AGENT_URL missing → fall back to FakeHermesAdapter (with warning audit)
  #   - HTTP timeout (default 25s) → mark execution as failed, raise so caller decides
  #   - HTTP 4xx/5xx → raise Hermes::ExecutionError
  #   - 5xx with retries allowed → retry up to HERMES_MAX_RETRIES (default 2)
  class RealHermesAdapter < Provider
    DEFAULT_TIMEOUT = 25
    DEFAULT_MAX_RETRIES = 2

    class ExecutionError < StandardError; end

    def name = "real"

    def execute(rule:, payload:)
      url = ENV["HERMES_AGENT_URL"].to_s
      token = ENV["HERMES_AGENT_TOKEN"].to_s

      if url.blank?
        Rails.logger.warn("[automation:real_hermes] HERMES_AGENT_URL not set, falling back to fake.")
        AuditEvent.create!(
          account: rule.account, action: "automation.hermes.misconfigured",
          resource_type: "AutomationRule", resource_id: rule.id,
          metadata: { hint: "set HERMES_AGENT_URL + HERMES_AGENT_TOKEN" },
          occurred_at: Time.current
        )
        return FakeHermesAdapter.new.execute(rule: rule, payload: payload)
      end

      body = build_request_body(rule: rule, payload: payload)
      timeout = ENV.fetch("HERMES_AGENT_TIMEOUT", DEFAULT_TIMEOUT).to_i
      max_retries = ENV.fetch("HERMES_MAX_RETRIES", DEFAULT_MAX_RETRIES).to_i

      response = http_post_with_retries(url: url, token: token, body: body, timeout: timeout, max_retries: max_retries)
      parsed = parse_response(response)

      AuditEvent.create!(
        account: rule.account, action: "automation.execute.real",
        resource_type: "AutomationRule", resource_id: rule.id,
        metadata: { kind: parsed[:kind], payload: payload, output: parsed[:output],
                    trace_id: parsed[:trace_id], duration_ms: parsed[:duration_ms] },
        occurred_at: Time.current
      )

      { ok: true, kind: parsed[:kind], output: parsed[:output],
        executed_by: "hermes-agent", trace_id: parsed[:trace_id] }
    end

    private

    def build_request_body(rule:, payload:)
      ai_employee = rule.ai_employee
      ctx = {
        ai_employee_id: ai_employee&.id,
        ai_employee_name: ai_employee&.name,
        ai_employee_role: ai_employee&.role,
        brand_profile: rule.account&.business_profile&.brand_profile_json,
        tone_guidelines: ai_employee&.tone_guidelines,
        compliance_constraints: rule.guardrails_json || [],
        knowledge_snapshot: load_knowledge_snapshot(rule)
      }

      {
        rule: {
          id: rule.id,
          account_id: rule.account_id,
          name: rule.name,
          intent_kind: rule.intent_kind,
          action_kind: rule.action_kind,
          schedule_json: rule.schedule_json,
          guardrails_json: rule.guardrails_json,
          knowledge_source_ids: rule.knowledge_source_ids
        },
        payload: payload,
        context: ctx
      }
    end

    def load_knowledge_snapshot(rule)
      return [] unless rule.knowledge_source_ids.present?
      ids = Array(rule.knowledge_source_ids).first(5)
      KnowledgeSource.where(id: ids, account_id: rule.account_id).limit(5).map do |ks|
        { id: ks.id, title: ks.title, kind: ks.kind, snippet: ks.snippet.to_s.first(800) }
      end
    end

    def http_post_with_retries(url:, token:, body:, timeout:, max_retries:)
      attempts = 0
      begin
        attempts += 1
        started = Time.current
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = timeout
        http.read_timeout = timeout
        req = Net::HTTP::Post.new(uri.request_uri)
        req["Authorization"] = "Bearer #{token}" if token.present?
        req["Content-Type"] = "application/json"
        req["Accept"] = "application/json"
        req["X-Workmori-Rule-Id"] = body[:rule][:id].to_s
        req.body = body.to_json
        res = http.request(req)
        duration_ms = ((Time.current - started) * 1000).to_i
        if res.code.to_i >= 500 && attempts <= max_retries
          sleep(0.5 * attempts)
          retry
        end
        res.tap { |r| r.instance_variable_set(:@_duration_ms, duration_ms) }
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
        if attempts <= max_retries
          sleep(0.5 * attempts)
          retry
        end
        raise ExecutionError, "Hermes timeout/connrefused after #{attempts} attempts: #{e.class} #{e.message[0,120]}"
      end
    end

    def parse_response(res)
      duration_ms = res.instance_variable_get(:@_duration_ms) || 0
      code = res.code.to_i
      body = res.body.to_s
      if code >= 400
        raise ExecutionError, "Hermes HTTP #{code}: #{body[0,300]}"
      end
      parsed = begin
        JSON.parse(body)
      rescue
        raise ExecutionError, "Hermes returned non-JSON (HTTP #{code}): #{body[0,300]}"
      end
      {
        kind: parsed["kind"] || parsed[:kind] || "custom",
        output: parsed["output"] || parsed[:output] || parsed,
        trace_id: parsed["trace_id"] || parsed[:trace_id] || SecureRandom.uuid,
        duration_ms: duration_ms
      }
    end
  end
end