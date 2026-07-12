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
    cliPath: process.env.ANTIGRAVITY_CLI_PATH ?? "",
    agentUrl: process.env.ANTIGRAVITY_AGENT_URL ?? "",
    model: "antigravity-default",
  },
} as const;