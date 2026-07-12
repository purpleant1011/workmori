# Discord-Native 확장 — Hermes 통합 (7단계)

> 기준: `architecture.md` (2단계), `data_flow.md` (3단계)
> 핵심: **Hermes MCP는 include 화이트리스트만. 절대 parallel tool calls로 권한 우회 불가.**

---

## 1. 현재 Hermes 연동

`HERMES_AGENT_URL` + `HERMES_AGENT_TOKEN` Bearer 호출.

- `Platform::HermesController` — 운영 콘솔 (대시보드/스모크/실행/감사)
- `app/services/automation/provider.rb` — Provider 인터페이스
- `app/services/automation/real_hermes_adapter.rb` — 실제 호출
- `app/services/automation/fake_hermes_adapter.rb` — 개발용 stub

**부재**: Hermes Agent → Rails 외부 API (api/v1), MCP 도구 정의, 작업 큐 동기화, Runtime Sync ACK.

---

## 2. 신규: sohee-control-mcp (`workers/sohee-control-mcp/`)

Node.js + TypeScript, stdio 또는 HTTP 양방향 지원.

### 디렉터리

```
workers/sohee-control-mcp/
  src/
    server.ts                  # MCP 서버 진입점
    config.ts                  # ENV 로딩
    auth.ts                    # 토큰 검증
    tools/
      get_active_runtime_config.ts
      list_pending_jobs.ts
      claim_job.ts
      submit_job_result.ts
      request_human_review.ts
      save_content_draft.ts
      save_inquiry_classification.ts
      report_knowledge_gap.ts
      post_discord_report.ts
      report_agent_health.ts
  package.json
  tsconfig.json
```

### 서버 등록 (Hermes 측)

```json
{
  "name": "sohee-control",
  "transport": "http",
  "url": "https://sohee.example.com/api/v1/mcp",
  "auth": {
    "type": "bearer",
    "token": "<HERMES_MCP_TOKEN from Keychain>"
  },
  "include_tools": [
    "get_active_runtime_config",
    "list_pending_jobs",
    "claim_job",
    "submit_job_result",
    "request_human_review",
    "save_content_draft",
    "save_inquiry_classification",
    "report_knowledge_gap",
    "post_discord_report",
    "report_agent_health"
  ],
  "exclude_tools": [
    "delete_runtime_config",
    "modify_credentials",
    "delete_customer_data",
    "publish_without_approval",
    "change_contract",
    "change_billing",
    "change_user_permissions"
  ],
  "supports_parallel_tool_calls": false,
  "rate_limit_per_minute": 30,
  "namespace_per_account": true,
  "version": "1.0.0"
}
```

### 서버 측 진입점 (Rails)

```
POST /api/v1/mcp/invoke
Authorization: Bearer <HERMES_MCP_TOKEN>
Content-Type: application/json

{
  "tool": "claim_job",
  "agent_id": "<hermes_agent_id>",
  "account_id": 10,
  "params": { "job_id": 1234 }
}
```

응답:

```json
{
  "ok": true,
  "data": { "runtime_config_id": 42, "checksum": "...", "bundle_json": {...} },
  "rate_limit_remaining": 27
}
```

---

## 3. 도구 명세 (초기 10개)

### 3.1 get_active_runtime_config

**용도**: Hermes가 현재 사업장 Runtime을 가져와 실행에 사용.

```typescript
// workers/sohee-control-mcp/src/tools/get_active_runtime_config.ts
export const getActiveRuntimeConfig = {
  name: "get_active_runtime_config",
  description: "현재 사업장의 활성화된 Runtime Config와 bundle_json을 반환합니다.",
  parameters: {
    type: "object",
    properties: {
      account_id: { type: "integer" },
      agent_id: { type: "string" }
    },
    required: ["account_id", "agent_id"]
  },
  
  async handler(args, ctx: McpContext): Promise<unknown> {
    // 권한 확인: agent_id가 account_id에 매핑되어 있는지
    await ctx.requireAgentAccess(args.account_id, args.agent_id);
    
    const runtime = await railsApi.get(`/api/v1/accounts/${args.account_id}/runtime_configs/active`);
    return {
      runtime_config_id: runtime.id,
      version: runtime.version,
      checksum: runtime.checksum,
      bundle_json: runtime.bundle_json,
      activated_at: runtime.activated_at
    };
  }
};
```

