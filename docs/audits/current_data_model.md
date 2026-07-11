# 현재 데이터 모델 감사 (Current Data Model Audit)

**조사 일자**: 2026-07-11  
**조사 범위**: `db/schema.rb` (34 마이그레이션), `app/models/*.rb` (67 모델)  
**조사 기준**: "소희 프로젝트 3차 대대적 리뉴얼 지시서" 8~17장 신규 요구사항

---

## 1. 현황 통계

- **총 모델**: 67개
- **총 마이그레이션**: 34개 (latest: `2026_07_11_055802`)
- **총 컨트롤러**: 63개
- **총 뷰**: 146개 (.erb)

---

## 2. 모델 카테고리 분류

### 2.1 핵심 도메인 (Account/User/Membership)

| 모델 | 컬럼 (대표) | 상태 |
|------|------------|------|
| `Account` | name, slug, status, timezone, country, operator_managed, settings_json | ✅ |
| `User` | email_address, password_digest, name, role (owner/operator/reviewer) | ✅ |
| `Membership` | account_id, user_id, role (owner/admin/reviewer) | ✅ |

### 2.2 페르소나 / RAG

| 모델 | 컬럼 | 충족도 | 신규 필요 |
|------|------|--------|---------|
| `AiEmployee` | name, role_label, tone, friendliness, expertise_level, honorific, sentence_length, vocabulary_phrases_json, forbidden_phrases_json, channel_behaviors_json, work_days/hours, daily/weekly_post_quota, approval_mode, monthly_token_budget | △ | 채널별 페르소나, 버전 상태(draft/review/active/archived), 변경 이력 강화 |
| `AiEmployeeVersion` | account_id, ai_employee_id, version_number, snapshot_json, change_summary, changed_by_user_id, restored_from_previous, activated_at | ✅ (UI 약함) | - |
| `KnowledgeSource` | account_id, ai_employee_id, kind, title, url, tags_json, status, valid_from/until | △ | source_type, original_file, business_id, category, applicable_channels, last_verified_at, verified_by, confidence_level, retrieval_priority, contains_personal_data, contains_sensitive_data, ai_use_allowed, public_content_use_allowed, version, checksum (12장 신규 메타) |
| `KnowledgeDocument` | account_id, knowledge_source_id, version, raw_text, normalized_text, mime_type, byte_size, checksum_sha256, pii_warnings_count, status, indexed_at | ✅ | - |

### 2.3 자동화

| 모델 | 컬럼 | 충족도 | 신규 필요 |
|------|------|--------|---------|
| `AutomationRule` | (확인 필요) | △ | skill_id, cron_expression, timezone, days_of_week, local_time, approval_mode (test_only/always_review/review_if_low_confidence/auto_execute/disabled), failure_action (retry/create_alert/pause_channel/request_human/skip_and_report), idempotency_key, blackout_dates, rate_limit, max_retries, retry_interval, human_review_condition, next_run_at, last_run_at, last_result |
| `AutomationSchedule` | (확인 필요) | △ | - |
| `AutomationExecution` | (확인 필요) | △ | - |

### 2.4 채널

| 모델 | 컬럼 | 충족도 | 신규 필요 |
|------|------|--------|---------|
| `ChannelConnection` | (확인 필요) | △ | environment (test/official), posting_mode (draft_only/scheduled/auto_publish/paused), secret_reference, allowed_actions, content_formats, last_success_at, last_failure_at, token_expires_at, rate_limit_status, health_status |
| `ChannelScope` | (확인 필요) | △ | - |

### 2.5 콘텐츠 / 문의 / 인계

| 모델 | 컬럼 | 충족도 |
|------|------|--------|
| `ContentItem` | (확인 필요) | △ |
| `ContentVersion` | (확인 필요) | △ |
| `Conversation` / `Message` / `ConversationParticipant` | ✅ | - |
| `Handoff` / `Inquiry` | ✅ | - |
| `Engagement` | ✅ | - |
| `CsatResponse` | ✅ | - |
| `ApprovalRequest` | ✅ | - |

