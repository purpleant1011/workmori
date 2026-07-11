# 소희 프로젝트 — 현재 시스템 감사

**작성일**: 2026-07-12
**범위**: Meta Graph API (Instagram + Threads) 통합을 위한 기존 Rails 시스템 분석

---

## 1. 환경

| 항목 | 값 |
|---|---|
| Ruby | 3.4.10 (arm64-darwin27, PRISM) |
| Rails | 8.0.5 |
| DB | PostgreSQL 16.14 (Homebrew, aarch64-apple-darwin25.4.0, Apple clang 21) |
| Node | v22.22.3 |
| Cache | `ActiveSupport::Cache::MemoryStore` (dev), production 미확인 |
| Queue | `solid_queue` gem 선언, 마이그레이션 부재 — **큐 워커 미가동 가능성** |
| Hermes | default 프로필, MiniMax-M3, gateway timeout 1800s |

## 2. 기존 모델 (Meta 통합 관련)

### 2.1 채널·콘텐츠·자동화 (이미 존재 — 토대 OK)

| 모델 | 주요 컬럼 | 비고 |
|---|---|---|
| `ChannelConnection` | account_id, kind, handle, external_id, **encrypted_token (Active Record Encryption)**, status, scopes_json, last_verified_at, connected_by_kind | `KINDS = %w[discord instagram threads blog naver_place daangn kakao_channel email mastodon]` — instagram/threads 포함 |
| `ChannelScope` | channel_connection_id, publish_allowed 등 | 세분화 권한 관리 |
| `ContentItem` | account_id, ai_employee_id, automation_rule_id, title, body, caption, hashtags_json, content_kind, state, safety_state, evidence_chunks_json, target_channel_kind, scheduled_at, published_external_url | 상태머신 추정 |
| `AutomationRule` | account_id, ai_employee_id, intent_kind, structured_plan (jsonb), constraints, status, approved_by_user_id, approved_at | 승인 기반 |
| `Conversation` | account_id, ai_employee_id, channel_connection_id, channel_kind, external_thread_id, risk_level, last_message_at, escalated_at, detected_locale | DM/댓글 통합 |
| `Message` | account_id, conversation_id, direction, author_kind, body, redacted_body_json, ai_draft, evidence_chunks_json, state, redacted_at | PII redaction 슬롯 |
| `Inquiry` | subject, body, subject_kind, score, status | 퍼블릭 문의 |
| `WebhookEndpoint` | account_id, kind, url, secret_digest, state, last_called_at | webhook 등록 메타 |

### 2.2 보안·감사·승인 (이미 존재)

| 모델 | 용도 |
|---|---|
| `ApprovalRequest` | 사람 승인 흐름 |
| `AuditEvent` | `ACTOR_KINDS = %w[user anon automation system operator]` — 모든 변경 작업 추적 |
| `SafetyLog` | 안전 검사 로그 |
| `GuardrailPolicy` | 금지어/민감 표현 룰 |
| `RuntimeConfig` | 버전 관리 + checksum + bundle_json |
| `RuntimeHeartbeat` | 런타임 상태 |
| `EscalationRule` | 사람 인계 룰 |

### 2.3 지식·콘텐츠 파이프라인

| 모델 | 용도 |
|---|---|
| `BrandConfig` | 브랜드 톤/CTA |
| `KnowledgeDocument`, `KnowledgeSource`, `KnowledgeGap`, `DocumentChunk`, `Embedding` | RAG 파이프라인 |
| `PromptTemplate`, `ModelCatalogEntry`, `ModelPolicy` | LLM 라우팅 |
| `IndustryTemplate` | 업종별 템플릿 (6종 시드) |

## 3. 기존 서비스 레이어

| 파일 | 역할 | Meta 통합 상태 |
|---|---|---|
| `app/services/channels/adapter.rb` | 채널 어댑터 인터페이스 | OK |
| `app/services/channels/instagram_adapter.rb` (158 lines) | Instagram 게시·검증 | **mock fallback** — ENV 토큰 없으면 mock. 실제 Graph API 호출 코드는 존재 (`post_media_container`, `post_media_publish`) |
| `app/services/channels/threads_adapter.rb` (174 lines) | Threads 게시·검증 | **mock fallback** — ENV 토큰 없으면 mock. `post_container`, `post_publish` 구현 |
| `app/services/channels/publisher.rb` | 통합 게시 게이트웨이 | OK |
| `app/services/channels/generic_adapter.rb`, `naver_adapter.rb`, `kakao_adapter.rb`, `mastodon_adapter.rb` | 기타 채널 | — |
| `app/services/content/pipeline.rb` | 콘텐츠 파이프라인 (16단계 추정) | 존재 |
| `app/services/engagement/automator.rb` | 댓글 자동화 | 존재 — 댓글 응대 토대 |
| `app/services/response_composer.rb` | AI 답변 합성 | 존재 |
| `app/jobs/engagement_tick_job.rb` | 폴링 잡 | 존재 |

