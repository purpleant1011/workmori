# ERD (Entity Relationship Diagram)

본 문서는 본 제품의 핵심 테이블 관계를 다이어그램으로 정리한다.
실제 구현은 `db/schema.rb` 가 단일 진실 공급원이며, 본 문서는 그 설계 의도를 보존한다.

## A. 핵심 관계 (요약)

```
accounts 1─* users (through memberships)
accounts 1─* business_profiles 1─* ai_employees 1─* ai_employee_versions
                                                │
ai_employees 1─* guardrail_policies / escalation_rules
ai_employees 1─* automation_rules 1─* automation_schedules
                                       └─* automation_executions 1─* execution_events
                                                                 └─* approval_requests

knowledge_documents 1─* document_versions 1─* document_chunks 1─1 embeddings
faqs / products / services ─ (account 스코프)
conversations 1─* messages 1─* handoffs
channel_connections 1─* channel_scopes
content_items 1─* content_versions / media_assets / publication_attempts

service_accounts 1─* api_tokens / webhook_endpoints
feature_flags (account_id nullable — 전역/계정/직원)
audit_events (account_id nullable, 글로벌 가능)
```

## B. Tenancy 규칙

- 모든 다중 고객 테이블: `account_id NOT NULL` + `index [account_id, ...]`
- 전역 테이블: `accounts`, `plans`, `feature_flags`(글로벌), `model_catalog_entries`, `prompt_templates`, `audit_events`
- 결제/환불/계약의 일부 메타는 `account_id` nullable

## C. Money / Time 규약

- 금액 컬럼: `*_amount_krw` (정수, KRW 단위, VAT 별도)
- 세금: `*_vat_krw` (정수)
- 시간: `*_at` 컬럼은 모두 UTC
- 표시 변환은 뷰/헬퍼에서 `account.timezone` 사용

## D. Idempotency 규약

- 자동화 실행: `automation_executions.idempotency_key` UNIQUE
- 게시 시도: `publication_attempts.idempotency_key` UNIQUE
- 외부 식별자: `(provider, external_id)` UNIQUE

## E. 인덱스 가이드

- 검색: `tsvector` 컬럼 + GIN 인덱스
- 임베딩: pgvector `ivfflat` 또는 `hnsw` (차후)
- 자주 필터: `(account_id, status, created_at)`, `(account_id, scheduled_at)`

## F. 보존 정책 (요약)

- 메시지 원문 180일 → 익명화 통계만 보존
- 자료 원본은 사용자 명시 시 영구 삭제 (연쇄 삭제)
- 결제/세금 5년 (가정)
- audit_events 변조 방지 (append-only)