### 2.6 결제 / 계약 / 보증금

| 모델 | 컬럼 | 처리 |
|------|------|------|
| `Plan` | code, name, monthly_price_krw, monthly_price_vat_krw, features, description | **공개 화면에서 가격 노출 차단** |
| `Billing` / `Invoice` / `Payment` / `Subscription` | ✅ | - |
| `ContractTerm` | ✅ | - |
| `Deposit` | ✅ | - |

### 2.7 인증 / 보안

| 모델 | 컬럼 | 충족도 |
|------|------|--------|
| `Session` | token_hash, account_id, user_id | ✅ |
| `PlatformSession` | token_hash, platform_staff_id | ✅ |
| `MagicLink` | token, expires_at | ✅ |
| `ApiToken` | (확인 필요) | △ - 신규 Hermes API에서 agent-specific token 발급 필요 |
| `AuditEvent` | actor_kind (user/anon/automation/system/operator), actor_id, account_id, kind, payload | ✅ |
| `DataExportRequest` / `DeletionRequest` | ✅ | - |

### 2.8 안전 / 가드레일

| 모델 | 컬럼 | 충족도 |
|------|------|--------|
| `GuardrailPolicy` | (확인 필요) | △ |
| `EscalationRule` | (확인 필요) | △ |
| `FeatureFlag` | ✅ | - |
| `Incident` | ✅ | - |

### 2.9 카탈로그

| 모델 | 컬럼 | 충족도 |
|------|------|--------|
| `IndustryTemplate` | (확인 필요) | △ |
| `ModelCatalogEntry` | (확인 필요) | △ |
| `PromptTemplate` | (확인 필요) | △ |

### 2.10 보고 / 분석

| 모델 | 컬럼 | 충족도 |
|------|------|--------|
| `Report` / `WeeklyReport` | ✅ | - |
| `Analytics` / `UsageMetric` | ✅ | - |
| `DeliveryLog` | ✅ | - |
| `Budget` | ✅ | - |

---

## 3. 신규 필요한 모델 (P2/P3)

| 신규 모델 | 용도 (지시서) | 우선순위 |
|----------|-------------|---------|
| `SetupReadinessScore` | 사업장별 준비도 점수 (12영역, 0~100%) | P2 |
| `SetupReadinessItem` | 12개 영역별 항목 (작성 중/검수 필요/완료/차단됨) | P2 |
| `Skill` | 스킬 레지스트리 (12개 기본) - 19필드 | P2 |
| `TestLabScenario` / `TestLabRun` | 테스트 랩 시나리오 + 실행 결과 (14종) | P2 |
| `TestLabPassCriterion` | 공식 전환 합격 기준 | P2 |
| `OwnerFeedback` / `Feedback` | 사업자 피드백 큐 | P2 |
| `KnowledgeGap` | 지식 공백 (답변 못 한 질문) | P2 |
| `RuntimeConfigBundle` | Runtime Configuration Bundle (사업장별) | P3 |
| `RuntimeConfigVersion` | draft / active 분리 + version + checksum | P3 |
| `HermesJob` / `HermesHeartbeat` / `HermesExecution` | Hermes 작업 큐 / heartbeat | P3 |
| `RuntimeConfigAuditLog` | 버전 변경 / 배포 / rollback 감사 | P3 |
| `ChannelSecret` (선택) | secret_reference (평문 저장 금지, KMS/referenced) | P3 |

---

## 4. 신규 필요한 컬럼 (기존 모델 강화)

### 4.1 `BusinessProfile` (9장 강화)

