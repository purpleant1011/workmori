# Instagram Capability Matrix

**범위**: Instagram Graph API + Instagram Login API가 제공하는 기능 vs 소희 프로젝트 자동화 매핑

---

## 1. 권한(Scope)별 기능 매트릭스

### 1.1 읽기

| 기능 | Scope | 공식 API | 사용 시점 | 소희 자동화 |
|---|---|---|---|---|
| 자기 프로필 | `instagram_business_basic` | `GET /me?fields=id,username,biography,website,followers_count,follows_count,media_count,profile_picture_url` | 자동화 시작 시 채널 검증 | Hermes가 채널 상태 점검 시 |
| 미디어 목록 | `instagram_business_basic` | `GET /me/media?fields=id,caption,media_type,media_url,permalink,thumbnail_url,timestamp` | 자동화 게시 후 외부 ID 검증 | ContentItem.published_external_url 동기화 |
| 단일 미디어 | `instagram_business_basic` | `GET /{media-id}?fields=id,caption,...` | 결과 재확인 | publication_attempt 검증 |
| 댓글 목록 | `instagram_business_manage_comments` | `GET /{media-id}/comments?fields=id,text,username,timestamp,like_count,replies` | Phase 3 자동 응대 | engagement/automator |
| 답글 스레드 | `instagram_business_manage_comments` | `GET /{comment-id}/replies` | 답글 답 답글 | engagement/automator |
| 멘션 | `instagram_business_manage_insights` (제한) | `GET /{user-id}/mentioned_media` 또는 Webhook | 향후 확장 | — |
| 인사이트 (계정) | `instagram_business_manage_insights` | `GET /{user-id}/insights?metric=follower_count,profile_views,reach,...&period=day` | Phase 4 보고서 | weekly_report 생성 |
| 인사이트 (미디어) | `instagram_business_manage_insights` | `GET /{media-id}/insights?metric=impressions,reach,saved,likes,comments,shares` | Phase 4 콘텐츠 성과 | content_item 성과 추적 |

### 1.2 게시

| 기능 | Scope | 공식 API | 자동화 정책 | 위험도 |
|---|---|---|---|---|
| 이미지 단일 | `instagram_business_content_publish` | 2-step: `POST /me/media` (container) → `POST /me/media_publish` | Risk 1 (테스트) / Risk 2 (공식) | R1/R2 |
| 캐러셀 | `instagram_business_content_publish` | `POST /me/media` (children + is_carousel_item=true × N) → `POST /me/media_publish` | Risk 1/R2 | R1/R2 |
| 릴(Reels) | `instagram_business_content_publish` | `POST /me/media` (media_type=REELS, video_url) → `POST /me/media_publish` (비동기) | Risk 1/R2 | R1/R2 |
| 스토리 | `instagram_business_content_publish` | `POST /me/media` (media_type=STORIES, image_url/video_url) → `POST /me/media_publish` | Risk 1/R2 | R1/R2 |

### 1.3 응대

| 기능 | Scope | 공식 API | 자동화 정책 | 위험도 |
|---|---|---|---|---|
| 댓글 답글 | `instagram_business_manage_comments` | `POST /{comment-id}/replies` | Risk 1: 테스트 자동 / Risk 2: 고신뢰 FAQ 자동 / Risk 3: 사람 승인 | R1/R2/R3 |
| 댓글 숨김 | `instagram_business_manage_comments` | `POST /{comment-id}?hide=true` 또는 `hide` 엔드포인트 변동 | **항상 사람 승인** | R4 |
| 댓글 숨김 해제 | `instagram_business_manage_comments` | `POST /{comment-id}?unhide=true` | Risk 3 | R3 |
| 댓글 삭제 | `instagram_business_manage_comments` | `DELETE /{comment-id}` | **항상 사람 승인** | R4 |
| 미디어 댓글 비활성화 | `instagram_business_manage_comments` | `POST /{media-id}?comment_enabled=false` | **항상 사람 승인** | R4 |
| 미디어 삭제 | `instagram_business_content_publish` | `DELETE /{media-id}` | **항상 사람 승인** | R4 |

### 1.4 DM (Phase 5)

| 기능 | Scope | 공식 API | 자동화 정책 | 위험도 |
|---|---|---|---|---|
| 대화 목록 | `instagram_business_manage_messages` | `GET /me/conversations?platform=instagram` | 자동 허용 (읽기) | R0 |
| 단일 대화 | `instagram_business_manage_messages` | `GET /{conversation-id}` | 자동 허용 (읽기) | R0 |
| DM 발송 | `instagram_business_manage_messages` | `POST /me/messages` | **24시간 응답창 + Risk 3** | R3 |
| 비공개 답글 (Private Reply) | `instagram_business_manage_messages` | 댓글 작성자에게만 DM (멘션/답글 자동 트리거) | Risk 3 | R3 |

---

## 2. Webhook 이벤트 (Instagram)

| 이벤트 | 페이로드 핵심 | 처리 |
|---|---|---|
| `comments` | `comment_id`, `media_id`, `from.username`, `text`, `timestamp` | 자동화 응대 큐 적재 |
| `mentions` | `media_id`, `comment_id` (멘션된 미디어) | 멘션 추적 |
| `messages` | `conversation_id`, `from`, `message`, `timestamp` | DM 큐 적재 |
| `story_insights` | `story_id`, `impressions`, `reach`, `replies` | 인사이트 적재 |

## 3. 속도 제한

- **Meta 자체 제한**: 사용자 토큰당 200 호출/시간 (기본), 게시는 별도
- **Graph 게시 API**: 분당 약 25회 (Instagram 측 명시, 가변)
- **소희 측 안전 제한**: 분당 5회 게시, 시간당 30건, 일일 100건 (사업장별)

## 4. 제한 사항

- 릴(Reels) 비디오 업로드는 **공개 URL**이어야 함 (소희는 `rails_blob_url` 사용 OK)
- 캐러셀 최대 10장
- 이미지 권장: 1080×1080 (정사각), 1080×1350 (세로), 1080×1920 (릴/스토리)
- 자동 DM 발송은 **사용자가 먼저 DM을 보낸 후 24시간 응답창** 내에서만 가능
- 스토리는 24시간 후 자동 소멸 — 보관은 인사이트 스냅샷으로

## 5. 공식 API로 해결 안 되는 것

| 항목 | 정책 |
|---|---|
| 팔로우/언팔로우 자동화 | ❌ **절대 금지** — Meta 정책 위반 + 소희 정책 위반 |
| 대량 좋아요 | ❌ **절대 금지** |
| 캡차 우회 | ❌ **절대 금지** |
| 2단계 인증 우회 | ❌ **절대 금지** |
| 대량 DM (cold outreach) | ❌ **절대 금지** |
| 비공개 계정 접근 | ❌ **절대 금지** |

## 6. Playwright 보조 검증 범위

| 용도 | 사용 |
|---|---|
| Meta 개발자 콘솔 설정 화면 캡처 | OK (사용자 동의 하) |
| 공식 게시가 실제 Instagram에 표시되는지 화면 확인 | OK (테스트 계정, 소량) |
| DM이 실제 수신되는지 화면 확인 | OK (테스트 계정) |
| 자동 팔로우/좋아요/대량 DM 검증 | ❌ **절대 사용 안 함** |