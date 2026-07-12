# Discord-Native 확장 — 현재 시스템 감사 (1단계)

> 작성일: 2026-07-12
> 기준 브랜치: `main` @ `65fef9e`
> 조사 원칙: 실제 코드로 확인된 사실만 기록. 추측·기대·미확인 항목은 명시.

---

## 0. 환경

| 항목 | 값 | 출처 |
|---|---|---|
| Ruby | 3.4.10 (PRISM, arm64-darwin27) | `ruby -v` |
| Rails | 8.0.5 | `Gemfile` |
| Database | PostgreSQL 16.x (`pg ~> 1.1`) | `Gemfile`, psql 접속 확인 |
| Background Jobs | Solid Queue (Rails 8 기본) | `Gemfile`, `config/queue.yml` |
| Active Storage | 설치됨 (local 디스크) | `db/migrate/20260711034101_create_active_storage_tables` |
| Credentials | `config/credentials.yml.enc` (Rails encrypted) | `ls config/credentials*` |
| 부트스트랩 토큰 | `WORKMORI_BOOTSTRAP_TOKEN` (`.env.example`) | `.env.example` |
| 모니터링 | `sentry-rails 5.28.1` | `bundle list` |
| launchd 매니페스트 | **없음** | `ls launchd/` ENOENT |
| Docker Compose | **없음** | 저장소 검색 |
| Test 디렉터리 | **없음** | `ls test/` ENOENT |

## 1. 멀티테넌트 / 인증 / 격리

### 모델

| 모델 | 역할 |
|---|---|
| `Account` | 최상위 테넌트(사업장) |
| `User` | 사업장 소속 사용자 (이메일 + 비밀번호) |
| `Membership` | User ↔ Account 다대다 + 권한(`owner/manager/staff/viewer`) |
| `PlatformStaff` | 운영자(퍼플앤트 직원) — 사용자 검색 |
| `PlatformSession` | 운영자 로그인 세션 |
| `ServiceAccount` | 머신 계정(Hermes Agent 등) |
| `MagicLink` | 비밀번호 리셋 / 셀프 가입 |
| `ApiToken` | 외부 API 토큰 |
| `WebhookEndpoint` | 외부 수신 콜백 |
| `Session` | 일반 사용자 세션 |

### 격리 메커니즘

- 모든 주요 모델은 `AccountScoped` concern 적용 → `default_scope where(account_id: current_account.id)`.
- 컨트롤러 베이스:
  - `App::BaseController` — `@current_account` 강제, 미인증 시 로그인 리다이렉트
  - `Platform::BaseController` — `@current_platform_staff` 강제
- `Membership` 4단계 권한: `owner/manager/staff/viewer`
- 운영 방식: **셀프 가입 → 도입 상담 → 운영팀이 사업장 계정 생성 + 셋업 + 테스트 → 공식 전환**

### 비밀 값 관리

| 메커니즘 | 위치 | 비고 |
|---|---|---|
| Rails encrypted credentials | `config/credentials.yml.enc` | master key 별도 |
| Active Record `encrypts` | `payment.rb`, `channel_connection.rb`, `deposit.rb`, `conversation_participant.rb` | `encrypted_token`, `encrypted_metadata`, `refund_bank_info_encrypted`, `encrypted_contact` |
| `.env` | 루트 (git ignore) | `WORKMORI_BOOTSTRAP_TOKEN`, `HERMES_AGENT_URL`, `HERMES_AGENT_TOKEN`, `OPENAI_API_KEY` 등 |
| macOS Keychain | **미사용** | 향후 추가 권장 |

> ⚠️ **Discord Bot Token / Gemini Auth Key는 현재 어디에도 저장되지 않음**. 외부에 노출된 값 없음. 신규 Secret 카테고리 추가 필요.

## 2. 비즈니스 도메인 모델

### 핵심 모델 (AccountScoped)