| 신규 컬럼 | 설명 |
|----------|------|
| `parking_info` | 주차 |
| `directions` | 찾아오는 길 |
| `reservation_method` | 예약 방식 |
| `consult_channel` | 상담 채널 |
| `core_keywords` | 대표 키워드 |
| `region_keywords` | 지역 키워드 |
| `customer_anxieties_json` | 고객 주요 불안 |
| `purchase_obstacles_json` | 구매 전 장애물 |
| `avoid_imagery` | 피하고 싶은 이미지 |
| `reference_channels` | 닮고 싶은/싫은 채널 |
| `last_verified_at` | 마지막 검수일 |

### 4.2 `AiEmployee` (10장 강화)

| 신규 컬럼 | 설명 |
|----------|------|
| `version_status` | draft/review/active/archived |
| `channel_personas_json` | 채널별 페르소나 (Instagram, Threads, Blog, Naver Place, Daangn, Inquiry reply, Daily report) |
| `change_log_json` | 변경 이력 |
| `effective_at` | 적용일 |

### 4.3 `KnowledgeSource` (11장 강화)

| 신규 컬럼 | 설명 |
|----------|------|
| `source_type` | service_info/pricelist/faq/policy/pre_post/cancel/review/reference/blog_ref/sns_ref/place/daangn/script/forbidden/legal/philosophy/brand_story |
| `original_file` | 원본 파일 경로 |
| `business_id` | 사업장 식별자 (내부 ID, 외부 노출 X) |
| `category` | 카테고리 |
| `applicable_channels_json` | 사용 가능 채널 |
| `last_verified_at` | 마지막 검증일 |
| `verified_by_user_id` | 검증자 |
| `confidence_level` | 신뢰도 |
| `retrieval_priority` | 검색 우선순위 |
| `contains_personal_data` | 개인정보 포함 여부 |
| `contains_sensitive_data` | 민감정보 포함 여부 |
| `ai_use_allowed` | AI 사용 허용 |
| `public_content_use_allowed` | 공개 콘텐츠 사용 허용 |
| `checksum_sha256` | 무결성 |

### 4.4 `AutomationRule` (13장 강화)

| 신규 컬럼 | 설명 |
|----------|------|
| `skill_id` | 스킬 FK |
| `cron_expression` | cron 표현식 |
| `timezone` | 타임존 |
| `days_of_week_json` | 요일 |
| `local_time` | 시간 |
| `approval_mode` | test_only/always_review/review_if_low_confidence/auto_execute/disabled |
| `failure_action` | retry/create_alert/pause_channel/request_human/skip_and_report |
| `idempotency_key` | 중복 실행 방지 |
| `blackout_dates_json` | 정지일 |
| `rate_limit` | 분당 제한 |
| `max_retries` | 최대 재시도 |
| `retry_interval_seconds` | 재시도 간격 |
| `human_review_condition` | 사람 검토 조건 |
| `next_run_at` | 다음 실행 |
| `last_run_at` | 마지막 실행 |
| `last_result` | 마지막 결과 |

### 4.5 `ChannelConnection` (14장 강화)

| 신규 컬럼 | 설명 |
|----------|------|
| `environment` | test/official |
| `posting_mode` | draft_only/scheduled/auto_publish/paused |
| `secret_reference` | 시크릿 참조 (평문 X) |
| `allowed_actions_json` | 허용 액션 |
| `content_formats_json` | 콘텐츠 포맷 |
| `last_success_at` | 마지막 성공 |
| `last_failure_at` | 마지막 실패 |
| `token_expires_at` | 토큰 만료 |
| `rate_limit_status` | 분당 제한 상태 |
| `health_status` | 정상/저하/만료/중지 |

---

## 5. 데이터 격리 / 멀티테넌시

### 5.1 현재 (충족)

- 모든 업무 데이터 모델이 `account_id` FK 보유
- `BaseController#current_account` 헬퍼로 자동 스코프
- `Pundit` 미사용 (지시서 유지)

### 5.2 신규 요구 (19장)

