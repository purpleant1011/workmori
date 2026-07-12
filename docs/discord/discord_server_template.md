# Discord-Native 확장 — Discord 서버 템플릿 (5단계)

> 기준: `security_model.md` (4단계), `data_flow.md` (3단계)
> 사람 단계: 실제 Discord 서버 생성·Bot 초대·카테고리 권한은 운영자가 수동 진행

---

## 0. 서버 생성 절차 (수동)

1. https://discord.com/developers/applications → "New Application"
2. Bot 탭 → "Add Bot" → Token 복사 (한 번만 표시, 즉시 안전한 곳에 저장)
3. Privileged Intents 활성화:
   - ✅ Message Content Intent (메시지 본문 읽기)
   - ✅ Server Members Intent (멤버 목록)
   - ✅ Presence Intent (선택)
4. OAuth2 → URL Generator:
   - scopes: `bot applications.commands`
   - bot permissions: 9개 (View Channels, Send Messages, Read Message History, Send Messages in Threads, Create Public/Private Threads, Manage Threads, Attach Files, Embed Links, Use Application Commands)
5. 생성된 URL로 테스트 서버에 Bot 초대

> ⚠️ **Production 봇은 Administrator 권한 절대 부여 금지**.

---

## 1. 서버 구조

### 서버 단위

- **운영 서버** (1개): 퍼플앤트 운영팀 + 모든 고객사 운영 카테고리 + 글로벌 카테고리
- **테스트 서버** (1개): MVP 테스트용
- **고객사 서버** (선택): 대규모 고객사는 자체 서버, Bot이 초대됨

권장: **운영 서버 1개 + 고객사별 비공개 Category**. 모든 고객사가 한 서버에 있지만 Category 권한으로 격리.

---

## 2. 카테고리 템플릿

### 글로벌 (모든 사업장 공통, 운영팀만)

```
[서버 이름] 소희 운영 콘솔
├── 📢 운영-공지            (운영팀 read/write, 사업자 read)
├── 🛠 운영-장애알림        (Bot 자동 게시, 운영팀 read)
├── 📊 일일운영-보고        (Bot 일 1회 게시, 운영팀 read)
└── 🔒 보안-감사로그        (Bot 자동 게시, 운영팀 read)
```

### 고객사별 (예: 카페 소희)

```
[Cafe Sohee]
├── 💬 소희-대화             (owner/staff write/read, Bot)
├── ✅ 확인-승인             (owner write, Bot read/write)
├── 📝 콘텐츠-검수           (owner/staff write, Bot read/write)
├── 🆘 문의-인계             (operator read/write, Bot)
├── 📈 일일보고              (Bot write only, owner/staff read)
├── 📂 자료-업로드           (owner/staff write, Bot read)
└── 💡 요청-수정             (Forum Channel, owner/staff write, Bot)
```

채널 ID는 자동 생성되며, `discord_workspaces` 테이블에 저장됨.

---

## 3. 채널별 역할

### 글로벌 역할

| 역할 | 권한 | 부여 대상 |
|---|---|---|
| `sohee_operator` | 모든 카테고리 read, 운영 콘솔 write | 퍼플앤트 운영팀 |
| `sohee_platform_admin` | 서버 관리 | 1-2명 |
| `sohee_bot` | 제한된 봇 권한 | 봇 계정 |

### 고객사 역할 (고객사마다 별도 생성)

| 역할 | 권한 | 부여 대상 |
|---|---|---|
| `csohee_owner` | 고객사 카테고리 모든 채널 read/write, 설정 변경 가능 | 대표 1인 |
| `csohee_staff` | #소희-대화, #콘텐츠-검수, #일일보고, #자료-업로드 read/write | 직원 |
| `csohee_viewer` | 모든 채널 read only | 매니저 옵션 |

### 채널 권한 매트릭스

| 채널 | csohee_owner | csohee_staff | csohee_viewer | sohee_bot |
|---|---|---|---|---|
| #소희-대화 | R/W | R/W | R | R/W |
| #확인-승인 | R/W | R | R | R/W |
| #콘텐츠-검수 | R/W | R/W | R | R/W |
| #문의-인계 | R | R | R | R/W |
| #일일보고 | R | R | R | R/W |
| #자료-업로드 | R/W | R/W | R | R/W |
| #요청-수정 (Forum) | R/W (Thread) | R/W (Thread) | R (Thread) | R/W (Thread) |

운영팀 카테고리는 `sohee_operator`만.

---

## 4. Bot 권한 정책

### Bot이 할 수 있는 것

