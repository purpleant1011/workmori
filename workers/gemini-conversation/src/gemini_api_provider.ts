// Gemini API Provider (프로덕션, 원칙 13)
// 사람 단계 #5, #6: GEMINI_API_KEY 또는 Service Account 필요

import type { Provider, ProviderConfig, ProviderKind, ProviderRequest, ProviderResponse } from "./provider.js";

export class GeminiApiProvider implements Provider {
  readonly kind: ProviderKind = "gemini_api";
  private readonly config: ProviderConfig;

  constructor(config: ProviderConfig) {
    this.config = config;
  }

  get isReady(): boolean {
    return Boolean(this.config.apiKey || this.config.projectId);
  }

  async invoke(req: ProviderRequest): Promise<ProviderResponse> {
    if (!this.isReady) {
      return this.stub(req, "GeminiApiProvider not configured — set GEMINI_API_KEY or GOOGLE_CLOUD_PROJECT_ID");
    }
    // 실제 구현: @google/genai 호출
    // const client = new GoogleGenAI({ apiKey: this.config.apiKey, project: this.config.projectId });
    // const response = await client.models.generateContent({...});
    // MVP 단계에서는 stub — 사람 단계 후 실 SDK 호출 추가
    return this.stub(req, "TODO: wire @google/genai SDK");
  }

  private stub(req: ProviderRequest, note: string): ProviderResponse {
    const last = req.messages[req.messages.length - 1];
    return {
      text: `(gemini_api stub) [${note}] 마지막 메시지: ${last?.content ?? "(empty)"}`,
      provider: this.kind,
      model: this.config.model,
      structured: { intent: "conversational", confidence: 0.0, note },
      usage: { inputTokens: 0, outputTokens: 0 },
    };
  }
}