## 4. 기존 ENV (Meta 관련 placeholder)

```bash
# .env 또는 .env.example (확인됨)
META_GRAPH_API_TOKEN=                # 비어있음 — 장기 토큰 필요
META_GRAPH_API_VERSION=v19.0
THREADS_ACCESS_TOKEN=                # 비어있음
THREADS_USER_ID=                     # 비어있음
THREADS_API_VERSION=v1.0
```

**문제**: 토큰을 ENV로 직접 관리 → 다중 사업장/공식화 단계에서 확장 불가. **DB 암호화 저장 + OAuth 갱신** 구조로 전환 필요.

## 5. Hermes 설정

`~/.hermes/config.yaml`:
- `toolsets`: terminal, file, web, todo (현재)
- Meta 관련 MCP 서버 **미등록**
- `parallel_tool_call`: 환경별 설정 가능

## 6. ★ 미비 사항 (Meta 통합 차단 요소)

| 카테고리 | 현재 | 필요 |
|---|---|---|
| OAuth 시작/콜백 | ❌ 없음 | `/app/channels/:kind/connect` → Meta OAuth → `/app/channels/oauth/callback` |
| 토큰 갱신 | ❌ 없음 | 60일 만료 전 자동 refresh, 갱신 실패 시 status: error + 사람 알림 |
| Token vault | ⚠️ `encrypted_token` 컬럼만 있음 (Rails AR Encryption 작동 확인) | 사업장별 격리 OK, refresh_at + last_error 컬럼 추가 필요 |
| Webhook 수신 | ❌ 컨트롤러 없음 (`webhook_endpoint` 모델만) | `POST /webhooks/instagram`, `POST /webhooks/threads` + verify token + signature + idempotency |
| Signature 검증 | ❌ 없음 | `X-Hub-Signature-256` HMAC-SHA256 |
| Idempotency | ❌ 없음 | `external_id` UNIQUE 또는 `idempotency_key` |
| 속도 제한 | ❌ 없음 | Meta Graph 자체 제한(200/시간/user) + 우리 측 안전 제한 |
| 재시도 | ⚠️ engagement_tick_job 추정 | exponential backoff + dead-letter |
| MCP 서버 | ❌ 없음 | `workers/sohee-meta-mcp` 신규 |
| Hermes MCP 등록 | ❌ 없음 | config에 `sohee_meta` 추가 |
| App Review 준비 | ❌ 없음 | 테스트 계정, 시연 절차, 개인정보처리방침, 데이터 삭제 URL |
| 고정 tunnel | ❌ 없음 (cloudflared 임시만 사용 추정) | 고정 도메인 또는 고정 Cloudflare Tunnel |

## 7. 채널·사용자 격리 현황

- `ChannelConnection.account_id` — 사업장별 격리 OK
- `encrypts :encrypted_token` — DB 평문 방지 OK
- `AuditEvent.account_id` 추정 — 감사 로그 사업장 격리 OK
- PII redaction (`Message.redacted_body_json`) — 슬롯만 존재, 정책 정의 필요

## 8. 결론

**토대는 충분**. 채널 어댑터, 콘텐츠 파이프라인, 자동화·승인·감사·인계 구조가 이미 갖춰져 있음. **부족한 것은**:

1. **OAuth 플로우** (가장 시급 — 토큰을 사업장별로 안전하게 발급/갱신)
2. **Webhook 수신 + signature + idempotency**
3. **MCP 서버** (Hermes → MCP → Rails → Meta의 좁은 도구 표면)
4. **App Review 준비 자산** (체크리스트·시연 절차)
5. **고정 tunnel + 도메인** (trycloudflare 폐기)
6. **DM 단계 권한** (`instagram_business_manage_messages`) — Phase 5