- ✅ 메시지 읽기/전송
- ✅ Embed 전송 (승인 카드)
- ✅ Button 전송 (5종)
- ✅ Modal 전송 (수정 요청)
- ✅ Slash Command 응답
- ✅ Thread 생성/관리 (요청-수정)
- ✅ File 첨부 (보고서 PDF)
- ✅ Reaction 추가 (승인/거절 보조)
- ✅ Typing 표시

### Bot이 할 수 없는 것

- ❌ 메시지 삭제 (관리자 권한 필요)
- ❌ 사용자 차단/kick/ban
- ❌ 역할 관리
- ❌ 채널 생성/삭제
- ❌ Webhook 관리
- ❌ @everyone / @here 멘션

---

## 5. 슬래시 명령

### 글로벌 명령 (서버에 1세트)

| 명령 | 설명 | 권한 |
|---|---|---|
| `/소희 상태` | 현재 런타임 상태, 최근 변경 내역 | owner, staff |
| `/소희 기억` | 사업장이 검증한 사실 목록 | owner, staff |
| `/소희 규칙` | 운영 규칙 목록 (영업시간, 금지어 등) | owner, staff |
| `/소희 이번만` | 일회성 작업 모드 전환 | owner |
| `/소희 캠페인` | 활성 캠페인 목록 + 만료일 | owner, staff |
| `/소희 확인` | 미처리 변경 제안 목록 | owner |
| `/소희 변경내역` | 최근 10건 변경 이력 | owner, staff |
| `/소희 되돌리기` | 최근 Runtime 롤백 | owner, operator |
| `/소희 멈춤` | 긴급 중지 | owner, manager |
| `/소희 재개` | 중지 해제 | owner, manager |
| `/소희 도움` | 사용 가이드 | 모두 |

### 명령 구현 흐름

```
사용자: /소희 멈춤
     │
[A] interaction_handler → POST /api/v1/discord/interactions (type=APPLICATION_COMMAND)
     │
[B] DiscordInteractionsController#create
     │  ① AuditEvent(action: discord.slash_command, command: "멈춤")
     │  ② 권한 확인 (owner/manager)
     │  ③ Account.emergency_stop = true
     │  ④ 즉시 응답 (Modal 또는 Ephemeral 메시지)
     ▼
[Discord] "🛑 긴급 중지 활성화. 모든 자동 작업이 일시정지됩니다."
```

---

## 6. 승인 카드 템플릿

### Embed 구조

```json
{
  "title": "🔔 변경 제안: 영업시간",
  "color": 16744448,  // amber
  "fields": [
    { "name": "변경 항목", "value": "business_hours_json", "inline": true },
    { "name": "위험도", "value": "🟢 낮음", "inline": true },
    { "name": "적용 시점", "value": "2026-07-13 00:00 (즉시)", "inline": true },
    { "name": "영향 채널", "value": "인스타그램, 네이버 블로그, 카카오 채널", "inline": false },
    { "name": "기존 값", "value": "```json\n{\"mon~fri\":\"09:00~21:00\",\"sat\":\"10:00~20:00\"}\n```", "inline": false },
    { "name": "새 값", "value": "```json\n{\"mon~fri\":\"10:00~22:00\",\"sat\":\"12:00~22:00\"}\n```", "inline": false },
    { "name": "사유", "value": "저녁 손님 증가로 시간 연장", "inline": false },
    { "name": "신뢰도", "value": "92%", "inline": true }
  ],
  "footer": { "text": "변경 제안 #42 · 유효기간 24시간" }
}
```

### 버튼 (최대 5개)

```json
{
  "type": 1,
  "components": [
    {
      "type": 2,
      "style": 3,  // green
      "label": "적용",
      "custom_id": "change:42:apply"
    },
    {
      "type": 2,
      "style": 1,  // blue
      "label": "수정",
      "custom_id": "change:42:edit"
    },
    {
      "type": 2,
      "style": 2,  // grey
      "label": "이번만",
      "custom_id": "change:42:once"
    },
    {
      "type": 2,
      "style": 1,  // blue
      "label": "운영팀 검토",
      "custom_id": "change:42:operator"
    },
    {
      "type": 2,
      "style": 4,  // red
      "label": "취소",
      "custom_id": "change:42:cancel"
    }
  ]
}
```

### Interaction 응답

| 버튼 | 동작 |
|---|---|
| 적용 | ChangeProposal.status = approved, RuntimeConfig Draft 생성, 활성화, Hermes 동기화 |
| 수정 | Modal 열림 → 사업자가 직접 수정 → 재제출 |
| 이번만 | 영구 저장 X, 작업 큐만 추가, expires_at 설정 |
| 운영팀 검토 | ChangeProposal.status = needs_review, 운영팀 콘솔 알림 |
| 취소 | ChangeProposal.status = cancelled, Discord 메시지 |

---

## 7. Forum Channel: #요청-수정

각 요청이 별도 Thread.

### Thread 생성 패턴

```
[Forum Channel] #요청-수정
├── Thread: 영업시간 변경 (07-12)
│   ├── 사업자: "오늘부터 10시부터로 바꿔줘"
│   ├── 소희: "변경 카드를 보냈습니다. #확인-승인에서 확인해 주세요."
│   └── (Thread 자동 닫힘 24h 후)
└── Thread: 신메뉴 카드뉴스 (07-12)
    ├── 사업자: "딸기라떼 카드뉴스 만들어줘"
    └── ...
