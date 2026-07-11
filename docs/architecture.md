# 아키텍처 (Architecture)

## A. 시스템 구성

```
                   ┌──────────────────────────────────┐
                   │  Rails 8 (Web + API + Sidekiq대체)│
                   │  - PostgreSQL 16 (5433)            │
                   │  - Solid Queue / Solid Cable      │
                   │  - Hotwire (Turbo + Stimulus)     │
                   │  - Tailwind CSS                   │
                   │  - Active Storage (S3 호환)        │
                   │  - Active Record Encryption       │
                   │                                    │
                   │  Modules:                          │
                   │    Identity / Tenancy              │
                   │    BusinessProfiles                 │
                   │    AiEmployees / Knowledge         │
                   │    Automations / ContentStudio      │
                   │    Conversations / Channels         │
                   │    AiGateway / Billing              │
                   │    Referrals / Terminations        │
                   │    AdminOps / Audit / Reporting    │
                   └─────┬───────────────────┬──────────┘
                         │                   │
            ┌────────────┴───┐    ┌──────────┴──────────┐
            │ Web (Browser)  │    │ Hermes (실행 주체)  │
            │ 사업자 화면    │    │ - 가짜: in-process  │
            │ 어드민 화면    │    │ - 실제: 향후 어댑터 │
            └────────────────┘    └──────────┬──────────┘
                                              │
                              ┌───────────────┼───────────────┐
                              ▼               ▼               ▼
                          AI 공급자      Discord          채널 (실제 게시)
                          (MiniMax,     (봇, 알림)        Instagram/Blog 등
                           OpenAI)
```

## B. 모듈 경계

| 모듈 | 책임 | 다른 모듈 의존 |
|---|---|---|
| Identity | User, Session, Role, Membership, Authn | Tenancy |
| Tenancy | Account 스코프, current_account, 행 격리 헬퍼 | Identity |
| BusinessProfiles | 사업자 프로필, 업종, 지역, 영업시간, FAQ, 금지어, 사람연결 규칙 | Identity, Tenancy |
| AiEmployees | 직원 정의, 버전, 페르소나, 가드레일, 비용한도 | BusinessProfiles, Tenancy, Knowledge |
| Knowledge | 자료 수집, RAG 처리, 검색, 근거 | BusinessProfiles, AiEmployees |
| Automations | 규칙, 일정, 실행 상태기계, 멱등 | ContentStudio, Channels, Audit |
| ContentStudio | 초안, 버전, 정책검사, 승인 | Knowledge, AiEmployees, Automations |
| Conversations | 메시지, 분류, 사람연결(Handoff) | AiEmployees, Knowledge, Channels |
| Channels | 채널 정의, 어댑터, 실제/가짜 | Automations, ContentStudio |
| AiGateway | 모델 카탈로그, 정책, 요청, 결과, 사용량, 비용 | (외부 AI), Audit, Reporting |
| Billing | 요금제, 계약, 청구, 결제, 보증금, 수동/자동 PG | Identity, Contracts |
| Referrals | 링크, 관계, 보상 | Identity, Billing |
| Terminations | 해지 신청, 회수, 내보내기, 삭제 | Billing, Channels, Knowledge |
| AdminOps | 운영자 화면, 기능플래그, 업종 템플릿, 정책 버전 | 모든 모듈 |
| Audit | AuditEvent 기록, 변조 방지 | 모든 모듈 |
| Reporting | 사용량/성과/비용/개선 | Automations, Conversations, Billing, AiGateway |

## C. 데이터 일관성 규칙

- 모든 업무 모델: `belongs_to :account, required: true`
- 모든 외부 ID: `(provider, external_id)` unique
- 모든 자동화 실행/게시: `idempotency_key` unique
- 돈: 정수 원 단위 (`cents`/`amount_krw`)
- 시간: UTC 저장, 표시 시 `account.timezone`

## D. 인증 / 권한

- 사람: 이메일 + 비밀번호 (has_secure_password)
- 실행 주체(Hermes): `ServiceAccount` + `ApiToken` (해시 저장, 짧은 수명, 회전 가능)
- 권한: `Membership.role` (owner/operator/reviewer) + `PlatformStaff.role` (super_admin/staff)
- 권한 미들웨어: `authorize! :action, resource` 패턴
- 기본 거부: 명시적 허용 없이는 거부

## E. RAG 파이프라인

```
원본 업로드
  → 1) [Virus 검사] clamav 또는 자리표시자
  → 2) [파일 형식] mime/시그니처 재검증
  → 3) [텍스트 추출] PDF/text/html 등
  → 4) [PII 검사] 전화/이메일/주민번호/계좌 마스킹
  → 5) [정규화] 공백/줄바꿈/언어 감지
  → 6) [청크 분할] 토큰 한도 + 오버랩
  → 7) [임베딩] (placeholder: 해시) → pgvector
  → 8) [검색 가능] status=ready
```

검색: `(1) PostgreSQL 전문 검색 (tsvector)` + `(2) 의미 검색 (해시 폴백)` → 가중치 결합

근거: 모든 답변은 `evidence_chunks` 를 저장 → UI에 원문/출처 표시

## F. 자동화 상태기계

```
draft
  └─ ready (사용자가 활성화)
       └─ queued
            └─ claimed (실행 주체가 가져감)
                 └─ running
                      ├─ awaiting_approval (사람 승인 필요)
                      │    └─ approved → publishing → succeeded
                      └─ succeeded (자동 게시 가능한 경우)
```

실패 시:
- `retry_scheduled` (다음 재시도 시각)
- `failed` (max_attempts 초과)
- `cancelled` (사용자)
- `paused` (계정/전체 일시중지)
- `quarantined` (반복 실패 또는 비용 급증)
- `expired` (승인 만료)

## G. 비용 / 한도

- `Budget` 모델: 계정/직원/일일/월간
- 50% / 80% / 100% 경고 + 격리
- `usage_records` 는 모델/실행 단위 누적
- 모델 카탈로그의 `input_price_per_1k` / `output_price_per_1k` (정수 원 단위)

## H. 보안

- `PIIRedactor` 미들웨어: 로그/오류 보고에서 마스킹
- CSRF: Rails 기본
- 보안 헤더: `config/initializers/security_headers.rb`
- 속도 제한: `bin/dev` 환경 + Rack::Attack (기본)
- 비밀: ENV → Rails credentials 또는 Active Record Encryption

## I. 관측

- 구조화 로그(JSON 라인) + `request_id` + `account_id` + `actor_id`
- `/up` 헬스체크 + `/health.json` (DB, 큐, AI 키, Discord, 워커)
- 일일 운영자 요약 (cron)

## J. 결정 기록

- `docs/adr/` 아래 ADR-XXX-title.md 형식
- ADR-001: 다중 고객 단일 Rails + 멀티 어댑터 Hermes
- ADR-002: RAG는 MVP에서 키워드 + 해시 폴백, pgvector는 차기
- ADR-003: 자동화 상태기계는 명시적 enum