| 모델 | 핵심 필드 | 비고 |
|---|---|---|
| `BusinessProfile` | `legal_name, trade_name, industry_code, owner_name, phone, address, region_label, timezone, brand_intro, target_audience, differentiators, business_hours_json, holidays_json, products_json, services_json, faqs_json, customer_anxieties_json, forbidden_phrases_json, forbidden_topics_json, escalation_rules_json, preferred_channels_json, settings_json, operator_managed, onboarding_step, onboarding_complete` | 업종 11종 enum, JSON 컬럼 정규화(JsonAttr concern) |
| `AiEmployee` | `name, persona_preset, role_label, tone, language, vocabulary_phrases_json, forbidden_phrases_json, can_answer_topics_json, must_handoff_topics_json, work_days_json, memory_json, status` | has_one_attached :avatar, has_many_attached :reference_images |
| `KnowledgeSource` | `kind (upload/text/url/faq/product), tags_json` | has_many :knowledge_documents, has_one_attached :file |
| `KnowledgeDocument` | `version, checksum_sha256` | has_many :document_chunks |
| `DocumentChunk` | (임베딩 청크) | has_many :embeddings |
| `Embedding` | (벡터) | RAG 검색용 |
| `Faq` | `question, answer, risk_level (low/medium/high), tags_json` | has_one_attached :media |
| `ContentItem` | `title, body, caption, hashtags_json, content_kind (feed/reel_script/blog/thread/place_post/daangn_post/cardnews/shortform), state, safety_state, target_channel_kind, scheduled_at, published_at, published_external_url, source_kind, risk_level` | has_many_attached :media, has_many :content_versions |
| `Conversation` | `channel_kind, customer_display_name, customer_contact_encrypted, state (open/closed), risk_level, last_message_at, locale` | has_many :messages, :handoffs, :participants |
| `Message` | `body, direction (inbound/outbound), author_kind (customer/ai/operator), state (received/drafted/sent/escalated/failed), external_id, attachments_json` | 발신/수신 추적 |
| `Handoff` | `reason, state (open/acknowledged/resolved/abandoned), priority, assigned_to_user_id, resolved_at` | 사람 인계 |
| `AutomationRule` | `name, intent_kind (post/reply/report/faq_update/data_export), state, approval_required, payload_template_json` | has_many :automation_schedules, :executions |
| `AutomationSchedule` | `automation_rule_id, kind (cron/at/interval), expression, next_run_at` | 실행 일정 |
| `AutomationExecution` | `automation_rule_id, content_item_id, state, error_message, attempts` | 실행 기록 |
| `BrandConfig` | 브랜드 톤·금지어·CTA | |
| `GuardrailPolicy` | 안전 정책 | |
| `EscalationRule` | 자동 인계 규칙 | |
| `SafetyLog` | 안전 검사 결과 | |
| `ModelPolicy` | 모델별 정책 | |
| `ModelCatalogEntry` | 모델 카탈로그 (`code, provider, kind, capabilities`) | 동적 모델 선택 |
| `PromptTemplate` | 프롬프트 템플릿 | |
| `IndustryTemplate` | 업종별 템플릿 (`slug, industry_kind, display_name`) | |
| `ChannelConnection` | `kind (discord/instagram/threads/blog/naver_place/daangn/kakao_channel/email/mastodon), handle, external_id, status, scopes_json, encrypted_token, connected_by_kind` | **discord 이미 enum 포함** |
| `ChannelScope` | 채널 권한 범위 | |
| `MediaAsset` | 미디어 자산 | |
| `DeliveryLog` | `kind (daily_report/weekly_report/magic_link/campaign/welcome/reset_password/billing/automation_summary/scheduled_post/manual_post/inquiry_response/system_notice/channel_publish), subject, recipient_count` | 발송 기록 |
| `Notification` | 알림 | |
| `ApprovalRequest` | 승인 요청 (현재는 limited) | ChangeProposal/ChangeApproval의 기초로 활용 가능 |
| `RuntimeConfig` | `version, status (draft/active/archived/rolled_back), checksum, bundle_json, change_summary, activated_by, activated_at, rolled_back_by, rolled_back_at` | **이미 Draft/Active 분리 + Rollback 지원** |
| `RuntimeHeartbeat` | `source (sohee/operator/scheduler), status (ok/degraded/down), open_jobs, failed_jobs_24h, meta_json, checked_at` | Hermes ping |
| `AuditEvent` | `action, resource_type, resource_id, actor_kind (user/anon/automation/system/operator), metadata, occurred_at` | 5 actor_kinds, 운영팀 콘솔 있음 |
| `FeatureFlag` | `key, enabled, account_id (nullable)` | **Antigravity CLI Dev Provider 게이트로 활용** |
| `ContractTerm`, `Plan`, `Subscription`, `Invoice`, `Payment`, `Deposit`, `Budget`, `UsageRecord`, `Referral`, `ReferralLink`, `ReferralReward`, `CsatResponse`, `DataExportRequest`, `DeletionRequest`, `TerminationRequest`, `Incident`, `Announcement`, `WeeklyReport` | 사업/과금/세션/리포트 | |

