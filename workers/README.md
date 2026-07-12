# Workmori Workers (Discord-Native, P1)

> **공식 인터페이스 = Discord / Source of Truth = Rails 8 / 언어 모델 = Gemini / 오케스트레이터 = Hermes Agent**

## 왜 분리하나
- Rails 앱과 메시지 I/O를 분리해 봇 장애가 DB/웹을 망가뜨리지 않도록 격리
- 봇·언어 모델·오케스트레이터를 독립 스케일링
- TypeScript 런타임의 동시성/네트워크 라이브러리가 Discord WebSocket/Gemini HTTPS에 적합

## 구성

| 경로 | 역할 | 언어 |
|---|---|---|
| `workers/discord-gateway/` | Discord WebSocket + Interactions 송수신, 권한/레이트 리미트/중복 방지 | TypeScript + discord.js |
| `workers/gemini-conversation/` | 대화 응답·분류·변경 후보·콘텐츠 작성 | TypeScript + @google/genai |
| `workers/sohee-control-mcp/` | Hermes Agent가 호출하는 MCP 도구 10종 | TypeScript + stdio |

## 개발 메모

```bash
cd workers
pnpm install
pnpm dev:discord        # workers/discord-gateway/src/index.ts
pnpm dev:gemini         # workers/gemini-conversation/src/index.ts (HTTP)
pnpm dev:mcp            # stdio, Hermes Agent만 부름
```

## 사람 단계 (운영자가 직접)

| # | 항목 | 어디서 |
|---|---|---|
| 1 | Discord Application 생성 | https://discord.com/developers/applications |
| 2 | Bot Token 발급 | Bot 탭 → Reset Token |
| 3 | Privileged Intent 활성화 | Bot 탭 → MESSAGE CONTENT INTENT / SERVER MEMBERS INTENT |
| 4 | 테스트 서버에 Bot 초대 | OAuth2 → URL Generator |
| 5 | Gemini Google Cloud Project 선택 | https://console.cloud.google.com |
| 6 | Auth Key 또는 Service Account 생성 | IAM & Admin → Service Accounts |
| 7 | Secret 등록 | macOS Keychain 또는 회사 secret manager |
| 8 | 실제 고객 Category 권한 승인 | Discord UI |
| 9 | 실제 SNS 공식 계정 연결 | Meta/Threads 개발자 콘솔 |

> 가짜 값으로 테스트 안 함. 실제 Secret 제공 전에는 실행 안 됨.

## 15 원칙 (요약)

1. 저장소 전체 조사 우선 (✅ P0에서 완료)
2. 조사 전 코드 수정 금지 (✅ P0에서 완료)
3. 기존 모델 최대 재사용 (BusinessProfile/AiEmployee/KnowledgeSource/RuntimeConfig/AuditEvent/ChannelConnection/FeatureFlag/encrypts)
4. 실제 데이터/인증 정보 로그 금지
5. Discord 메시지 = 신뢰 불가능 외부 입력
6. Discord 메시지로 시스템 프롬프트/도구 권한 변경 불가
7. Gemini는 Rails DB 직접 수정 불가 (변경 후보 생성 → 사람 승인 → Rails 작업만)
8. Gemini는 SNS/Discord/파일 시스템 직접 실행 불가 (MCP/API만)
9. 영구 변경 = 제안 → 확인 → 적용
10. 고객사 간 완전 격리 (모든 쿼리에 `business_id`)
11. Discord 장애가 Rails/Hermes 손상 안 시킴 (이중화 가능한 큐)
12. Antigravity CLI OAuth = 프로덕션 대화 런타임 사용 금지
13. 프로덕션 Gemini = 공식 Gemini API
14. Antigravity CLI = 개발용 feature flag 아래만 (`antigravity_cli_enabled`, 기본 false)
15. 모델 ID/Provider 코드 하드코딩 금지 (`ModelCatalogEntry` / `FeatureFlag`)

## 환경 변수

`.env.example` 참조 (절대 커밋 안 함). 필수:

- `DISCORD_BOT_TOKEN` — 사람 단계 #2에서 발급
- `DISCORD_APPLICATION_ID`, `DISCORD_PUBLIC_KEY` — 사람 단계 #1에서 발급
- `DISCORD_GATEWAY_SERVICE_TOKEN` — 우리 측 생성 (openssl rand -hex 32)
- `GEMINI_API_KEY` 또는 `GOOGLE_CLOUD_PROJECT_ID` + Service Account — 사람 단계 #5~6
- `HERMES_MCP_TOKEN` — 우리 측 생성
- `RAILS_INTERNAL_API_BASE` — `https://peripheral-oasis-certificates-antiques.trycloudflare.com` (개발) / 운영 도메인