**반환 예**:

```json
{
  "runtime_config_id": 42,
  "version": "v7",
  "checksum": "sha256:abc...",
  "bundle_json": {
    "schema_version": "2.0",
    "business_id": "cafe-sohee",
    "agent": { "persona_key": "cafe-casual", ... },
    "business_profile": { ... },
    "verified_knowledge": { ... },
    ...
  },
  "activated_at": "2026-07-12T10:00:00Z"
}
```

### 3.2 list_pending_jobs

**용도**: 처리 대기 중인 자동화 작업 목록.

```typescript
{
  "name": "list_pending_jobs",
  "params": {
    "account_id": 10,
    "agent_id": "...",
    "limit": 20
  },
  "returns": [
    {
      "job_id": 1234,
      "kind": "post",          // post | reply | report | faq_update
      "scheduled_at": "2026-07-12T18:00:00Z",
      "priority": "normal",
      "payload": { "topic": "신메뉴", "channel": "instagram" }
    }
  ]
}
```

### 3.3 claim_job

**용도**: 작업을 인수하여 다른 Hermes가 중복 처리하지 못하게.

```typescript
{
  "name": "claim_job",
  "params": {
    "account_id": 10,
    "agent_id": "...",
    "job_id": 1234
  },
  "returns": {
    "job_id": 1234,
    "claimed_at": "...",
    "expires_at": "...",        // 30분 후 자동 만료
    "payload": { ... }
  }
}
```

**Rails 측**: `AutomationExecution.update!(claimed_by_agent: agent_id, claimed_at: now, expires_at: 30.minutes.from_now)`. 동시 요청은 row lock으로 1개만 성공.

### 3.4 submit_job_result

**용도**: 작업 처리 결과 보고.

```typescript
{
  "name": "submit_job_result",
  "params": {
    "account_id": 10,
    "agent_id": "...",
    "job_id": 1234,
    "result": {
      "status": "success",      // success | partial | failed | needs_human
      "output": { "post_url": "...", "engagement_id": "..." },
      "error": null,
      "artifacts": [{ "kind": "image", "url": "..." }]
    }
  },
  "returns": { "ok": true, "execution_id": 5678 }
}
```

### 3.5 request_human_review

**용도**: 사람 검토가 필요한 상황 보고.

```typescript
{
  "name": "request_human_review",
  "params": {
    "account_id": 10,
    "agent_id": "...",
    "job_id": 1234,
    "reason": "이미지에 고객 얼굴이 감지되어 사람 검토 필요",
    "priority": "high"
  },
  "returns": {
    "review_request_id": 99,
    "discord_message_id": "..."   // 운영팀 Discord에 자동 게시
  }
}
```

### 3.6 save_content_draft

**용도**: 초안 콘텐츠 저장 (게시 X).

```typescript
{
  "name": "save_content_draft",
  "params": {
    "account_id": 10,
    "agent_id": "...",
    "title": "...",
    "body": "...",
    "caption": "...",
    "hashtags": ["#카페", "#신메뉴"],
    "image_brief": "...",
    "content_kind": "feed",
    "target_channel_kind": "instagram"
  },
  "returns": {
    "content_item_id": 201,
    "status": "draft",
    "discord_review_message_id": "..."
  }
}
```

**자동 처리**: ContentItem 생성 (state: draft) → Discord #콘텐츠-검수에 검수 카드 전송.

### 3.7 save_inquiry_classification

**용도**: 문의 분류 결과 저장.

