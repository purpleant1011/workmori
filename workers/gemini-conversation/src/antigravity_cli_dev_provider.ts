// Antigravity CLI Dev Provider (개발 전용 — 원칙 12, 14 절대 위반 금지)
// Feature flag "antigravity_cli_enabled" 가 true 일 때만 인스턴스화 가능

import type { Provider, ProviderConfig, ProviderKind, ProviderRequest, ProviderResponse } from "./provider.js";

export class AntigravityCliDevProvider implements Provider {
  readonly kind: ProviderKind = "antigravity_cli_dev";
  private readonly cliPath: string;

  constructor(config: ProviderConfig, cliPath: string) {
    this.config = config;
    this.cliPath = cliPath;
  }

  get isReady(): boolean {
    return Boolean(this.cliPath);
  }

  async invoke(_req: ProviderRequest): Promise<ProviderResponse> {
    if (!this.isReady) {
      return {
        text: "(antigravity_cli_dev stub) ANTIGRAVITY_CLI_PATH not set",
        provider: this.kind,
        model: this.config.model,
      };
    }
    // 실제 구현: child_process.spawn(this.cliPath, [...])
    // 프로덕션 부트 시점에 이 Provider가 로딩 시도되면 panic
    return {
      text: `(antigravity_cli_dev stub) TODO: spawn ${this.cliPath} — DEV ONLY`,
      provider: this.kind,
      model: this.config.model,
    };
  }

  private readonly config: ProviderConfig;
}