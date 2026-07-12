# Discord-Native 확장 — 구현 계획 (8단계)

> 기준: 1~7단계 문서 전체
> 원칙: **사람이 직접 해야 하는 단계는 자동으로 추측하지 않고 멈춰서 보고**

---

## 우선순위 매트릭스

| 우선순위 | 범위 | 목표 |
|---|---|---|
| **P0** | 감사/문서/데이터 모델/Provider 구조/보안 모델 | 기본 설계 + 사람 단계 식별 |
| **P1** | Discord Gateway + 사용자 연결 + 메시지 저장 + Gemini 응답 | Discord에서 1:1 대화 가능 |
| **P2** | 변경 후보 추출 + 승인 카드 + 적용/취소 + 감사 로그 | Discord에서 설정 변경 가능 |
| **P3** | Runtime Config v2 + Hermes Sync + ACK + Rollback | Runtime 자동 배포 |
| **P4** | 콘텐츠 검수 + 문의 인계 + 일일 보고 | 일상 운영 자동화 |
| **P5** | Instagram/Threads 테스트 + 게시/댓글 + 인사이트 | 외부 채널 실연동 (테스트) |
| **P6** | 다중 고객사 + 모니터링 + 비용/SLA + 보안 강화 | 운영 등급 |

---

## P0 — 설계 + 사람 단계 식별 ✅ 거의 완료

### 상태: 진행 중

| 항목 | 상태 |
|---|---|
| `docs/discord/current_system_audit.md` | ✅ 완료 |
| `docs/discord/architecture.md` | ✅ 완료 |
| `docs/discord/data_flow.md` | ✅ 완료 |
| `docs/discord/security_model.md` | ✅ 완료 |
| `docs/discord/discord_server_template.md` | ✅ 완료 |
| `docs/discord/gemini_provider_strategy.md` | ✅ 완료 |
| `docs/discord/hermes_integration.md` | ✅ 완료 |
| `docs/discord/implementation_plan.md` | ✅ 본 문서 |
| Discord App 생성 | ⏸ 사람 단계 |
| Bot Token 발급 | ⏸ 사람 단계 |
| Privileged Intent 활성화 | ⏸ 사람 단계 |
| Gemini Google Cloud Project | ⏸ 사람 단계 |
| Auth Key/Service Account 생성 | ⏸ 사람 단계 |
| `.env.example` 업데이트 | ⏸ 코드 단계 (가짜 값 X) |
| 데이터 모델 7개 마이그레이션 | ⏸ 코드 단계 |
| Provider 인터페이스 골격 | ⏸ 코드 단계 |

### P0 완료 기준

- 8개 문서 모두 main 머지 ✅
- 사람 단계 식별 + 사용자에게 보고 ✅
- 사용자가 Discord/Gemini Secret 제공 (또는 보류 결정) 대기

### 사람이 제공해야 하는 값

```
DISCORD_APPLICATION_ID=
DISCORD_BOT_TOKEN=
DISCORD_PUBLIC_KEY=
DISCORD_GATEWAY_SERVICE_TOKEN=          # Rails 측, 우리 생성
DISCORD_GATEWAY_ALLOWED_IPS=            # 선택

GEMINI_API_KEY=
GOOGLE_CLOUD_PROJECT_ID=

HERMES_MCP_TOKEN=                       # 우리 생성
HERMES_AGENT_URL=                       # Hermes Agent 측 제공
HERMES_AGENT_TOKEN=                     # Hermes Agent 측 제공
```

**가짜 값은 절대 만들지 않음**. 사람이 값을 제공할 때까지 코드 단계는 대기.

---

## P1 — Discord Gateway + 기본 대화

### 작업 목록