```typescript
{
  "name": "save_inquiry_classification",
  "params": {
    "account_id": 10,
    "agent_id": "...",
    "conversation_id": 567,
    "message_id": 890,
    "category": "refund",
    "needs_human": true,
    "priority": "high",
    "reason": "시술 후 알레르기 발생"
  },
  "returns": {
    "handoff_id": 12,             // 자동 생성된 경우
    "discord_alert_message_id": "..."
  }
}
```

### 3.8 report_knowledge_gap

**용도**: 지식 공백 보고 (학습 권장).

```typescript
{
  "name": "report_knowledge_gap",
  "params": {
    "account_id": 10,
    "agent_id": "...",
    "topic": "화환 케이크 가격",
    "frequency": 5,               // 주 5회 반복 질문
    "sample_questions": ["화환 케이크 얼마예요?"]
  },
  "returns": { "knowledge_gap_id": 7 }
}
```

**자동 처리**: KnowledgeGap INSERT + Discord #자료-업로드에 알림.

### 3.9 post_discord_report

**용도**: Discord 채널에 보고 메시지 게시.

```typescript
{
  "name": "post_discord_report",
  "params": {
    "account_id": 10,
    "agent_id": "...",
    "channel": "daily_report",     // daily_report | incident | content_published
    "embed": {
      "title": "...",
      "fields": [...]
    }
  },
  "returns": {
    "discord_message_id": "..."
  }
}
```

**권한 검증**: Bot이 해당 채널에 게시할 수 있는지 화이트리스트로 확인.

### 3.10 report_agent_health

**용도**: Hermes Agent가 자신의 상태 보고.

```typescript
{
  "name": "report_agent_health",
  "params": {
    "agent_id": "...",
    "account_id": 10,
    "status": "ok",                 // ok | degraded | down
    "open_jobs": 3,
    "failed_jobs_24h": 0,
    "channels_authenticated": ["instagram", "threads"],
    "channels_failed": []
  },
  "returns": { "heartbeat_id": 789 }
}
```

**자동 처리**: RuntimeHeartbeat INSERT → 운영팀 콘솔에 표시.

---

## 4. 권한 매트릭스 (계정별 격리)

### 고객사마다 분리

| 분리 대상 | 메커니즘 |
|---|---|
| `account_id` | 모든 도구 호출에 필수 |
| `agent_id` | agent_id ↔ account_id 매핑 검증 |
| `runtime_config` | active 한 개만, 다른 사업장 접근 불가 |
| `secret namespace` | 외부 채널 토큰 (Meta, Naver) 사업장별 |
| `job queue` | Solid Queue에서 `account_id` 기반 필터링 |

### agent_id ↔ account_id 매핑

`AgentRegistration` 테이블 (신규):

```ruby
{
  agent_id: "hermes-agent-cafe-sohee-01",
  account_id: 10,
  registered_at: <timestamp>,
  last_seen_at: <timestamp>,
  status: "active" | "suspended",
  capabilities: ["post", "reply", "report"],
  ip_whitelist: ["10.0.0.0/24"]
}
```

Rails는 모든 MCP 호출에서:
1. Bearer 토큰 검증 (HERMES_MCP_TOKEN)
2. agent_id가 account_id에 등록되어 있는지 검증
3. IP 화이트리스트 (선택)
4. AuditEvent 기록

### 미등록 agent_id 호출

→ 403 Forbidden + AuditEvent(action: mcp.unauthorized_agent)

---

## 5. supports_parallel_tool_calls: false (초기)

**이유**: 동시 호출로 인한 race condition 방지. 

- Runtime Config가 activate되는 동안 claim_job, submit_job_result가 동시에 호출되면 race 발생
- Hermes 측에서 도구 호출은 **순차 처리**되어야 함

```typescript
// workers/hermes-agent/src/mcp_client.ts
async function invokeTool(tool: string, params: any): Promise<any> {
  // 순차 큐
  await this.queue.lock();
  try {
    return await this.mcpInvoke(tool, params);
  } finally {
    this.queue.unlock();
  }
}
```

운영 안정화 후 검토.

---

## 6. Runtime Config 동기화 흐름

### Runtime 변경 시