- ✅ 고객사 간 데이터 완전 분리 (이미 충족)
- ⚠️ 테스트와 공식 환경 분리 (`ChannelConnection.environment` 강화 필요)
- ⚠️ 고객 사진 학습 기본값 `false` (`AiEmployee` 또는 `BusinessProfile.photo_learning_allowed` 신규)

---

## 6. 시드 데이터 현황

### 6.1 핵심 시드 파일

| 파일 | 라인 수 | 내용 | 위험 |
|------|--------|------|------|
| `db/seeds.rb` | ~300 | 데모 계정 + 바이름 시드 트리거 | 데모 계정 노출 (운영 콘솔/문서용, 공개 X) |
| `script/seed_byreum.rb` | ~150 | 바이름 계정/페르소나/콘텐츠/문의 | 실명 슬러그 - P2 익명화 |
| `script/seed_byreum_content.rb` | ~100 | 바이름 콘텐츠/문의 상세 | 실명 - P2 익명화 |
| `script/seed_billing.rb` | ~80 | 결제 시드 | (확인 필요) |
| `bin/seed_full.rb` | (확인 필요) | 전체 시드 | 데모 계정 출력 |

### 6.2 신규 시드 필요 (P2/P3)

- `db/seeds/anonymous_fixtures.rb` - 익명화된 기본 데이터 (1인 뷰티샵 A)
- 공개 데모용 사업장 1건 (`pilot-beauty-studio-01` slug) — 익명화, 가격/계약 없음
- 신규 모델 (SetupReadinessScore, Skill, TestLabScenario 등) 시드

---

## 7. DB 마이그레이션 전략 (지시서 24장 - 작은 단위)

### 7.1 P0 (이번 작업)

- 별도 마이그레이션 없음 (P0는 화면/문구 정리 위주)

### 7.2 P2 (관리자 IA 개편)

순서대로 작은 마이그레이션 분리:

1. `AddSetupReadinessFieldsToAccounts` - 12개 영역 JSON
2. `CreateSkills` - 스킬 레지스트리
3. `CreateTestLabScenariosAndRuns` - 테스트 랩
4. `CreateRuntimeConfigBundlesAndVersions` - Runtime Bundle
5. `CreateHermesJobsAndHeartbeats` - Hermes 연동
6. `CreateFeedbacksAndKnowledgeGaps` - 피드백/지식공백
7. `AddChannelEnvironmentToChannelConnections` - env 분리
8. `EnhanceKnowledgeSources` - 12개 신규 메타 필드
9. `EnhanceAutomationRules` - 13개 신규 필드
10. `EnhanceAiEmployees` - 채널별 페르소나/버전 상태
11. `EnhanceBusinessProfiles` - 신규 필드

### 7.3 P3 (Hermes 연동)

- 별도 Hermes 전용 마이그레이션

---

## 8. 호환성 / 성능 고려

### 8.1 JSON 컬럼

- 기존 모델 다수에 `*_json` 컬럼 사용 (`settings_json`, `tags_json` 등) — Postgres 16 `jsonb` 사용 권장
- 신규 필드도 JSON 컬럼으로 추가 (유연성)

### 8.2 인덱스

- `account_id` + `status` + `created_at` 복합 인덱스 추가 검토
- Runtime Bundle 조회 빈도 높음 → `(account_id, status, effective_at DESC)` 인덱스

### 8.3 트랜잭션

- Runtime Bundle 생성/활성화는 단일 트랜잭션 + 체크섬 + audit log
- 버전 충돌 방지: optimistic locking (`lock_version`)

---

## 9. 다음 액션

1. **P0**: 화면/문구 정리 (DB 변경 없음)
2. **P2**: 위 4장의 신규 컬럼 + 신규 모델 마이그레이션 (작은 단위 분리)
3. **P3**: Runtime Bundle + Hermes API 마이그레이션
4. **P4**: PII 자동 감지 룰, 비밀 KMS reference 등 보안 강화