| # | 작업 | 비고 |
|---|---|---|
| 1 | `workers/discord-gateway/` 디렉터리 + package.json + tsconfig.json | 신규 |
| 2 | `discord_client.ts` (discord.js Client 래퍼) | 신규 |
| 3 | `event_handler.ts` (MESSAGE_CREATE, INTERACTION_CREATE) | 신규 |
| 4 | `outbound_worker.ts` (Rails Outbound 큐 폴링) | 신규 |
| 5 | `permission_guard.ts` (Discord Identity 매핑) | 신규 |
| 6 | `rate_limit_handler.ts` (429 처리) | 신규 |
| 7 | Rails `Api::V1::DiscordEventsController` | 신규 |
| 8 | Rails `DiscordMessageEvent` 모델 + 마이그레이션 | 신규 |
| 9 | Rails `DiscordIdentity` 모델 + 마이그레이션 | 신규 |
| 10 | Rails `ConversationSession` 모델 + 마이그레이션 | 신규 |
| 11 | Rails `discord_outbound_jobs` 테이블 + 마이그레이션 | 신규 |
| 12 | Rails `DiscordOutboundJob` 워커 (Solid Queue) | 신규 |
| 13 | Rails `GenerateDiscordReplyJob` | 신규 |
| 14 | `workers/gemini-conversation/` + Provider 골격 | 신규 |
| 15 | Rails `Api::V1::GeminiController` (서비스 토큰 인증) | 신규 |
| 16 | `GeminiApiProvider` (converse 구현) | 신규 |
| 17 | `ModelRouter` (Runtime Config 기반) | 신규 |
| 18 | Discord ↔ Rails 인증 (ServiceAccountToken + IP) | 신규 |
| 19 | FeatureFlag: `discord_gateway_enabled`, `sohee_mcp_enabled` | 시드 |
| 20 | 운영 매니페스트 (launchd 또는 Docker Compose) 골격 | 신규 |
| 21 | 통합 테스트 (Discord 모의) | 신규 |
| 22 | E2E 테스트 (테스트 서버, 실제 Gemini 호출) | 신규 |

### P1 완료 기준

1. Discord 테스트 서버 연결 ✅
2. 테스트 사업자와 Discord 사용자 매핑 ✅
3. #소희-대화에서 메시지 수신 ✅
4. Gemini API로 응답 (실제 호출) ✅
5. 대화 원문 Rails 저장 ✅
6. 응답이 Discord에 표시 ✅

### 첫 MVP 정의 (사용자 명시)

> "MVP 단계에서는 SNS 공식 계정에 게시하지 않는다."

→ P1은 **응답까지만**. 발행·변경 적용은 P2 이후.

---

## P2 — 변경 후보 추출 + 승인 카드

### 작업 목록

| # | 작업 |
|---|---|
| 1 | `ChangeProposal`, `ChangeApproval`, `BusinessMemory` 모델 + 마이그레이션 |
| 2 | `Gemini.extract_change()` 구현 |
| 3 | `ExtractChangeProposalJob` |
| 4 | `ChangeProposalApplier` (Rails transaction + AuditEvent + Runtime Draft) |
| 5 | Discord 승인 카드 Embed 생성기 |
| 6 | 5종 버튼 (적용/수정/이번만/운영팀 검토/취소) Interaction 핸들러 |
| 7 | 수정 Modal |
| 8 | 이번만 / 영구 구분 로직 |
| 9 | Discord Workspace ↔ Account 매핑 (`DiscordWorkspace` 모델) |
| 10 | `Security` 검증 (path/risk_level/confidence) |

### P2 완료 기준

1. Discord에서 "영업시간 바꿔줘" 메시지 → ChangeProposal 생성
2. 승인 카드 표시
3. [적용] → DB 반영 + Runtime Draft → AuditEvent
4. [취소] → ChangeProposal cancelled
5. [이번만] → Runtime 변경 없이 작업 큐만

---

## P3 — Runtime Config v2 + Hermes Sync

### 작업 목록

| # | 작업 |
|---|---|
| 1 | `snapshot_v2_for(account)` 메서드 (기존 v1 확장) |
| 2 | v2 스키마 정의 (16개 섹션) |
| 3 | `RuntimeConfig.new.activate!` 트랜잭션 강화 |
| 4 | `RuntimeSync` 모델 + 마이그레이션 |
| 5 | `DispatchHermesJob` (notify_runtime_change) |
| 6 | Hermes ACK API (`POST /api/v1/hermes/ack`) |
| 7 | Runtime Rollback (`status: rolled_back` + 이전 active 복귀) |
| 8 | `CompileRuntimeConfigJob` (Draft 생성) |
| 9 | `RuntimeConfig.validate_runtime` (안전성 검사) |
| 10 | `RuntimeHeartbeat` 통합 (Hermes Agent → Rails) |
| 11 | Hermes 측 `workers/sohee-control-mcp/` 초기 10개 도구 |
| 12 | MCP 보안 (agent_id ↔ account_id 매핑) |
| 13 | MCP rate limiting |

### P3 완료 기준

1. RuntimeConfig v2 Bundle 생성/활성화
2. Hermes 동기화 요청 + ACK
3. Runtime Rollback → 이전 active 복귀 → Hermes ACK

---

## P4 — 콘텐츠 검수 + 문의 인계 + 일일 보고

### 작업 목록

