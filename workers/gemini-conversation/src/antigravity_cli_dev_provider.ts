// Antigravity CLI Dev Provider (개발 전용 — 원칙 12, 14 절대 위반 금지)
// Feature flag "antigravity_cli_enabled" 가 true 일 때만 인스턴스화 가능
//
// P3 Antigravity OAuth 통합 (2026-07-12):
// - 사용자가 이미 `agy` 바이너리 + OAuth 인증 완료 상태
// - spawn agy -p "<prompt>" 로 Gemini Pro 응답 받기
// - ~/.gemini/oauth_creds.json 자동 사용 (agy 가 자체 관리)

import { spawn } from "node:child_process";
import type { Provider, ProviderConfig, ProviderKind, ProviderRequest, ProviderResponse } from "./provider.js";
import { logger } from "./logger.js";

export class AntigravityCliDevProvider implements Provider {
  readonly kind: ProviderKind = "antigravity_cli_dev";
  private readonly cliPath: string;
  private readonly config: ProviderConfig;
  private readonly defaultModel: string;

  constructor(config: ProviderConfig, cliPath: string, defaultModel = "Gemini 3.1 Pro (High)") {
    this.config = config;
    this.cliPath = cliPath;
    this.defaultModel = defaultModel;
  }

  get isReady(): boolean {
    return Boolean(this.cliPath);
  }

  private buildPrompt(req: ProviderRequest): string {
    const parts: string[] = [];
    if (req.contextMemories && req.contextMemories.length > 0) {
      parts.push("[메모리 참고]");
      for (const m of req.contextMemories) {
        parts.push(`- (${m.scope}/${m.kind}) ${m.content}`);
      }
      parts.push("");
    }
    parts.push("[대화]");
    for (const turn of req.messages) {
      parts.push(`${turn.role}: ${turn.content}`);
    }
    if (req.structuredOutput) {
      parts.push("");
      parts.push(`[출력 형식: ${req.structuredOutput} — 가능한 경우 JSON 으로 답해]`);
    }
    return parts.join("\n");
  }

  async invoke(req: ProviderRequest): Promise<ProviderResponse> {
    if (!this.isReady) {
      return {
        text: "(antigravity_cli_dev stub) ANTIGRAVITY_CLI_PATH not set",
        provider: this.kind,
        model: this.config.model,
      };
    }

    const prompt = this.buildPrompt(req);
    const args = ["-p", prompt, "--model", this.defaultModel];
    const timeoutMs = this.config.timeoutMs ?? 30_000;

    logger.info("antigravity_cli_dev invoke", { cli: this.cliPath, args: ["-p", "...", "--model", this.defaultModel], timeoutMs });

    return new Promise<ProviderResponse>((resolve) => {
      const child = spawn(this.cliPath, args, {
        env: { ...process.env },
        stdio: ["ignore", "pipe", "pipe"],
      });

      let stdout = "";
      let stderr = "";
      const timer = setTimeout(() => {
        child.kill("SIGKILL");
        resolve({
          text: `(antigravity_cli_dev timeout after ${timeoutMs}ms)`,
          provider: this.kind,
          model: this.defaultModel,
        });
      }, timeoutMs);

      child.stdout.on("data", (chunk: Buffer) => (stdout += chunk.toString()));
      child.stderr.on("data", (chunk: Buffer) => (stderr += chunk.toString()));

      child.on("error", (err) => {
        clearTimeout(timer);
        logger.error("antigravity_cli_dev spawn error", { err: String(err) });
        resolve({
          text: `(antigravity_cli_dev spawn error: ${String(err)})`,
          provider: this.kind,
          model: this.defaultModel,
        });
      });

      child.on("close", (code) => {
        clearTimeout(timer);
        if (code !== 0) {
          logger.warn("antigravity_cli_dev non-zero exit", { code, stderr: stderr.slice(0, 500) });
          resolve({
            text: stderr || `(antigravity_cli_dev exit ${code})`,
            provider: this.kind,
            model: this.defaultModel,
          });
          return;
        }
        resolve({
          text: stdout.trim(),
          provider: this.kind,
          model: this.defaultModel,
        });
      });
    });
  }
}