```

### Thread 자동 관리

- 24시간 후 자동 archive
- 사업자가 명시적으로 닫으면 즉시 archive
- Bot은 archive 안 함 (운영자만)

---

## 8. 테스트 서버 구성

### 분리

- **테스트 서버**: `sohee-test` 이름, 자유롭게 테스트
- **프로덕션 서버**: `sohee-prod`, 고객사 카테고리만

### Bot 토큰 분리

- `DISCORD_BOT_TOKEN_TEST` — 테스트 서버 전용
- `DISCORD_BOT_TOKEN_PROD` — 프로덕션 전용
- ENV로 분리, 실수로 다른 서버에 게시 방지

### 테스트 시나리오

- 일반 대화
- 변경 제안
- 승인 / 취소 / 이번만
- 롤백
- tenant 격리 시도 (반드시 차단되어야 함)
- 메시지 수정/삭제
- 429 시뮬레이션
- Gateway 재연결

---

## 9. Discord 사용자 검증 흐름

### 사업자가 Discord로 처음 연결할 때

```
1. 사업자 웹 (/app/settings/discord) → "Discord 연결하기" 클릭
2. Rails: 6자리 일회용 코드 생성 (5분 유효), MagicLink 패턴
3. 사업자: Discord에서 봇에게 DM → "/verify 123456"
4. 봇 → Rails API: verify_discord_code(discord_user_id, code)
5. Rails: DiscordIdentity INSERT (verified_at = now, status='active')
6. Discord: "✅ 연결 완료. #소희-대화에서 시작하세요."
```

### 운영자용 매핑

```
1. 운영자 콘솔 → "Discord 사용자 매핑" → Discord User ID 입력
2. Rails: DiscordIdentity INSERT (role='operator')
```

---

## 10. 매니페스트 (자동 배포)

### 권장: 고객사 Discord 템플릿 JSON

```json
{
  "name": "Cafe Sohee",
  "type": 0,
  "channels": [
    { "name": "소희-대화", "type": 0 },
    { "name": "확인-승인", "type": 0 },
    { "name": "콘텐츠-검수", "type": 0 },
    { "name": "문의-인계", "type": 0 },
    { "name": "일일보고", "type": 0 },
    { "name": "자료-업로드", "type": 0 },
    { "name": "요청-수정", "type": 15 }
  ],
  "roles": [
    { "name": "csohee_owner", "color": "GOLD" },
    { "name": "csohee_staff", "color": "BLUE" },
    { "name": "csohee_viewer", "color": "GREY" }
  ]
}
```

> Bot은 이 템플릿으로 카테고리 생성 가능 (MANAGE_CHANNELS 권한 필요). 운영자가 수동으로 생성 후 Bot 권한 부여하는 것도 가능.

---

## 11. 모니터링 & 로깅

### Bot 로그 위치

- stdout (구조화 JSON, pino)
- Sentry (에러)
- 운영팀 Discord #장애-알림 (심각)

### 로깅 항목

- 이벤트 수신/처리
- Interaction 응답
- Outbound 발송
- 에러/스택트레이스
- 재연결 이벤트

### 로깅 금지

- 사용자 메시지 본문 (원문은 Rails `raw_payload_encrypted`에)
- 첨부파일 내용
- 토큰/키
- 결제/개인정보

---

## 12. 첫 MVP 서버 설정

### 단계

1. **테스트 Discord 서버 생성** (이름: `소희 MVP 테스트`)
2. **Bot 생성 + Token 발급 + 저장** (macOS Keychain)
3. **Privileged Intent 활성화**
4. **Bot 초대** (Administrator 권한 없이 9개 권한만)
5. **글로벌 카테고리 + 테스트용 고객사 카테고리 1개** 수동 생성
6. **역할 생성** (sohee_operator, sohee_bot, ctest_owner, ctest_staff)
7. **사용자 매핑 테스트** (운영자 1명 + 테스트 사업자 1명)

> 이후 P0/P1 구현 완료 후 자동화.

---

## 다음 단계

→ `gemini_provider_strategy.md` — Provider 인터페이스 + 모델/사고수준 정책 + Antigravity 정책