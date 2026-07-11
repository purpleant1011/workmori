module Platform
  # Platform-facing Hermes integration console.
  #
  # GET  /platform/hermes              → status dashboard
  # GET  /platform/hermes/executions   → recent real-hermes executions
  # POST /platform/hermes/test         → manual smoke test (calls Hermes Agent directly)
  # GET  /platform/hermes/audit        → all automation.hermes.* AuditEvent entries
  class HermesController < BaseController
    def index
      @provider = Automation::Provider.active
      @configured = ENV["HERMES_AGENT_URL"].present? && ENV["HERMES_AGENT_TOKEN"].present?
      @recent_real = AutomationExecution.joins(:automation_rule)
                                        .where(automation_rules: { account_id: Account.pluck(:id) })
                                        .order(created_at: :desc)
                                        .limit(20)
      @provider_label = @provider.name
    end

    def test
      url = ENV["HERMES_AGENT_URL"].to_s
      token = ENV["HERMES_AGENT_TOKEN"].to_s

      if url.blank? || token.blank?
        flash.now[:alert] = "HERMES_AGENT_URL 또는 HERMES_AGENT_TOKEN이 설정되지 않았습니다."
        AuditEvent.create!(
          action: "platform.hermes.test.misconfigured",
          resource_type: "PlatformConfig",
          resource_id: 0,
          metadata: { hint: "set HERMES_AGENT_URL + HERMES_AGENT_TOKEN then restart the server" },
          occurred_at: Time.current
        )
        return redirect_to(platform_hermes_path)
      end

      payload = params[:payload].presence || default_payload
      result, err = run_smoke_test(url: url, token: token, payload: payload)

      AuditEvent.create!(
        action: err ? "platform.hermes.test.failed" : "platform.hermes.test.success",
        resource_type: "PlatformConfig",
        resource_id: 0,
        metadata: { ok: err.nil?, payload: payload, output: result, error: err&.slice(0, 400) },
        occurred_at: Time.current
      )

      if err
        flash[:alert] = "실패: #{err}"
      else
        flash[:notice] = "성공: #{result.to_json.truncate(200)}"
      end
      redirect_to(platform_hermes_path)
    end

    def executions
      @executions = AutomationExecution.order(created_at: :desc).limit(100)
    end

    def audit
      @events = AuditEvent.where("action LIKE ?", "automation.hermes.%")
                          .or(AuditEvent.where("action LIKE ?", "automation.execute.%"))
                          .order(created_at: :desc)
                          .limit(200)
    end

    private

    def default_payload
      { topic: "smoke-test", intent: "ping" }
    end

    def run_smoke_test(url:, token:, payload:)
      timeout = ENV.fetch("HERMES_AGENT_TIMEOUT", 25).to_i
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = timeout
      http.read_timeout = timeout
      req = Net::HTTP::Post.new(uri.request_uri)
      req["Authorization"] = "Bearer #{token}"
      req["Content-Type"] = "application/json"
      req["Accept"] = "application/json"
      req.body = { rule: { id: 0, account_id: 0, intent_kind: "custom" }, payload: payload }.to_json

      res = http.request(req)
      if res.code.to_i >= 400
        return [nil, "HTTP #{res.code}: #{res.body.to_s[0, 200]}"]
      end
      parsed = begin
        JSON.parse(res.body)
      rescue
        { raw: res.body.to_s[0, 400] }
      end
      [parsed, nil]
    rescue => e
      [nil, "#{e.class}: #{e.message[0, 200]}"]
    end
  end
end