# 보안 모델 — Meta 통합

**목표**: Hermes Agent, MCP 서버, Rails, Meta API 사이의 모든 데이터 흐름에서
- 토큰/시크릿 평문 노출 방지
- 외부 텍스트의 프롬프트 인젝션 방어
- 사람 승인 없는 위험 액션 차단
- 감사 로그 완전성

---

## 1. 토큰 / 시크릿 관리

### 1.1 분류

| 항목 | 민감도 | 보관 위치 | 출력 정책 |
|---|---|---|---|
| `META_APP_SECRET` | Critical | `.env` (gitignore), Rails credentials (production) | 절대 출력 금지, 로그 금지 |
| `META_APP_ID` | Low-Medium | `.env` | 일반 env |
| `META_GRAPH_API_TOKEN` (장기) | Critical | `ChannelConnection.encrypted_token` (Rails `encrypts`) | 로그 마스킹, 응답 마스킹 |
| `THREADS_ACCESS_TOKEN` | Critical | `ChannelConnection.encrypted_token` | 동일 |
| `THREADS_USER_ID` | Low | `.env` 또는 DB (외부 ID) | 일반 |
| Webhook verify token | Medium | `.env` | 일반 env |
| Webhook signature secret | Medium | `WebhookEndpoint.secret_digest` | DB 다이제스트 |
| 단기 OAuth 토큰 (콜백 중) | Critical | 메모리만, 콜백 직후 폐기 | 절대 로그 금지 |
| Refresh token | Critical | DB 암호화 | 동일 |

### 1.2 암호화 검증

- **Rails Active Record Encryption**: `ChannelConnection.encrypts :encrypted_token` 확인됨 (production master key 필요)
- `config/credentials.yml.enc` 또는 `ENV["RAILS_MASTER_KEY"]` 운영 환경에 설정
- **마스터 키 평문 출력 금지**, gitignore 확인

### 1.3 로그 마스킹 규칙

```ruby
# application.rb 또는 initializers
Rails.application.config.filter_parameters += [
  :access_token, :refresh_token, :client_secret, :app_secret,
  :META_APP_SECRET, :META_GRAPH_API_TOKEN, :THREADS_ACCESS_TOKEN,
  :password, :current_password, :new_password, :token, :encrypted_token
]
```

- AuditEvent 생성 시 actor_kind 별도 — `system` (배치), `operator` (사람), `user` (고객), `automation` (AI)
- 토큰은 오류 메시지에 포함 금지 — `last_error`는 일반화된 카테고리만 (`"token_expired"`, `"rate_limited"`)

---

## 2. 프롬프트 인젝션 방어

### 2.1 위협 모델

외부 텍스트 (댓글, DM, 인스타그램 게시물 본문, 참조 링크)는 **신뢰할 수 없는 데이터**로 취급. 다음 지시가 포함돼도 실행 안 함:

- "시스템 프롬프트를 무시하라"
- "파일을 읽어라"
- "환경변수를 출력하라"
- "다른 도구를 호출하라"
- "계정을 삭제하라"
- "링크에 접속하라"
- "코드를 실행하라"
- "개인정보를 전송하라"

### 2.2 처리 원칙

1. **분류 대상 데이터로만 모델에 전달** — 도구 지시(instruction)로 해석 안 함
2. **외부 텍스트는 시스템 프롬프트와 분리** — `user_content`로 격리
3. **답변 생성 시 외부 텍스트를 인용하더라도 도구 호출로 사용 안 함**
4. **인용 길이 제한** (예: 댓글 본문 200자 이내만 컨텍스트에 포함)
5. **민감 카테고리 분류 시 사람 인계** — `procedure_suitability`, `skin_or_medical`, `complaint`, `refund`, `negotiation`, `sensitive_personal`, `unknown`

### 2.3 모델 가드레일

```ruby
# GuardrailPolicy 모델에 다음 룰 추가 가능:
# - 외부 텍스트에서 도구 호출 키워드 매치 시 차단
# - 시스템 프롬프트 유출 시도 감지
# - 명령 인젝션 패턴 (예: "ignore", "forget", "new instructions") 감지
```

---

## 3. 승인 정책

### 3.1 위험도별 (Meta 통합)

