# Discord-Native 확장 — 최종 아키텍처 (2단계)

> 기준: `current_system_audit.md` (1단계)
> 핵심 원칙: **대화 내용을 바로 DB에 쓰지 않고, 변경 제안과 사용자 확인을 거쳐 적용**

---

## 5계층 구조

```
┌─────────────────────────────────────────────────────────┐
│ A. Discord Gateway  (workers/discord-gateway, Node/TS)  │
│    - Discord 이벤트 수신 / Interaction / Outbound        │
└────────────────────────┬────────────────────────────────┘
                         │ HTTPS (Bearer + idempotency key)
                         ▼
┌─────────────────────────────────────────────────────────┐
│ B. Rails Control Plane  (Rails 8, 기존 + 확장)          │
│    - 원문 이벤트 / 세션 / ChangeProposal / Runtime /     │
│      AuditEvent / Hermes Queue / 승인 카드               │
└─────┬─────────────────────────┬─────────────────────────┘
      │                         │
      │ HTTPS (gRPC/REST)       │ HTTPS (Hermes MCP)
      ▼                         ▼
┌─────────────────────┐  ┌──────────────────────────────┐
│ C. Gemini           │  │ D. Hermes Orchestrator       │
│    Conversation     │  │    (Hermes Agent + MCP)      │
│    Service          │  │    - Runtime Config 로딩     │
│    - 응답 / 분류 /   │  │    - 예약 실행 / 외부 채널   │
│      변경 추출 /     │  │      MCP / 보고 / 복구       │
│      콘텐츠 초안     │  └──────────┬───────────────────┘
└─────────────────────┘             │
                                    │ API/MCP (승인된 것만)
                                    ▼
                    ┌───────────────────────────────────┐
                    │ E. External Channel Adapters      │
                    │    Discord, Instagram, Threads,    │
                    │    Naver Blog/Place, Daangn,       │
                    │    상담 연결 채널                  │
                    └───────────────────────────────────┘
```

---

## A. Discord Gateway (`workers/discord-gateway/`)

Node.js + TypeScript + discord.js. 단일 프로세스, launchd/Docker로 상시 실행.

### 책임

1. Discord Gateway WebSocket 연결 (`discord.js` Client)
2. 메시지 / Interaction / 버튼 / 모달 / 슬래시 명령 수신
3. 사용자·Guild·Channel·Thread 식별
4. Discord Identity ↔ Account 매핑 검증 (사전 캐시 + 폴링)
5. **이벤트 중복 방지** (idempotency_key: `guild_id:channel_id:message_id`)
6. typing 표시 (응답 생성 중)
7. 원문 이벤트를 **Rails 내부 API** (`POST /api/v1/discord/events`)로 전달
8. **Outbound**: Rails `Outbound Queue`를 폴링하여 Discord에 메시지 발송
9. 429 Retry-After 준수
10. 재연결 시 Resume (세션 상태 저장)
11. **한 메시지 실패가 Bot 전체를 중단하지 않도록 격리** (per-message try/catch)

### 디렉터리

```
workers/discord-gateway/
  src/
    index.ts                  # 진입점
    discord_client.ts         # discord.js Client 래퍼
    event_handler.ts          # messageCreate / interactionCreate 등
    interaction_handler.ts    # 버튼/모달/슬래시
    outbound_worker.ts        # Rails Outbound Queue 폴링
    permission_guard.ts       # Discord 사용자 → Account 매핑
    rate_limit_handler.ts     # 429 처리
    config.ts                 # ENV 로딩
    logger.ts                 # 구조화 로그 (pino)
  package.json
  tsconfig.json
  Dockerfile
```

### 통신 프로토콜

**Inbound (Discord → Rails)**

```
POST /api/v1/discord/events
Authorization: Bearer <SERVICE_ACCOUNT_TOKEN>
Content-Type: application/json
X-Idempotency-Key: <guild_id>:<channel_id>:<message_id>

{
  "event_type": "MESSAGE_CREATE",
  "account_id": 10,
  "guild_id": "...",
  "channel_id": "...",
  "thread_id": null,
  "discord_message_id": "...",
  "discord_user_id": "...",
  "content": "...",
  "attachments": [...],
  "occurred_at": "2026-07-12T10:00:00Z",
  "raw_payload_b64": "..."   # AES-GCM 암호화된 원본
}
```