### 운영 콘솔

- `/platform/*` — 운영자 전용
  - `accounts, platform_staff, inquiries, feature_flags, audit_events, safety_logs, runtime_configs, incidents, model_catalog_entries, plans, industries, prompt_templates`
  - `hermes#index/test/executions/audit` — Hermes 상태 대시보드

## 3. Runtime Config Bundle 구조 (v1)

스키마: `sohee.runtime/v1`

`snapshot_for(account)` 메서드로 DB 상태에서 직렬화:

```ruby
{
  schema_version: "sohee.runtime/v1",
  generated_at: Time.current.iso8601,
  business: { trade_name, legal_name, owner_name, industry_code, region_label, brand_intro, ... },
  persona: { key, ... },
  ...
}
```

> ⚠️ 사용자가 제시한 **v2 스키마**는 미존재. v2 추가 시 `schema_version: "2.0"` 형식으로 기존 v1과 공존.

## 4. Hermes 연동 (현재)

### HTTP 호출만 존재 (MCP 부재)

`Platform::HermesController` (`app/controllers/platform/hermes_controller.rb`):

| 메서드 | 라우트 | 역할 |
|---|---|---|
| `index` | `GET /platform/hermes` | 상태 대시보드 |
| `test` | `POST /platform/hermes/test` | 스모크 테스트 (`Net::HTTP::Post` Bearer) |
| `executions` | `GET /platform/hermes/executions` | 최근 실행 100건 |
| `audit` | `GET /platform/hermes/audit` | automation.hermes.* AuditEvent 200건 |

ENV:
- `HERMES_AGENT_URL` (필수)
- `HERMES_AGENT_TOKEN` (필수)
- `HERMES_AGENT_TIMEOUT` (기본 25초)

> ⚠️ **Hermes Agent → Rails 외부 API 없음** (`api/v1` 컨트롤러 부재). 작업 큐 동기화/ACK/Health Check API 신규 필요.

### Hermes Adapter

`app/services/automation/`:
- `provider.rb` — Provider 인터페이스 + active lookup
- `real_hermes_adapter.rb` — 실제 HTTP 호출
- `fake_hermes_adapter.rb` — 개발용 stub

## 5. 채널 어댑터 (현재)

`app/services/channels/`:
- `adapter.rb` (인터페이스)
- `generic_adapter.rb`
- `instagram_adapter.rb`
- `threads_adapter.rb`
- `naver_adapter.rb` (블로그/플레이스/통합)
- `kakao_adapter.rb`
- `mastodon_adapter.rb`
- `publisher.rb` — 발행 오케스트레이션

> ⚠️ **Discord 어댑터 부재**. ChannelConnection에 `discord` kind는 enum으로 있지만 발행 어댑터 없음.

## 6. AI 호출 (현재)

- `app/services/response_composer.rb` — 응답 합성 (실제 Gemini 호출 **없음**, stub placeholder 텍스트)
- `app/services/safety/policy.rb` — 안전 정책 검사
- `app/services/rag/search.rb` — RAG 검색 (Embedding → DocumentChunk)
- `app/services/notification_broadcaster.rb` — 알림

> ⚠️ **Gemini/OpenAI/GenAI SDK 어디에도 호출 없음**. `.env.example`에 `OPENAI_API_KEY=` (빈 값)만 정의. 실제 AI 호출은 Hermes Agent 측에 위임하는 구조로 추정.

## 7. Discord / Gemini 코드 (현재)

