// Conversation Worker HTTP entrypoint (P1, 2026-07-12)
// 워커는 HTTP 서버로 동작 — Rails가 /api/v1/gemini/call에 보내는 결과를 내부적으로 라우팅

import { config } from "./config.js";
import { ConversationService } from "./conversation_service.js";
import { createServer } from "node:http";
import { logger } from "./logger.js";

async function fetchFeatureFlags(): Promise<{ antigravityCliEnabled: boolean; geminiProviderActive: boolean }> {
  // Rails에서 feature flag 조회
  const base = process.env.RAILS_INTERNAL_API_BASE ?? "http://localhost:3000";
  const res = await fetch(`${base}/api/v1/health`, {
    headers: { "X-Internal-Token": process.env.DISCORD_GATEWAY_SERVICE_TOKEN ?? "" },
  });
  if (!res.ok) return { antigravityCliEnabled: false, geminiProviderActive: true };
  const j = (await res.json()) as { feature_flags?: Record<string, boolean> };
  return {
    antigravityCliEnabled: Boolean(j.feature_flags?.antigravity_cli_enabled),
    geminiProviderActive: Boolean(j.feature_flags?.sohee_gemini_provider_active),
  };
}

async function main() {
  const flags = await fetchFeatureFlags();
  const svc = new ConversationService(flags, {
    gemini: {
      apiKey: config.gemini.apiKey,
      projectId: config.gemini.projectId,
      model: config.gemini.model,
      fallbackModel: config.gemini.fallbackModel,
      thinking: config.gemini.thinking,
      timeoutMs: config.gemini.timeoutMs,
    },
    antigravity: {
      agentUrl: config.antigravity.agentUrl,
      model: config.antigravity.model,
    },
    antigravityCliPath: config.antigravity.cliPath,
  });

  logger.info("Providers ready", { available: svc.listAvailable(), flags });

  const port = Number(process.env.GEMINI_WORKER_PORT ?? 7100);
  const server = createServer(async (req, res) => {
    if (req.method !== "POST" || req.url !== "/invoke") {
      res.writeHead(404).end();
      return;
    }

    let body = "";
    req.on("data", (chunk: Buffer) => (body += chunk.toString()));
    req.on("end", async () => {
      try {
        const req2 = JSON.parse(body) as { provider: "gemini_api" | "antigravity_agent" | "antigravity_cli_dev"; payload: unknown };
        const result = await svc.invoke(req2.provider, req2.payload as never);
        res.writeHead(200, { "Content-Type": "application/json" }).end(JSON.stringify(result));
      } catch (err) {
        res.writeHead(500, { "Content-Type": "application/json" }).end(JSON.stringify({ error: String(err) }));
      }
    });
  });

  server.listen(port, () => logger.info(`gemini-conversation worker listening on :${port}`));
}

main().catch((err) => {
  logger.error("Fatal", { err: String(err) });
  process.exit(1);
});