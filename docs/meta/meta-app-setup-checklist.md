# Meta 앱 설정 체크리스트 (Instagram + Threads)

**중요**: 이 문서는 **사람이 Meta 개발자 콘솔에서 직접 수행해야 하는 작업**만 포함한다. 실제 App ID, App Secret, 액세스 토큰을 AI가 입력하는 단계에서는 멈추고 사용자에게 안내한다. **가짜 값 금지**.

---

## 0. 전제

- Meta for Developers 계정 보유
- Facebook Page 보유 (Instagram Business 계정 연결용)
- Instagram 계정이 **Business 또는 Creator** 타입이어야 함
- Threads 계정이 **공개 게시 가능** 상태
- 도메인 1개 (HTTPS, 고정 tunnel 또는 자체 호스팅)

---

## 1. 앱 생성

- [ ] https://developers.facebook.com/apps 접속
- [ ] **앱 만들기** → 타입: **Business** 선택
- [ ] 앱 이름: `Sohee Meta Integration` (또는 회사 정책에 맞춰 변경)
- [ ] 비즈니스 계정 연결 (선택 — 추후 Business Verification 시 필요)
- [ ] **App ID**, **App Secret** 복사해 안전한 비밀 저장소에 보관
- [ ] `.env`에 `META_APP_ID`, `META_APP_SECRET` 자리만 만들어두고 값은 **사람이 직접 채움**

---

## 2. Instagram Graph API 사용 설정

### 2.1 제품 추가

- [ ] 앱 대시보드 → **제품 추가** → **Instagram** → **Instagram API with Instagram Login** 설정
- [ ] **Instagram Graph API**는 별도 — Instagram Login이 더 권장됨

### 2.2 권한(Scopes) 요청

| Scope | 용도 | 자동/검토 |
|---|---|---|
| `instagram_business_basic` | 프로필·미디어 읽기 | Basic Access (즉시) |
| `instagram_business_content_publish` | 이미지·캐러셀·릴 게시 | **Standard Access — App Review 필요** |
| `instagram_business_manage_comments` | 댓글 읽기·답글·숨김·삭제 | Standard Access — App Review 필요 |
| `instagram_business_manage_insights` | 인사이트 읽기 | Standard Access — App Review 필요 |
| `instagram_business_manage_messages` | DM (Phase 5) | **Advanced Access — App Review 필수** |

### 2.3 테스트 계정 준비

- [ ] **Roles** → **Instagram Testers** → Instagram 계정 추가
- [ ] 추가된 Instagram 계정에서 개발자 초대 **수락** (Instagram 앱 알림)
- [ ] 계정이 **Business** 또는 **Creator** 타입인지 확인 (Personal → 설정 → 계정 → 프로페셔널 전환)

### 2.4 OAuth Redirect / Webhook URL 등록

- [ ] **Instagram** → **API settings** → **Valid OAuth Redirect URIs**:
  ```
  https://<고정 도메인>/app/channels/instagram/oauth/callback
  ```
- [ ] **Deauthorize Callback URL**:
  ```
  https://<고정 도메인>/webhooks/instagram/deauthorize
  ```
- [ ] **Data Deletion Request URL**:
  ```
  https://고정 도메인/webhooks/instagram/data_deletion
  ```
- [ ] **Webhook URL** (메타 서명 검증 포함):
  ```
  https://<고정 도메인>/webhooks/instagram
  ```
- [ ] **Verify Token**: 32자 random hex 생성해 `META_INSTAGRAM_WEBHOOK_VERIFY_TOKEN` ENV에 저장

### 2.5 권한 App Review 준비

- [ ] **App Review** → **Permissions and Features** → 위 권한들 각각
- [ ] 제출물:
  - **화면 녹화** — Instagram 로그인부터 게시까지 실제 흐름
  - **테스트 계정 자격증명** (앱 테스터로 등록된 계정 ID/비번)
  - **시연 절차** 문서 (`docs/meta/app-review-plan.md` 참조)
  - **개인정보처리방침 URL** (자체 호스팅 페이지)
  - **이용약관 URL**
  - **데이터 삭제 안내 URL** (위 Data Deletion Callback과 동일)

---

## 3. Threads API 설정

### 3.1 제품 추가

- [ ] 앱 대시보드 → **제품 추가** → **Threads** → **Access the Threads API** use case 추가

### 3.2 권한(Scopes) 요청

| Scope | 용도 | 자동/검토 |
|---|---|---|
| `threads_basic` | 프로필·게시물 읽기 | Basic Access |
| `threads_content_publish` | 텍스트·이미지·캐러셀 게시 | Standard Access — App Review 필요 |
| `threads_read_replies` | 답글 읽기 | Standard Access |
| `threads_manage_replies` | 답글 작성·숨김 | Standard Access |
| `threads_manage_insights` | 인사이트 | Standard Access |
| `threads_keyword_search` | 공개 검색 (선택) | Standard Access |
| `threads_mentions` | 멘션 읽기 (선택) | Standard Access |
| `threads_delete` | 게시물 삭제 | Advanced Access — 사람 승인 필수 |