```
[B. Rails Control Plane]
  ChangeProposal.apply! (사용자 승인 후)
     │
     │  ① RuntimeConfig.new(status: draft)
     │  ② bundle_json 컴파일 (v2 스키마)
     │  ③ checksum 계산
     │  ④ validate_runtime (안전성 검사)
     │  ⑤ activate! → 이전 active → archived
     │  ⑥ AuditEvent
     │  ⑦ Enqueue: DispatchHermesJob
     ▼
[Job] DispatchHermesJob
     │  POST https://hermes-agent.example.com/notify_runtime_change
     │  Authorization: Bearer <HERMES_TOKEN>
     │  {
     │    "account_id": 10,
     │    "runtime_config_id": 42,
     │    "version": "v7",
     │    "checksum": "...",
     │    "bundle_url": "https://sohee.example.com/api/v1/accounts/10/runtime_configs/42/bundle"
     │  }
     ▼
[Hermes Agent]
     │  ① Bundle URL에서 fetch
     │  ② checksum 검증
     │  ③ 로컬 캐시 무효화
     │  ④ 새 Runtime으로 실행 전환
     │  ⑤ POST https://sohee.example.com/api/v1/hermes/ack
     │    { "runtime_config_id": 42, "agent_id": "...", "status": "ok" }
     ▼
[B. Rails]
     │  RuntimeSync INSERT (status: acknowledged)
     │  AuditEvent
     │  Discord #확인-승인 채널에 "✅ 동기화 완료" 메시지
```

### Hermes ACK 미수신

```
[B] DispatchHermesJob 후 30분 동안 RuntimeSync.status='pending'
     │
     │  만료 시 재시도 (3회까지, 1시간 간격)
     │  최종 실패 시 Incident 생성 + 운영팀 Discord 알림
     │
[Discord #장애-알림]
  운영팀: "Hermes 동기화 실패 — Cafe Sohee v7. 확인 필요."
```

---

## 7. Runtime Rollback

```
[Discord #확인-승인 채널]
  사업자/운영자: "직전 버전으로 되돌려줘"
     │
[B] DiscordInteractionsController
     │  ① 권한 확인 (owner 또는 operator)
     │  ② RuntimeConfig.active → rolled_back
     │  ③ RuntimeConfig.where(version < current).where(status='archived').last → active
     │  ④ AuditEvent(action: runtime.rollback)
     │  ⑤ Enqueue: DispatchHermesJob (notify_rollback)
     ▼
[Hermes]  Bundle 재로딩 + ACK
     │
[B]  RuntimeSync INSERT + Discord 보고
```

### 데이터 보존

- 모든 RuntimeConfig 버전은 영구 보존
- Rollback 후에도 새 버전 유지 (재활성화 가능)

---

## 8. 작업 실행 흐름 (콘텐츠 발행 예)

```
[시간 도달: 18:00]
     │
[Job] AutomationExecution.tick (Solid Queue)
     │  ① @execution = AutomationExecution.find(job_id)
     │  ② RuntimeConfig.current_for(account) 로딩
     │  ③ ContentKind 확인 (feed/reel/blog/...)
     │  ④ Hermes에 claim_job 요청 (MCP)
     ▼
[Hermes]  claim_job OK
     │
[B]  Hermes 작업 실행:
     │  ① MCP get_active_runtime_config
     │  ② verified_knowledge 검색
     │  ③ ContentItem 초안 생성 (Gemini.generate_content)
     │  ④ MCP save_content_draft
     │  ⑤ Discord 검수 카드 게시
     │  ⑥ 사용자 승인 대기
     ▼
[Discord #콘텐츠-검수]
  사업자: "게시"
     │
[B]  발행 작업:
     │  ① Hermes MCP로 채널 어댑터 호출 (Instagram/Threads/Naver)
     │  ② Hermes MCP post_publish_result (또는 별도 도구)
     │  ③ ContentItem.state = published
     │  ④ Discord 보고: "✅ 발행 완료 (URL)"
     │  ⑤ AuditEvent
```

