# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# AntigravityClient — 워커 gemini-conversation 호출 헬퍼 (P3, 2026-07-12)
# Discord 응답 / SNS 글 작성에서 사용
# 워커는 :7100 에서 /invoke 수신, antigravity_cli_dev provider 로 agy CLI spawn
module AntigravityClient
  class Error < StandardError; end

  WORKER_URL = ENV.fetch("GEMINI_WORKER_URL", "http://localhost:7100/invoke")
  DEFAULT_TIMEOUT = 30 # 초

  # provider 우선순위:
  # 1. antigravity_cli_dev (agy CLI + OAuth, Gemini Pro 구독 토큰)
  # 2. gemini_api (GEMINI_API_KEY 환경변수, 유료 API)
  def self.provider
    return "antigravity_cli_dev" if FeatureFlags.enabled?(:antigravity_cli_enabled)
    return "gemini_api" if FeatureFlags.enabled?(:sohee_gemini_provider_active)
    "gemini_api" # fallback
  end

  def self.invoke(business_profile_id:, messages:, structured_output: "free", context_memories: [], timeout: DEFAULT_TIMEOUT)
    payload = {
      provider: provider,
      payload: {
        businessProfileId: business_profile_id,
        messages: messages,
        structuredOutput: structured_output,
        contextMemories: context_memories
      }
    }

    uri = URI.parse(WORKER_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = timeout

    req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
    req.body = payload.to_json

    res = http.request(req)
    raise Error, "worker returned #{res.code}: #{res.body}" unless res.code == "200"

    JSON.parse(res.body)
  rescue Errno::ECONNREFUSED
    raise Error, "워커에 연결할 수 없음 — gemini-conversation 워커 실행 상태 확인 필요 (URL: #{WORKER_URL})"
  rescue Net::OpenTimeout
    raise Error, "워커 응답 시간 초과 (#{timeout}초)"
  end
end