| # | 작업 |
|---|---|
| 1 | `Gemini.generate_content` 구현 |
| 2 | `Gemini.classify_inquiry` 구현 |
| 3 | `ContentItem` draft 생성 + Discord 검수 카드 |
| 4 | `Handoff` 자동 생성 (민감 문의) |
| 5 | `daily_report` Job (Discord 일일 보고) |
| 6 | `weekly_report` Job (Discord 주간 보고) |
| 7 | KnowledgeGap 자동 보고 |
| 8 | Forum Channel (#요청-수정) Thread 자동 생성 |
| 9 | 임시 캠페인 만료 자동 처리 (야간 Reconciliation) |

### P4 완료 기준

1. Discord #콘텐츠-검수에 초안 카드 표시
2. [게시] → ContentItem.published (Hermes 호출은 mock, 실제 SNS 미게시)
3. 민감 문의 자동 Handoff
4. 일일 보고 자동 생성

---

## P5 — 외부 채널 실연동 (테스트)

### 작업 목록

| # | 작업 |
|---|---|
| 1 | Instagram 테스트 계정 연결 (Meta App + Sandbox) |
| 2 | Threads 테스트 계정 |
| 3 | Naver 블로그/플레이스 테스트 |
| 4 | Daangn 테스트 |
| 5 | `Hermes.post_to_channel` 도구 활성화 (테스트 계정만) |
| 6 | 댓글 자동 응답 (Polling/Webhook) |
| 7 | 인사이트 수집 |
| 8 | 오류 복구 (재시도, 백오프) |

### P5 완료 기준

1. 테스트 Instagram 계정에 실제 게시 ✅
2. 댓글 자동 응답 ✅
3. 일일 인사이트 보고 ✅

### 사람 단계

- Meta App ID/Secret
- Long-lived User Token
- Naver Client ID/Secret
- 실제 테스트 계정 ID/비밀번호

---

## P6 — 운영 등급

### 작업 목록

| # | 작업 |
|---|---|
| 1 | 다중 고객사 동시 운영 검증 |
| 2 | 운영자 모니터링 (Sentry + Discord 알림) |
| 3 | 비용/사용량 추적 대시보드 |
| 4 | SLA 모니터링 (응답 시간, 가용성) |
| 5 | 보안 강화 (Penetration Testing 결과 반영) |
| 6 | 백업/복구 절차 |
| 7 | 컴플라이언스 (개인정보, 데이터 보존) |
| 8 | 다중 언어 (i18n) |

---

## 단계별 의사결정 (사용자 확인 필요)

| 결정 | 옵션 | 권장 |
|---|---|---|
| Bot 언어 | TypeScript (discord.js) vs Ruby (discordrb) | TypeScript — 더 성숙 |
| Gemini SDK | `@google/genai` 공식 SDK vs 직접 REST | 공식 SDK |
| Workers 배포 | launchd vs Docker Compose vs k8s | launchd (Mac mini) 또는 Docker Compose |
| MCP 전송 | stdio vs HTTP | HTTP (운영 등급 확장 용이) |
| Runtime v1 호환 | v1 유지 + v2 추가 vs v1 마이그레이션 | v1 유지 + v2 추가 (점진적) |
| 컨텍스트 캐시 | Redis vs 메모리 vs DB | Redis (안정성) — 단, 현재 Redis 미사용. 초기에는 메모리 |
| 이미지 생성 | Imagen 3 vs 외부 API (Midjourney, DALL-E) | Imagen 3 (Gemini 통합) |

---

## 리스크와 완화

| 리스크 | 영향 | 완화 |
|---|---|---|
| Discord Bot Token 유출 | 심각 | macOS Keychain, .env ignore, AuditEvent |
| Gemini API 비용 폭증 | 중간 | UsageRecord 추적, 월 한도, Feature Flag |
| Hermes Agent 장애 | 높음 | 자동 재시도 + 큐, Discord 보고, 사업자 알림 |
| Runtime 충돌 (두 agent가 다른 버전) | 높음 | checksum + ACK + 잠금 |
| 프롬프트 인젝션 | 높음 | 입력 분류 + 시스템 프롬프트 동적 + ChangeProposal 강제 |
| tenant 데이터 유출 | 심각 | account_id default_scope + 테스트 자동화 |

---

## 테스트 전략

### 단위 (각 레이어)

- Provider parse/validate
- ChangeExtractor JSON schema 검증
- RuntimeConfig Draft/Active 전이
- tenant 격리 (AccountScoped)
- idempotency_key 중복

### 통합

- Discord 메시지 → Rails → Gemini → 응답 → Discord
- 변경 카드 → 승인 → Runtime → Hermes ACK

### E2E (테스트 Discord 서버)

1. 일반 대화
2. 영업시간 변경
3. 임시 캠페인
4. 일회성 게시
5. 금지어 추가
6. 민감 문의 인계
7. 변경 취소
8. Runtime 배포
9. Hermes ACK
10. Rollback

### 공격

- 다른 고객사 채널 접근
- 프롬프트 인젝션
- 토큰 요청
- 고객 개인정보 입력
- 중복 이벤트
- 메시지 수정/삭제
- Gemini API 실패
- Discord 429
- Hermes Offline
- Runtime 충돌
- 잘못된 승인 사용자

### CI

- 모든 PR에 보안 테스트 통과 필수
- 프로덕션 시뮬레이션 (개발 환경)

---

## 마일스톤

| 시점 | 마일스톤 |
|---|---|
| 2026-07-12 | P0 문서 완료 (현재) |
| 2026-07-13 | 사람 단계 (Secret 제공) |
| 2026-07-14 | P1 코드 시작 |
| 2026-07-21 | P1 MVP (Discord 일반 대화) |
| 2026-07-28 | P2 MVP (Discord 변경 적용) |
| 2026-08-04 | P3 MVP (Runtime Sync) |
| 2026-08-11 | P4 MVP (콘텐츠/문의/보고) |
| 2026-08-18 | P5 MVP (외부 채널 테스트) |
| 2026-08-25 | P6 (운영 등급) |

(예상 일정 — 사용자 조정 가능)

---

## 현재 상태 (2026-07-12)

### 완료

- 1단계 현재 시스템 감사 ✅
- 2단계 아키텍처 ✅
- 3단계 데이터 흐름 ✅
- 4단계 보안 모델 ✅
- 5단계 Discord 서버 템플릿 ✅
- 6단계 Gemini Provider 전략 ✅
- 7단계 Hermes 통합 ✅
- 8단계 구현 계획 ✅ (본 문서)

### 다음 사용자 결정 필요

1. **Discord Bot Token / Gemini API Key 제공**
   - 제공 시: P1 코드 단계 진행
   - 미제공 시: `.env.example` 업데이트 + 사람 가이드만 작성, 코드 단계는 보류
2. **workers 언어 선택**: TypeScript (권장) 또는 Ruby (discordrb)
3. **Workers 배포 방식**: launchd 또는 Docker Compose
4. **MVP 범위**: 사용자 정의대로 "Discord 테스트 서버 연결 + 메시지 수신 + Gemini 응답 + DB 저장"까지만 (그 외 SNS 게시·변경 적용은 P2+)

### 미완성

- 7개 신규 모델 (DiscordWorkspace/Identity/MessageEvent, ChangeProposal/Approval, BusinessMemory, RuntimeSync)
- 1개 신규 마이그레이션
- 6개 신규 Job
- 3개 Worker 디렉터리
- 5개 신규 컨트롤러
- 3개 신규 Gemini Provider 구현체
- sohee-control-mcp 10개 도구
- 테스트 디렉터리 (현재 `test/` 없음)
- 운영 매니페스트 (launchd 또는 Docker Compose)

---

## 24. 완료 보고 (사용자 요구)

요구된 18개 항목 중 8개는 본 단계에서 문서로 완료. 나머지 10개는 코드 단계에서.

1. ✅ 현재 시스템 감사 → `current_system_audit.md`
2. ✅ 새 아키텍처 → `architecture.md`
3. ⏸ 추가한 모델 → P1~P3 마이그레이션 후
4. ⏸ 추가한 마이그레이션 → P1~P3
5. ⏸ Discord Gateway → P1
6. ⏸ Discord 권한 → P1 + Discord 서버 설정
7. ⏸ Gemini Provider → P1
8. ⏸ 변경 제안 워크플로 → P2
9. ⏸ Runtime Config v2 → P3
10. ⏸ Hermes MCP → P3
11. ⏸ 보안 조치 → P1~P6 누적
12. ⏸ 테스트 결과 → P1~P5 누적
13. ⏸ E2E 결과 → P4~P5
14. ⏸ Mac mini 실행 방법 → P6
15. ⏸ 사람이 해야 하는 단계 → 본 문서 + 서버 템플릿 문서
16. ⏸ 아직 미완성인 항목 → 본 문서
17. ⏸ 커밋 목록 → P1~P6 누적
18. ⏸ 다음 우선순위 → P1 (Discord MVP)

---

## 다음 액션

1. **사용자에게 보고**: "8개 문서 완료. P0 종료. P1 코드 시작 전에 Discord Bot Token + Gemini API Key 필요. 없으면 가짜 값 만들지 않고 사람 가이드만 작성하고 대기. workers 언어 (TypeScript 권장) 및 배포 방식 (launchd/Docker Compose) 결정 요청."
2. 사용자 응답 후 P1 코드 진행.