> ⚠️ **초기 MVP에서는 SNS 공식 계정에 게시하지 않음**. dry-run 또는 sandbox만. Hermes MCP `publish_to_channel` 도구는 **비활성** 상태로 시작.

---

## 9. Secret 관리 (Hermes 측)

### Hermes가 보관하는 토큰

| 토큰 | 용도 | 저장 |
|---|---|---|
| `HERMES_MCP_TOKEN` | Rails API 호출 인증 | macOS Keychain |
| `META_LONG_LIVED_TOKEN_<account_id>` | Instagram/Threads | Hermes 측 vault |
| `NAVER_CLIENT_ID/SECRET_<account_id>` | Naver | Hermes 측 vault |
| `DAANGN_API_KEY_<account_id>` | Daangn | Hermes 측 vault |

### Rails이 보관하는 토큰 (변경 없음)

- `encrypted_token` (ChannelConnection)
- 운영 콘솔 인증 토큰

### Hermes에서 Rails로

- `HERMES_MCP_TOKEN`만 사용
- 다른 Rails 내부 토큰 불필요

---

## 10. 감사 로그 (모두)

Rails AuditEvent에 다음 action 기록:

| Action | 의미 |
|---|---|
| `mcp.tool.invoked` | 도구 호출 |
| `mcp.unauthorized_agent` | 미등록 agent_id |
| `mcp.rate_limit_exceeded` | 분당 한도 초과 |
| `runtime.activated` | Runtime 활성화 |
| `runtime.rollback` | Runtime 롤백 |
| `runtime.sync_requested` | Hermes 동기화 요청 |
| `runtime.sync_acknowledged` | Hermes ACK |
| `runtime.sync_failed` | Hermes ACK 실패 |
| `hermes.job.claimed` | 작업 인수 |
| `hermes.job.completed` | 작업 완료 |
| `hermes.job.failed` | 작업 실패 |
| `hermes.agent.heartbeat` | Agent 상태 보고 |
| `hermes.knowledge_gap.reported` | 지식 공백 보고 |
| `hermes.inquiry.classified` | 문의 분류 |

---

## 11. 환경변수

```
# Rails 측
HERMES_AGENT_URL=https://hermes-agent.example.com
HERMES_AGENT_TOKEN=<Keychain>
HERMES_MCP_TOKEN=<Keychain>           # Hermes → Rails API 인증
HERMES_AGENT_TIMEOUT=25

# Hermes 측 (별도 저장소)
SOHEE_RAILS_URL=https://sohee.example.com
SOHEE_RAILS_MCP_TOKEN=<Keychain>
SOHEE_MCP_PARALLEL_TOOL_CALLS=false
SOHEE_MCP_RATE_LIMIT_PER_MIN=30
```

---

## 12. 보안 검증

### 테스트 시나리오

`test/integration/hermes/mcp_security_test.rb`:

1. **미등록 agent_id**: 403 + AuditEvent
2. **다른 사업장 Runtime 조회**: 403 + AuditEvent
3. **rate_limit 초과**: 429 + AuditEvent
4. **잘못된 checksum Runtime**: 거부 + Hermes에 재요청
5. **concurrent claim_job**: 1개만 성공 (row lock)
6. **expired job claim**: 거부
7. **parallel tool calls**: 순차 처리 확인
8. **delete_runtime_config 호출 시도**: 도구 미노출 확인
9. **publish_without_approval 호출 시도**: 도구 미노출 확인

---

## 13. 사람 단계

1. **Hermes Agent 측 저장소에 `workers/sohee-control-mcp/` 클론**
2. **MCP 서버 빌드** (`pnpm build`)
3. **Hermes 측 config에 sohee-control 등록**
4. **`HERMES_MCP_TOKEN` 발급 + 양 측 저장**
5. **테스트 호출** (`scripts/test-mcp.ts`)
6. **운영 환경에 등록**

---

## 다음 단계

→ `implementation_plan.md` — P0~P6 우선순위, 단계별 작업, 완료 기준