### 3.3 Threads 테스트 사용자

- [ ] **Roles** → **Threads API Testers** → Threads 계정 추가
- [ ] Threads 계정에서 **설정 → 계정 → 개발자** → 초대 수락
- [ ] 계정이 **공개** 프로필이어야 함

### 3.4 OAuth Redirect / Webhook

- [ ] **Threads** → **API settings** → **Valid OAuth Redirect URIs**:
  ```
  https://<고정 도메인>/app/channels/threads/oauth/callback
  ```
- [ ] **Webhook URL**:
  ```
  https://<고정 도메인>/webhooks/threads
  ```
- [ ] **Verify Token**: 별도 생성, `META_THREADS_WEBHOOK_VERIFY_TOKEN` ENV에 저장

---

## 4. App Review / App Verification 단계

### 4.1 사전 준비

- [ ] **Business Verification** — 사업자등록증, 정식 도메인, 공개 연락처
- [ ] **Data Deletion Instructions** 페이지 (Data Deletion Callback URL에서 사용자에게 안내)
- [ ] **개인정보처리방침** 페이지 (앱 공개용)
- [ ] **이용약관** 페이지
- [ ] **App Icon** 1024x1024
- [ ] **테스트 계정** 2개 이상 (Instagram 1 + Threads 1)

### 4.2 제출 절차

1. App Review → Permissions and Features → 각 권한별 "Request" 버튼
2. 화면 녹화 (30~120초): OAuth 흐름부터 게시까지
3. 테스트 계정 자격증명 입력
4. 시연 절차 PDF 업로드 (`docs/meta/app-review-plan.md` 기반)
5. 제출 후 5~14 영업일 대기
6. 보완 요청 시 빠른 응대 (보통 추가 정보 제출 후 24~72시간)

### 4.3 Advanced Access 단계 (DM, 대량 작업 등)

- Advanced Access는 별도 심사 + 사업 영향 설명 필요
- Privacy Policy + Data Deletion + Compliance 검증 필수

---

## 5. 토큰 발급 흐름 (테스트 단계)

### 5.1 Instagram 테스트 토큰

1. Graph API Explorer 접속
2. 앱 선택 (방금 만든 앱)
3. User or Page → **Instagram Business 계정** 선택
4. Permissions 추가 (위 scope들)
5. **Generate Access Token** → 단기 토큰 발급
6. 단기 → **장기 토큰(60일)** 변환:
   ```
   GET https://graph.facebook.com/v19.0/oauth/access_token
     ?grant_type=fb_exchange_token
     &client_id={APP_ID}
     &client_secret={APP_SECRET}
     &fb_exchange_token={SHORT_LIVED_TOKEN}
   ```
7. **사람이 직접** `META_GRAPH_API_TOKEN` ENV에 붙여넣기 (코드 출력 금지)

### 5.2 Threads 테스트 토큰

1. Threads API Explorer 또는 Threads 자체 OAuth 플로우
2. 위 scope들 선택 → 단기 토큰 발급
3. 단기 → 장기 토큰 변환 (Threads API 동일 패턴)
4. `THREADS_ACCESS_TOKEN` ENV에 저장

---

## 6. ★ 사람 입력 필요 지점 (AI는 여기서 멈춤)

| 시점 | 입력 항목 | 위치 |
|---|---|---|
| 앱 생성 직후 | `META_APP_ID`, `META_APP_SECRET` | `.env` (사용자 직접) |
| OAuth 시작 | — | 코드에서 자동 |
| OAuth 콜백 후 | 토큰은 자동 저장 | — |
| App Review 제출 | 시연 절차 문서, 화면 녹화, 테스트 계정 ID/비번 | Meta 콘솔 |
| 장기 토큰 변환 | `client_secret`은 .env, 단기 토큰은 Graph Explorer 출력값 | .env + Meta 콘솔 |
| App Review 통과 후 | 공식 계정 연결용 추가 권한 | Meta 콘솔 |

---

## 7. 다음 단계 (사람 작업 후)

1. App Review 제출
2. 통과 시 Standard Access 권한 활성화
3. 테스트 계정으로 게시·답글 검증 (소희 프로젝트 자동화)
4. Advanced Access (DM 등) 별도 심사
5. 공식 계정 전환 — Business Verification + 추가 심사

---

## 8. 보안 유의사항

- **App Secret은 절대 코드/로그/대화에 출력 금지**
- Access Token은 DB 암호화 저장 (Rails `encrypts` 확인됨)
- 토큰 만료 7일 전 자동 갱신 시도
- 갱신 실패 시 `ChannelConnection.status = "error"` + 사람 알림
- 사업장 간 토큰 공유 금지 (`account_id`로 격리)