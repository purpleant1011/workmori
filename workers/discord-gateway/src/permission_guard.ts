// 권한 가드 — 어떤 메시지를 처리할지 결정
// 원칙 5: Discord 메시지 = 신뢰 불가능 외부 입력
// 원칙 10: 고객사 간 격리

import type { Message } from "discord.js";
import { config } from "./config.js";
import { logger } from "./logger.js";

export class PermissionGuard {
  // 허용된 카테고리(sohee-category)에 있는 메시지만 처리
  canReceive(message: Message): boolean {
    if (!message.guildId) {
      logger.warn("DM received — ignored (MVP에서는 서버 메시지만)", { author: message.author.id });
      return false;
    }
    // 멘션 또는 봇 prefix가 있을 때만 응답
    const botMentioned = message.mentions.has(message.client.user?.id ?? "");
    const hasPrefix = message.content.startsWith("!소희") || message.content.startsWith("/소희");
    return botMentioned || hasPrefix;
  }

  // Rate limit: 사용자당 분당 10회
  private readonly userBuckets = new Map<string, { count: number; resetAt: number }>();
  rateLimit(userId: string, perMin: number = 10): boolean {
    const now = Date.now();
    const bucket = this.userBuckets.get(userId);
    if (!bucket || bucket.resetAt < now) {
      this.userBuckets.set(userId, { count: 1, resetAt: now + 60_000 });
      return true;
    }
    if (bucket.count >= perMin) return false;
    bucket.count += 1;
    return true;
  }

  // IP 화이트리스트 (선택)
  isIpAllowed(ip: string): boolean {
    if (config.rails.allowedIps.length === 0) return true;
    return config.rails.allowedIps.includes(ip);
  }
}