**Outbound (Rails → Discord)**

Rails는 `discord_outbound_jobs` 테이블에 작업 적재 → Gateway가 `GET /api/v1/discord/outbound?since=...` 폴링 → 처리 후 ACK (`POST /api/v1/discord/outbound/:id/ack`).

---

## B. Rails Control Plane (기존 + 확장)

### 책임 (기존 재사용 + 신규)

| 책임 | 위치 | 비고 |
|---|---|---|
| 원문 이벤트 저장 | `discord_message_events` 테이블 (신규) | raw_payload_encrypted |
| 고객사 ↔ Discord 공간 연결 | `discord_workspaces`, `discord_identities` (신규) | 1:1 |
| 대화 세션 | `conversation_sessions` (신규) | Discord thread ↔ Conversation |
| 변경 제안 | `change_proposals`, `change_approvals` (신규) | Draft 단계 |
| 승인 카드 (Discord UI) | 인터랙션 핸들러 + `discord_outbound_job` | 버튼 |
| 사업장 지식 | 기존 `knowledge_sources/documents/chunks` | 재사용 |
| Runtime Config | 기존 `runtime_configs` + v2 스키마 | v1→v2 확장 |
| Hermes 작업 큐 | `automation_executions` 재사용 | |
| 감사 로그 | 기존 `audit_events` | `actor_kind: "discord_user"` 추가 검토 |

### Discord Outbound 큐 패턴

- `discord_outbound_jobs` 테이블 (신규): `id, account_id, kind (message/embed/button_response/modal/defer), target_channel_id, payload_json, status (queued/sent/failed/dead), attempts, error_message, scheduled_at, sent_at`
- Solid Queue의 `discord_outbound` 큐에서 워커가 폴링 → 처리
- Gateway는 폴링 기반 (단방향 푸시보다 Rails 컨트롤 단순)

---

## C. Gemini Conversation Service (`workers/gemini-conversation/`)

### 책임

1. **대화 응답** (general chat, business_fact, brand_preference 등)
2. **메시지 의미 분류** (12종)
3. **변경 후보 추출** (ChangeProposal JSON)
4. **콘텐츠 초안 작성** (Feed/Reel/Blog/Thread/Place/Daangn/Cardnews/Shortform)
5. **문의 분류** (inquiry routing)
6. **구조화 JSON 출력** (Function Calling 또는 strict JSON schema)
7. **DB 직접 수정 금지** (오직 Rails API로만 영향)
8. **시스템 프롬프트는 코드/DB 모두에서 동적으로 로드** (Runtime Config에서)

### 디렉터리

```
workers/gemini-conversation/
  src/
    provider.ts                  # GeminiProvider 인터페이스
    gemini_api_provider.ts       # 프로덕션 기본
    antigravity_agent_provider.ts # 복잡한 장기 작업
    antigravity_cli_dev_provider.ts # dev-only
    conversation_service.ts      # 4가지 호출 조율
    change_extractor.ts          # 변경 추출
    content_writer.ts            # 콘텐츠 작성
    safety_classifier.ts         # 분류 + 안전
    config.ts
  package.json
  tsconfig.json
```

### Rails 호출

```
POST /api/v1/gemini/call
{
  "provider": "gemini_api",
  "model": "gemini-3.5-flash",
  "thinking": "low",
  "task": "converse" | "extract_change" | "generate_content" | "classify_inquiry" | "summarize_report",
  "context": { ... }
}
```

Rails는 **서비스 어카운트 인증 + IP 화이트리스트**로만 허용.

---

## D. Hermes Orchestrator

기존 `HERMES_AGENT_URL`/`HERMES_AGENT_TOKEN` Bearer 호출 유지 + **`sohee-control-mcp`** 신규 추가.

### MCP 도구 (초기 노출 화이트리스트)