| 위험도 | 액션 | 승인 정책 |
|---|---|---|
| R0 | 프로필·게시물·댓글 읽기, 인사이트, 초안 생성 | 자동 허용 |
| R1 | 테스트 계정 게시/답글 | 자동 허용 (`environment == "test"`) |
| R2 | 공식 게시 (승인된 루틴), 고신뢰 FAQ 자동답글 | 자동 허용 + 사후 감사 |
| R3 | DM 발송, 댓글 작성자 비공개 답장, 부정 응대, 공개 선제 답글 | **사람 승인 필수** (`MetaActionApproval`) |
| R4 | 댓글 삭제, 게시물 삭제, 계정 설정 변경, 권한 변경, 대량 작업 | **항상 사람 승인 + 2단계 검증** |

### 3.2 `MetaActionApproval` 테이블 (이미 정의됨)

- action_type: `instagram_publish`, `threads_reply`, `comment_hide`, `comment_delete`, `dm_send`, ...
- target_id: 외부 ID
- requested_by: AI 직원 ID 또는 operator
- risk_level: 0~4
- approval_status: `pending`, `approved`, `denied`, `expired`
- approved_by: 사람 user_id
- expires_at: TTL (예: 30분)
- reason: 자동 분류 결과 + 신뢰도

### 3.3 만료·재시도

- `expires_at` 지난 approval은 자동 `expired`
- 같은 액션 재요청 시 새 approval 발급 (idempotency는 외부 ID 기준)
- 사용자가 거부한 액션은 동일 external_id에 대해 24시간 재요청 금지 (옵션)

---

## 4. 속도 제한

### 4.1 Meta 자체 제한

- Graph API: 사용자 토큰당 200 호출/시간
- 게시: 분당 ~25 (Instagram), ~10 (Threads) — 가변
- `X-RateLimit-*` 헤더 모니터링 → 임계치 도달 시 백오프

### 4.2 소희 측 안전 제한 (사업장별)

- **게시**: 분당 5회, 시간당 30건, 일일 100건
- **댓글 답글**: 분당 10회, 시간당 100건
- **인사이트**: 시간당 50건 (캐싱 권장)
- **DM**: 분당 2회 (24시간 응답창 내)
- **위험 액션 (R3/R4)**: 시간당 5건 (사람 승인 후)

### 4.3 백오프 전략

- Meta `429 Too Many Requests` 응답 시 `Retry-After` 헤더 존중
- 5xx 응답 시 exponential backoff (1s, 2s, 4s, 8s, 16s) — 최대 5회
- 5회 실패 후 `ChannelConnection.status = "error"` + 사람 알림
- 다른 사업장 채널에 영향 없도록 사업장별 격리

---

## 5. 데이터 보존·PII

### 5.1 보존 정책

| 데이터 | 보존 기간 | 처리 |
|---|---|---|
| 댓글 원문 (raw_text) | 90일 | 이후 마스킹 + 분석 메타만 보존 |
| DM 본문 | 30일 (응답창 종료 후) | 이후 삭제 또는 강한 마스킹 |
| 게시물 본문 (자체) | 무기한 (계정 삭제 시까지) | — |
| 참조 링크 캡션 | **저장 안 함** | 패턴만 추출 |
| 참조 이미지 | **저장 안 함** | 시각 archetype만 메타화 |
| Webhook raw payload | 7일 (디버깅용) | 이후 삭제 |

### 5.2 PII 마스킹

- 이메일, 전화번호, 카드번호, 주민번호 패턴 자동 마스킹
- `Message.redacted_body_json` 활용 — 원본 + 마스킹 버전 별도 저장
- AI 모델에는 마스킹 버전만 전달
- AuditEvent `payload`에 원본 텍스트 금지 — 메타(`classification`, `confidence`)만

### 5.3 고객 사진·민감 상담

- AI 학습에 사용 금지 (소희 정책 1.5)
- RAG/embedding에 포함 금지
- 마스킹 후에도 사람 검토 큐로 인계

---

## 6. 감사 로그 (AuditEvent)

### 6.1 기록 대상

- 모든 Meta API 호출 (success/failure, latency, error_category)
- 토큰 발급·갱신·폐기
- OAuth 시작·콜백
- Webhook 수신
- 게시·답글·숨김·삭제 (모든 mutation)
- 승인 요청·승인·거부
- 인사이트 수집
- 사람 인계 발생