- Discord 관련: `app/models/channel_connection.rb`에 enum `discord` 1줄 외 **없음**
- Discord Bot, Gateway, Event Handler, Slash Command 코드 **부재**
- Gemini 관련: **부재** (gem은 없음, 코드도 없음)
- `workers/` 디렉터리 **부재**
- `app/jobs/` — `application_job.rb`, `automation_tick_job.rb`, `content/publisher_job.rb`, `engagement_tick_job.rb`, `daily_report_job.rb`, `data_export_job.rb`, `knowledge_ingest_job.rb`, `inquiries/...`, `automation/{run_job,tick_job}.rb`

## 8. Solid Queue / 백그라운드 작업

- `config/queue.yml` — `dispatchers: polling_interval: 1, batch_size: 500`, workers: `threads: 3, processes: 1`, polling_interval: 0.1
- **개발자 환경**: 단일 `bin/jobs` 프로세스로 실행
- **프로덕션**: 단일 `bin/jobs-up` 스크립트 추정 (Docker/launchd 부재)

## 9. 안전 / 격리 / 정책

- `GuardrailPolicy`, `EscalationRule`, `SafetyLog`, `PromptTemplate`, `ModelPolicy`, `BrandConfig` — DB 레벨 정책 표현
- `forbidden_phrases_json`, `forbidden_topics_json`, `must_handoff_topics_json` — 다중 모델에 분산 저장
- `AiEmployee.memory_json` — 에이전트 단기 메모리
- `operator_managed` (BusinessProfile) — 운영팀이 직접 관리 플래그

## 10. P0/P1 작업 이력 (참고)

| 커밋 | 내용 |
|---|---|
| `de9a3ee` | audit 5개 문서 main 머지 |
| `53a1963` | P0-2 사이드바 22→7 IA + 셋업 준비도 라벨 변환 |
| `1311c2a` | P0-3 사업자 화면 placeholder 라우트 차단 |
| `8b05dae` | P0-4 Runtime/Audit/Safety 메뉴를 운영자 콘솔로 이동 |
| `6f3720a` | P0-5 대시보드 재구성 |
| `65fef9e` | P0-6 확인할 일 통합 + RAG 잔존 정리 |

## 11. 미커밋 변경 (현재 작업 디렉토리)

P1 5개 작업(자동화 라우트 500 수정, 콘텐츠 라벨, 사업자 영역 잔존 정리, 사업장 편집 폼, 셋업 마법사) 코드 변경됨, 커밋·머지 **미완**.

## 12. 신규 확장 시 영향받는 영역

| 영역 | 작업 |
|---|---|
| 모델 | 7개 신규 모델 + 1개 마이그레이션 |
| 컨트롤러 | `/api/v1/*` 신규 (Hermes MCP용 외부 API) |
| 라우트 | `discord/*`, `api/v1/*` namespace 추가 |
| Workers | `workers/discord-gateway/`, `workers/gemini-conversation/`, `workers/sohee-control-mcp/` (신규, TypeScript/Ruby/Node) |
| Jobs | `process_discord_event_job`, `generate_discord_reply_job`, `extract_change_proposal_job`, `compile_runtime_config_job`, `dispatch_hermes_job`, `discord_outbound_job`, `reconcile_discord_messages_job` |
| Providers | `GeminiProvider` 인터페이스 + 3개 구현체 |
| ENV | `SOHEE_GEMINI_*`, `DISCORD_*`, `HERMES_MCP_*` 추가 |
| 운영 | launchd / Docker Compose 매니페스트 |
| 테스트 | `test/` 디렉터리 신규 구축 (현재 없음) |

## 13. 사람이 직접 해야 하는 단계 (다음)

1. Discord Application 생성 (https://discord.com/developers/applications)
2. Bot Token 발급
3. Privileged Intent 활성화 (Message Content Intent 등)
4. 테스트 서버에 Bot 초대
5. Gemini Google Cloud Project 선택
6. Auth Key 또는 Service Account 생성
7. Secret을 macOS Keychain 또는 환경변수에 등록
8. 운영 매니페스트 작성 (launchd 또는 Docker Compose)

**가짜 값은 만들지 않음**. `.env.example`에 placeholder만 추가하고 사람 입력 대기.

---

문서 종료. 다음 단계(아키텍처/데이터플로우/보안/서버 템플릿/Gemini 전략/Hermes 통합/구현 계획)는 본 감사 결과를 기반으로 별도 작성.