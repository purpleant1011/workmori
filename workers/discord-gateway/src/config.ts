// 환경 변수 로더 (P1, 2026-07-12)
// 원칙: 가짜 값 안 만듦 — 없으면 즉시 에러

export const config = {
  discord: {
    botToken: process.env.DISCORD_BOT_TOKEN ?? "",
    applicationId: process.env.DISCORD_APPLICATION_ID ?? "",
    publicKey: process.env.DISCORD_PUBLIC_KEY ?? "",
  },
  rails: {
    base: process.env.RAILS_INTERNAL_API_BASE ?? "http://localhost:3000",
    serviceToken: process.env.DISCORD_GATEWAY_SERVICE_TOKEN ?? "",
    allowedIps: (process.env.DISCORD_GATEWAY_ALLOWED_IPS ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean),
  },
  logLevel: process.env.LOG_LEVEL ?? "info",
} as const;

export function requireSecret(name: string, value: string): string {
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}