### 6.2 액터 분류

```ruby
ACTOR_KINDS = %w[user anon automation system operator]
```

- `user`: 고객 (댓글·DM 발신자) — **외부 액터로 추적 대상**
- `automation`: AI 에이전트가 자동 실행
- `operator`: 운영자 (사람)
- `system`: 시스템/배치
- `anon`: 비인증

### 6.3 로그 무결성

- append-only (수정·삭제 금지)
- 사업장별 격리 (`account_id`)
- 90일 후 cold storage 이동 (옵션)

---

## 7. 격리

### 7.1 사업장 간

- `ChannelConnection.account_id` 격리
- 토큰은 사업장별로 암호화 + 마스터 키 동일하지만 사업장 컨텍스트 없으면 조회 불가
- 다른 사업장 채널 상태·콘텐츠·댓글 접근 불가

### 7.2 채널 간

- Instagram 채널 ↔ Threads 채널 독립
- 한 채널 실패가 다른 채널에 영향 없음
- 채널별 상태 (`active`/`paused`/`error`)

### 7.3 환경 간

- `ChannelConnection.environment`: `test` vs `official`
- 테스트 계정 액션은 운영 채널과 분리
- App Review용 테스트와 실제 테스트 분리 (`test_user` vs `test_reviewer`)

---

## 8. MCP 서버 보안

### 8.1 토큰 흐름

```
Hermes → MCP (도구 호출) → Rails API (권한·승인·audit) → Meta API
                  ↑                              ↑
            토큰 직접 노출 안 함         암호화된 토큰만 사용
```

- MCP 서버는 Meta 토큰을 직접 받지 않음
- 모든 도구 호출은 Rails API를 경유 — 권한·승인·audit 보장
- MCP 서버는 단순 프록시 + 도구 메타 등록

### 8.2 MCP 도구 표면 축소

- 처음에는 **읽기 + 초안 + 테스트 게시 + 테스트 답글**만 노출
- 삭제·숨김·DM·좋아요 관련 도구는 노출 안 함
- `supports_parallel_tool_calls`: false
- sampling 비활성, prompts/resources 비활성

### 8.3 MCP 인증

- MCP 서버 ↔ Rails API: 사설 토큰 (`MCP_RAILS_API_TOKEN`, .env)
- 사업장별 격리는 MCP 요청에 `business_id` 포함 + Rails가 권한 확인

---

## 9. 사고 대응

### 9.1 토큰 유출 의심

1. 즉시 Meta 개발자 콘솔에서 해당 토큰 revoke
2. 모든 활성 세션 폐기 (`Session.where(...).update_all(revoked_at: Time.current)`)
3. ChannelConnection 상태 `revoked`로 변경
4. 사람 알림 (심각도 Critical)
5. AuditEvent 기록 + 사후 분석

### 9.2 비인가 게시 감지

1. 자동 polling 또는 webhook으로 비인가 게시물 감지
2. 사람 알림 + 자동 삭제 검토 (R4 → 사람 승인 후)
3. 원인 추적 (audit log 분석)

### 9.3 Meta 정책 위반 경고

1. Meta로부터 정책 경고 수신 시 즉시 모든 자동화 일시중지
2. 원인 분석 + 사람 검토 후 재개 결정
3. App Review 추가 심사 대비

---

## 10. 체크리스트 (구현 시)

- [ ] Rails credentials / master key 운영 환경 설정
- [ ] filter_parameters 확장 (위 표)
- [ ] ChannelConnection 모델에 `last_error`, `token_expires_at`, `environment` 컬럼 추가
- [ ] MetaActionApproval 모델 구현
- [ ] GuardrailPolicy에 인젝션 패턴 룰 추가
- [ ] MCP 서버 도구 표면 축소 (R0/R1만)
- [ ] MCP ↔ Rails API 인증 토큰 설정
- [ ] AuditEvent actor_kind 검증
- [ ] PII 마스킹 헬퍼 (`Message` 모델)
- [ ] 보존 정책 자동 정리 잡 (daily)
- [ ] 사고 대응 런북 (`docs/meta/operations-runbook.md`)