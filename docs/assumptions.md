# 가정 (Assumptions)

본 문서는 구현 과정에서 외부 정보를 확정할 수 없거나 환경을 확인하기 어려운 부분에 대해,
되돌릴 수 있는 가정을 세운 기록이다. 출시 전 반드시 재검토한다.

## A. 런타임 환경

| 항목 | 가정 | 근거 | 재검토 시점 |
|---|---|---|---|
| Ruby | 3.4.10 (mise) | 로컬 검증됨 | mise `ruby-3.4.10` |
| Rails | 8.0.5 | 로컬 검증됨. 스캐폴드는 8.1.3 가정이라 다운그레이드 | 다음 Gemfile.lock 갱신 시 |
| PostgreSQL | 16.14, 5433 포트 | 로컬 환경, trust auth, `hochari` 사용자 | 운영 DB 이전 시 |
| Node.js | 22.22.3 | 로컬 검증됨 | 그대로 |
| pgvector | 로컬 PG에 설치 시도, 미설치 시 JSON 캐시로 폴백 | 5433 PG에 권한 없는 경우 | dev 환경 셋업 시 |

## B. 도메인 가정

- **고객 다중화**: 단일 Rails 앱에 다중 `account`. 고객별 별도 DB/별도 Rails 프로세스 안 만듦. (금지사항)
- **테넌트 키**: 모든 업무 데이터는 `account_id` 필수. 일부 감사/결제 메타는 `account_id` nullable.
- **바이름 첫 고객**:
  - 계약 코드: `B-2026-01`
  - 운영 모드: `operator_managed` (운영자가 대신 사업자 프로필/AI 직원 설정)
  - 월 300,000원 (공급가액), 부가세 별도, 보증금 500,000원 → `ClientContract.price_overrides` JSON에 저장
  - 다른 일반 가입자에게 이 가격을 절대 노출하지 않음
- **공식 채널 게시**: 바이름 공식 인스타/블로그/플레이스/당근에는 `approved` 상태인 `content_item` 만 게시. 자동 게시는 `official=true`이고 사람이 명시적으로 활성화한 경우만.
- **해지 시 채널 회수**: `TerminationRequest.status = completed` 이면 해당 `ChannelConnection.access_status = revoked` 가 되도록 자동화.

## C. AI 모델

- `MiniMax M3` 가 텍스트 기본 후보 — 모델 카탈로그의 `kind: text, provider: minimax, code: m3`. 키 없으면 자리표시자.
- 이미지 기본 = `openai/gpt-image-1` (실 구현 시점에 OpenAI의 고품질 이미지 모델 확인). 사용자 문서에 적힌 "GPT 이미지 2"는 검증되지 않은 이름이므로 카탈로그에 적지 않음.
- 모델명은 도메인 로직에 직접 박지 않고 `ModelCatalogEntry.code` 만 사용.
- 고객 자료는 `provider.training_opt_out: true` 와 `AiGateway` 의 마스킹을 통과한 뒤에만 외부로 송신.
- `GPT-5.6`은 OpenAI 공식 카탈로그에 없음 → 개발 시 가용 최상위 모델로 폴백. 차이는 ADR에 기록.

## D. Hermes

- 로컬 환경의 Hermes(`/Users/hochari/.hermes`)는 호출 가능한 외부 서비스가 아니라 다른 시스템.
- 본 제품은 `AutomationProvider` 인터페이스 뒤에 두고, 로컬 검증은 `FakeHermesAdapter` (in-process) 로 한다.
- 진짜 Hermes를 붙일 때 `RealHermesAdapter` 가 인터페이스를 구현.
- 자세한 기능 매트릭스: `docs/hermes-capability-matrix.md`

## E. Discord

- 봇 토큰은 `Active Record Encryption` 으로 암호화 저장.
- 첫 실제 연동은 Discord. 다른 채널(`instagram` / `threads` / `blog` / `naver_place` / `daangn`)은 UI에서 `planned` 또는 `manual_export` 로만 표시, 지원되는 것처럼 가장하지 않음.

## F. 결제

- 실제 결제사(PG) 연동은 MVP에서 강제하지 않음.
- `Billing::Provider` 인터페이스 + `ManualBillingProvider`(수동 기록) + 자리표시자 `StripeBillingProvider` 제공.
- 바이름 보증금 500,000원, 월 300,000원(공급가액) 은 `ClientContract` 의 정수 원 단위로 저장.

## G. 보안

- RLS(PostgreSQL 행 수준 보안) 는 MVP 이후 도입. MVP는 애플리케이션 계층 `current_account` 스코프로 차단.
- 다중 인증(MFA) 은 인터페이스만 준비, 실제 적용은 출시 전.
- 비밀키는 Rails credentials, Active Record Encryption, OS keychain 중 하나로 보관. 평문 금지.
- 로그는 `PIIRedactor` 를 통과. 전화/이메일/계좌번호 정규식 마스킹.

## H. 데이터 보존

- 문의 원문 180일 후 자동 삭제. 익명화 통계는 별도.
- 자료 업로드 원본은 사용자가 명시적으로 비활성화 시 `deletion_request.status = completed` 시 영구 삭제.
- 환불/계약의 경우 5년 보관 (한국 전자상거래법 가정 — 실제 적용 전 법무 검토).

## I. 용어 / 번역

- 화면 한국어 본문은 `config/locales/ko.yml` 에 집중. 도메인 로직은 i18n key 사용.
- 브랜드명 "워크모리(WorkMori)" 는 i18n key `brand.name` 으로 일괄 교체. 가칭이므로 `(가칭)` 표시 기본 ON.

## J. 성능

- 5,000 사업자 / 50,000 가입자 가정. 단일 Rails 프로세스 + Solid Queue로 시작.
- 5분 polling 작업이 아닌 push 기반 (Solid Queue) 으로 지연 최소화.

## K. 정합성

- 돈은 정수 원 단위 (Float 금지).
- 시간은 UTC 저장, 계정별 `timezone` 으로 표시 변환.
- 모든 자동화 실행과 게시 시도는 `idempotency_key` UNIQUE.
- 외부 시스템 식별자는 `(provider, external_id)` UNIQUE.

## L. 위험 표시

- 출시 전 법무/보안 검토 항목: `docs/legal-review-checklist.md`, `docs/security-threat-model.md`.