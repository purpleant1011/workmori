# P4 운영자 콘솔 audit (2026-07-13)

## 1. 범위
§18 P4 = **운영자 콘솔**. 목표: 운영자가 1개 고객사에 들어가서 페르소나/지식/채널/자동화/Runtime/Audit 을 한 번에 보고 즉시 통제.

## 2. 현재 상태 (현장 조사)

| 항목 | 상태 |
|---|---|
| 컨트롤러 | `app/controllers/platform/` 22개 |
| 라우트 | `/platform/*` 107개 (globals + 인증) |
| 레이아웃 | `app/views/layouts/platform.html.erb` — 상단 nav 11 링크 |
| 대시보드 | `/platform` — 6-카드 카운트 + 최근 문의/가입 |
| **고객사별 콘솔** | ❌ **0개** 라우트 (`/platform/accounts/:id/setup`, `/persona`, `/knowledge`, `/channels`, `/automations`, `/runtime`, `/audit` 등 모두 부재) |
| **사이드바** | ❌ 부재 (8 링크 nav 만) |
| `/platform/accounts/:id` show | placeholder ("이 화면은 준비 중입니다.") |
| **계정 인덱스 정렬/필터** | ❌ 기본 — 상태/업종/생성일 필터 없음 |
| **통계/사고 큐** | ⚠️ 부분 (Inquiry 만, Account별 단위 X) |
| **상시 상태 위젯** | ❌ 부재 (대시보드 카운트만) |

## 3. 갭 분석 vs §20 5초/10초 UX

### 3.1 운영자가 "한 고객사 = 한 콘솔" 의 5개 질문 (자체 정의)
1. 이 고객사는 정상인가? (소희 상태 / 인시던트 / 런타임 설정)
2. 오늘 뭘 했는가? (executions + publication_history)
3. 내가 봐야 할 게 있는가? (변경 제안 / 승인 대기)
4. 페르소나/RAG/채널 상태는?
5. **위급시 정지/격리** 가능? (긴급 일시중지, 계정 suspend, 채널 disconnect)

### 3.2 부족 라우트 (12개 우선순위)
| 우선 | 경로 | 목적 | 의존 모델 |
|:---:|---|---|---|
| 1 | `/platform/accounts/:id/setup` | 셋업 준비도 6-카드 (페르소나/RAG/채널/Runtime/테스트/DISCORD) | Account + joined counts |
| 2 | `/platform/accounts/:id/persona` | AI 직원 목록/preset 편집 진입 | AiEmployee + persona_preset |
| 3 | `/platform/accounts/:id/knowledge` | RAG 문서/FAQ 카운트 + 최근 업로드 | KnowledgeDocument + FaqItem |
| 4 | `/platform/accounts/:id/channels` | 채널 연결/test·공식 분리 | ChannelConnection + ChannelScope |
| 5 | `/platform/accounts/:id/automations` | 자동 게시 규칙 + 실행 상태 | AutomationRule + AutomationExecution |
| 6 | `/platform/accounts/:id/runtime` | Runtime config JSON 미리보기/롤백 | RuntimeConfig |
| 7 | `/platform/accounts/:id/audit` | AuditEvents (최근 50) + 필터 | AuditEvent |
| 8 | `/platform/accounts/:id/content` | 콘텐츠 큐/승인 | ContentItem |
| 9 | `/platform/accounts/:id/inquiries` | 고객 문의 | Inquiry |
| 10 | `/platform/accounts/:id/test_lab` | 런타임 dry-run / 메시지 시뮬레이션 | (신규 — MiniMax 단계에서 후속) |
| 11 | `/platform/accounts/:id/monitoring` | 일별 메트릭 (실행/게시/실패) | MetricRollup (선택) |
| 12 | `/platform/accounts/:id/safety` | 안전 로그/탐지 | SafetyLog |

## 4. UI/UX 갭

### 4.1 사이드바 (우선 작업)
- 현재: 상단 11-link nav — 페이지 깊이 표현 불가, 고객사별 콘솔 진입 시 혼잡
- 목표: 좌측 사이드바 (`/platform/accounts/:id/*` 선택 시 12개 메뉴)
- 디자인 시스템: P1 `app-shell` (max-w-1440 / sidebar 240px / main min-w-0) 와 **동일 구조**

### 4.2 breadcrumb
- 목표: `운영자 / 고객사 목록 / {계정명} / {현재 페이지}`
- 페이지 헤더: `<PageHeader title="…" subtitle="…">` 사용

### 4.3 통제 버튼 (사이드바 헤더)
- **긴급 일시중지** (POST `/platform/accounts/:id/suspend`)
- **재개** (POST `/platform/accounts/:id/reactivate`)
- **Discord 채널 강제 동기화** (POST `/platform/accounts/:id/discord_resync`)
- 모두 기존 `suspend/reactivate` 액션 재사용

## 5. 기존 자산 (재사용)
- `accounts#suspend` / `#reactivate` ✓ (`config/routes.rb` 245)
- `accounts#show` ✓ (placeholder → 콘솔 진입점으로 강화)
- `app/views/layouts/app.html.erb` 의 7-그룹 사이드바 패턴 ✓
- `shared/_stat_card.html.erb` partial (P3 신규) ✓
- `app/views/app/channels/index.html.erb` test/official 배지 ✓
- `OpsNotifier` (P2/P3) — 운영자 행위도 Discord 큐로 통보 가능

## 6. 권한 / 보안
- §16: platform_staff 역할별 권한 — `super_admin` / `support` / `viewer` 3-tier (현재 미구분)
- P4 후속 또는 P5 에서 `PlatformStaff#role` 기반 cancan/permit 도입
- **현재 P4 범위**: 모든 운영자에게 동일 노출, role 분기는 후속 task

## 7. 작업 단위 (P4 단계)

| 단계 | 내용 | 의존 |
|:---:|---|---|
| P4-1 | audit + verification (현재) | — |
| P4-2 | `Platform::Accounts::ConsolesController` 베이스 (`accounts/:id/*`) — `setup` 액션 우선 | P4-1 |
| P4-3 | setup view (6-카드, 소희 상태, 승인 대기 큐) | P4-2 |
| P4-4 | persona/knowledge/channels/automations/runtime/audit 6개 콘솔 페이지 | P4-2 |
| P4-5 | 플랫폼 사이드바 partial + breadcrumb | P4-2 |
| P4-6 | 통제 액션 (suspend/reactivate/discord_resync) 강화 | P4-3 |
| P4-7 | 검증 (trycloudflare `/platform/accounts/1/setup` 200 + 데모 12 routes) | P4-6 |

## 8. 검증 기준 (자체 정의)
- 운영자가 고객사 1개 클릭 → 12개 콘솔 페이지 모두 200
- 5초 안에 "정상인가 / 오늘 뭐했나 / 봐야할 것 / 페르소나/RAG/채널 / 정지" 5개 질문 응답 가능
- 사이드바 240px + main min-w-0 + app-shell max-w-1440 (P1과 동일)

## 9. 호스트 결정 필요
- P4-2 부터 코드 작업 시작할지 (지금 자동 진행 vs 호스트 확인)
- `setup` 카드 6종 (페르소나/RAG/채널/Runtime/테스트/DISCORD) 동의 여부
- role 권한 분기 (P4 포함 vs 후속) 결정