| 도구 | 용도 | 권한 |
|---|---|---|
| `get_active_runtime_config` | 활성 Runtime 조회 | OK |
| `list_pending_jobs` | 작업 큐 조회 | OK |
| `claim_job` | 작업 인수 | OK |
| `submit_job_result` | 결과 제출 | OK |
| `request_human_review` | 사람 검토 요청 | OK |
| `save_content_draft` | 콘텐츠 초안 저장 | OK |
| `save_inquiry_classification` | 문의 분류 저장 | OK |
| `report_knowledge_gap` | 지식 공백 보고 | OK |
| `post_discord_report` | Discord 보고 | OK |
| `report_agent_health` | 헬스 체크 | OK |

### MCP 도구 (초기 비노출)

`delete_runtime_config`, `modify_credentials`, `delete_customer_data`, `publish_without_approval`, `change_contract`, `change_billing`, `change_user_permissions`

### 보안

- MCP 설정에 `include` 화이트리스트만 명시
- `supports_parallel_tool_calls: false` 초기값
- 고객사마다: account_id, agent_id, runtime_config, secret namespace, job queue **완전 분리**
- 모든 호출은 AuditEvent 기록

---

## E. External Channel Adapters

기존 `app/services/channels/` 활용. 신규:

- **Discord**: 사용자 메시지 송수신 (주로 A 계층 처리), 길드 메시지 / DM
- **Instagram / Threads / Naver / Daangn / 카카오**: 기존 어댑터 호출 (변경 없음)
- **상담 연결 채널**: 운영팀 콘솔 / Handoff 큐

> ⚠️ **승인 없이 게시 금지**. 모든 발행은 `ApprovalRequest` 또는 `ChangeApproval`을 거쳐야 함.

---

## 컨텍스트 분리 (절대 원칙)

```
┌──────────────────────────────────────────────────────┐
│ owner_conversation_context      (대표 ↔ 소희, 원본)   │
│   ↓ 분리                                           │
│ verified_business_knowledge     (승인된 사실)         │
│ content_generation_context      (공개 콘텐츠용)        │
│ customer_response_context       (고객 응대용 공개분)   │
│ internal_operations_context     (운영/Hermes 내부)    │
└──────────────────────────────────────────────────────┘
```

- Discord 원문은 **감사 로그 + 원재료**
- 활성 Runtime에는 **검증되고 승인된 구조화 정보만** 포함
- 컨텍스트는 4종 분리 캐시, 절대 혼용 금지

---

## 런타임 안정성

- Discord 장애 → Rails/Hermes 정상 동작 (큐에 쌓여 있다가 복구 시 처리)
- Rails 장애 → Gemini Worker는 작업 중단, 재시작 시 미처리 작업 재처리
- Hermes 장애 → 자동 게시는 보류, 수동 재시도 큐에 적재
- Gemini 장애 → 안전 메시지 응답 + 재시도 큐

---

## 디렉터리 변경 요약

### 신규

- `workers/discord-gateway/`
- `workers/gemini-conversation/`
- `workers/sohee-control-mcp/`
- `docs/discord/*`
- `launchd/` (plist)
- `docker-compose.yml` (선택)

### 수정

- `config/routes.rb` — `api/v1` namespace 추가, discord/* 라우트
- `.env.example` — `DISCORD_*`, `SOHEE_GEMINI_*`, `HERMES_MCP_*`
- `app/models/runtime_config.rb` — `snapshot_v2_for(account)` 추가
- `Gemfile` — `google-genai` (프로덕션), `discord.js` (workers, npm)

### 미변경 (재사용)

- 모든 AccountScoped 모델
- AuditEvent, RuntimeConfig(v1), RuntimeHeartbeat, ChannelConnection, ContentItem, Conversation, Message, Handoff, AutomationRule, KnowledgeSource/Document/Chunk, Embedding, Faq, BrandConfig, GuardrailPolicy, EscalationRule, SafetyLog, ModelPolicy, ModelCatalogEntry, PromptTemplate, IndustryTemplate, Account, User, Membership, PlatformStaff, PlatformSession, ServiceAccount, MagicLink, ApiToken, FeatureFlag, MagicLink, Session

---

## 다음 단계

→ `data_flow.md`: 메시지 수신 → 응답 / 변경 제안 / 승인 / Runtime 반영 / Hermes 동기화 / Discord 보고의 전체 시퀀스 다이어그램.