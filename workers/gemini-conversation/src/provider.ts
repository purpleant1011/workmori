// Gemini Provider 인터페이스 + 3개 구현체 골격 (P1, 2026-07-12)
// 원칙 12, 13: 프로덕션 = GeminiApi / Antigravity = 개발용
// 원칙 14: Antigravity CLI는 feature flag 아래만
// 원칙 15: 모델 ID/Provider 코드 하드코딩 금지

export type ProviderKind = "gemini_api" | "antigravity_agent" | "antigravity_cli_dev";

export interface ProviderConfig {
  apiKey?: string;
  projectId?: string;
  model: string;
  fallbackModel?: string;
  thinking?: "low" | "medium" | "high";
  timeoutMs: number;
}

export interface ConversationTurn {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface ProviderRequest {
  businessProfileId: number;
  messages: ConversationTurn[];
  structuredOutput?: "inquiry" | "change_request" | "content_draft" | "free";
  contextMemories?: Array<{ id: number; scope: string; kind: string; content: string }>;
}

export interface ProviderResponse {
  text: string;
  structured?: Record<string, unknown>;
  provider: ProviderKind;
  model: string;
  usage?: { inputTokens: number; outputTokens: number };
}

export interface Provider {
  readonly kind: ProviderKind;
  readonly isReady: boolean;
  invoke(req: ProviderRequest): Promise<ProviderResponse>;
}