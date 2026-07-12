export const config = {
  gemini: {
    apiKey: process.env.GEMINI_API_KEY ?? "",
    projectId: process.env.GOOGLE_CLOUD_PROJECT_ID ?? "",
    model: process.env.SOHEE_GEMINI_DEFAULT_MODEL ?? "gemini-3.5-flash",
    fallbackModel: process.env.SOHEE_GEMINI_FALLBACK_MODEL ?? "",
    thinking: (process.env.SOHEE_GEMINI_DEFAULT_THINKING as "low" | "medium" | "high" | undefined) ?? "low",
    timeoutMs: Number(process.env.GEMINI_REQUEST_TIMEOUT ?? "30") * 1000,
  },
  antigravity: {
    // P3 Antigravity CLI OAuth 통합 (2026-07-12):
    // 기본값 = "agy" (PATH 의 /Users/hochari/.local/bin/agy)
    // 사용자가 OAuth 인증 완료 시 자동으로 ~/.gemini/oauth_creds.json 사용
    cliPath: process.env.ANTIGRAVITY_CLI_PATH ?? "agy",
    agentUrl: process.env.ANTIGRAVITY_AGENT_URL ?? "",
    model: process.env.ANTIGRAVITY_DEFAULT_MODEL ?? "Gemini 3.1 Pro (High)",
  },
} as const;