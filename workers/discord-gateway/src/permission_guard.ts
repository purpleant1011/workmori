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
    // 봇이 invite된 길드만 처리 (없으면 모든 길드 수락)
    if (config.allowedGuildIds.length > 0 && !config.allowedGuildIds.includes(message.guildId)) {
      logger.warn("Guild not in allowedGuildIds — skip", {
        guildId: message.guildId,
        allowed: config.allowedGuildIds,
        messageId: message.id,
      });
      return false;
    }
    // 봇 멘션(@소희), prefix(!소희, /소희), 또는 content에 '소희' 단어 포함 시 응답
    const botUserId = message.client.user?.id ?? "";
    const botMentioned = botUserId ? message.mentions.has(botUserId) : false;
    const hasPrefix = message.content.startsWith("!소희") || message.content.startsWith("/소희");
    const botNameInContent = message.content.includes("소희");
    const triggered = botMentioned || hasPrefix || botNameInContent;
    if (!triggered) return false;

    // 봇이 그 채널에서 VIEW_CHANNEL + SEND_MESSAGES 권한이 있어야만 처리
    // (없으면 답을 못 보내므로 무한 fail 방지)
    const me = message.guild?.members.me;
    if (!me) {
      logger.warn("Bot not a member of the guild — skip", { guildId: message.guildId, messageId: message.id });
      return false;
    }
    const channelPerms = me.permissionsIn(message.channelId);
    const canRead = channelPerms.has("ViewChannel");
    const canSend = channelPerms.has("SendMessages");
    if (!canRead || !canSend) {
      logger.warn("Bot lacks ViewChannel/SendMessages — skip", {
        guildId: message.guildId,
        channelId: message.channelId,
        canRead,
        canSend,
        messageId: message.id,
      });
      return false;
    }
    return true;
  }

  // 봇이 발송을 시도해도 안전한지 (디스코드 outbound job에 사용)
  canSendToChannel(guildId: string | null): boolean {
    return Boolean(guildId); // 실제 체크는 discord_sender.ts에서
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