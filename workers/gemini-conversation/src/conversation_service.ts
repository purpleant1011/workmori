// Conversation Service — Provider 라우팅 (P1, 2026-07-12)
// 원칙 13, 14: 프로덕션 라우팅 = gemini_api, 개발용만 antigravity

import type { Provider, ProviderKind, ProviderRequest, ProviderResponse } from "./provider.js";
import { GeminiApiProvider } from "./gemini_api_provider.js";
import { AntigravityAgentProvider } from "./antigravity_agent_provider.js";
import { AntigravityCliDevProvider } from "./antigravity_cli_dev_provider.js";

interface FeatureFlagSnapshot {
  antigravityCliEnabled: boolean;
  geminiProviderActive: boolean;
}

export class ConversationService {
  private providers: Map<ProviderKind, Provider> = new Map();

  constructor(
    featureFlags: FeatureFlagSnapshot,
    config: {
      gemini: { apiKey?: string; projectId?: string; model: string; fallbackModel?: string; thinking?: "low" | "medium" | "high"; timeoutMs: number };
      antigravity: { agentUrl?: string; model: string };
      antigravityCliPath?: string;
    }
  ) {
    if (featureFlags.geminiProviderActive) {
      this.providers.set(
        "gemini_api",
        new GeminiApiProvider({
          apiKey: config.gemini.apiKey,
          projectId: config.gemini.projectId,
          model: config.gemini.model,
          fallbackModel: config.gemini.fallbackModel,
          thinking: config.gemini.thinking,
          timeoutMs: config.gemini.timeoutMs,
        })
      );
    }

    // 원칙 14: antigravity_cli_dev는 명시적 플래그가 있을 때만
    if (featureFlags.antigravityCliEnabled && config.antigravityCliPath) {
      if (process.env.NODE_ENV === "production") {
        throw new Error("antigravity_cli_dev MUST NOT load in production");
      }
      this.providers.set(
        "antigravity_cli_dev",
        new AntigravityCliDevProvider(
          { model: config.antigravity.model, timeoutMs: 30_000 },
          config.antigravityCliPath,
          config.antigravity.model
        )
      );
    }

    // antigravity_agent는 dev에서만 (원칙 12)
    if (process.env.NODE_ENV !== "production" && config.antigravity.agentUrl) {
      this.providers.set(
        "antigravity_agent",
        new AntigravityAgentProvider({ apiKey: config.antigravity.agentUrl, model: config.antigravity.model, timeoutMs: 30_000 })
      );
    }
  }

  listAvailable(): ProviderKind[] {
    return Array.from(this.providers.keys());
  }

  async invoke(kind: ProviderKind, req: ProviderRequest): Promise<ProviderResponse> {
    const provider = this.providers.get(kind);
    if (!provider) {
      throw new Error(`Provider ${kind} not registered`);
    }
    return provider.invoke(req);
  }
}