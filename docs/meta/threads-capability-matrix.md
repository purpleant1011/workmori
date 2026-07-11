# Threads Capability Matrix

**범위**: Threads API가 제공하는 기능 vs 소희 프로젝트 자동화 매핑
**공식 문서**: https://developers.facebook.com/docs/threads

---

## 1. 권한(Scope)별 기능 매트릭스

### 1.1 읽기

| 기능 | Scope | 공식 API | 사용 시점 | 소희 자동화 |
|---|---|---|---|---|
| 자기 프로필 | `threads_basic` | `GET /{user-id}?fields=id,username,threads_profile_picture_url,threads_biography` | 채널 검증 | 자동 |
| 게시물 목록 | `threads_basic` | `GET /{user-id}/threads?fields=id,media_type,permalink,text,timestamp,is_quote_post` | 결과 검증 | 자동 |
| 단일 게시물 | `threads_basic` | `GET /{thread-id}?fields=...` | publication_attempt 검증 | 자동 |
| 답글 목록 | `threads_read_replies` | `GET /{thread-id}/replies?fields=id,text,username,timestamp,permalink,media_type,...` | Phase 3 답글 응대 | 자동 |
| 대화(컨버세이션) | `threads_basic` | `GET /{user-id}/conversations` (DM — 별도 권한) | DM 단계에서 | 자동 |
| 인사이트 (계정) | `threads_manage_insights` | `GET /{user-id}/threads_insights?metric=views,likes,replies,reposts,quotes,followers_count` | 보고서 | 자동 |
| 인사이트 (게시물) | `threads_manage_insights` | `GET /{thread-id}/insights?metric=views,likes,replies,reposts,quotes` | 콘텐츠 성과 | 자동 |
| 멘션 | `threads_mentions` (선택) | `GET /{user-id}/mentions` 또는 Webhook | 향후 확장 | — |
| 키워드 검색 | `threads_keyword_search` (선택) | `GET /keyword_search?q=...&search_type=...` | 트렌드 리서치 (참조 분석 아님) | 제한적 |

### 1.2 게시

| 기능 | Scope | 공식 API | 자동화 정책 | 위험도 |
|---|---|---|---|---|
| 텍스트 단일 | `threads_content_publish` | 3-step: `POST /{user-id}/threads` (text, media_type=TEXT) → 폴링 status=FINISHED → `POST /{user-id}/threads_publish` | Risk 1/R2 | R1/R2 |
| 이미지 단일 | `threads_content_publish` | `POST /{user-id}/threads` (media_type=IMAGE, image_url, text) → publish | Risk 1/R2 | R1/R2 |
| 비디오 단일 | `threads_content_publish` | `POST /{user-id}/threads` (media_type=VIDEO, video_url) → publish | Risk 1/R2 | R1/R2 |
| 캐러셀 | `threads_content_publish` | `POST /{user-id}/threads` (media_type=CAROUSEL, children=[...]) → 각 children → publish | Risk 1/R2 | R1/R2 |
| 인용 게시 (quote post) | `threads_content_publish` | `POST /{user-id}/threads` (quote_post_id=...) | Risk 3 (신중) | R3 |

### 1.3 응대

| 기능 | Scope | 공식 API | 자동화 정책 | 위험도 |
|---|---|---|---|---|
| 게시물 답글 | `threads_manage_replies` | `POST /{thread-id}/replies` (text, media_type, ... → reply_to_id) | Risk 1: 테스트 자동 / Risk 2: 고신뢰 FAQ 자동 / Risk 3: 부정 응대, 선제 답글 | R1/R2/R3 |
| 답글 숨김 | `threads_manage_replies` | `POST /{reply-id}/hide` (또는 `?hide=true`) | **항상 사람 승인** | R4 |
| 답글 숨김 해제 | `threads_manage_replies` | `POST /{reply-id}/unhide` | Risk 3 | R3 |
| 답글 관리 제어 변경 | `threads_manage_replies` | `POST /{thread-id}/reply_control` (`reply_control=everyone|accounts_you_follow|mentioned_only`) | **항상 사람 승인** | R4 |
| 게시물 삭제 | `threads_delete` | `DELETE /{thread-id}` | **항상 사람 승인** | R4 |
| 답글 삭제 | `threads_manage_replies` | `DELETE /{reply-id}` | **항상 사람 승인** | R4 |

### 1.4 DM (Threads)

- Threads DM은 별도 정책 — Instagram DM과 응답창 규칙 다름
- 현재 자동화 범위에서 **DM 발송 안 함** (Phase 5 이후 검토)

---

## 2. Webhook 이벤트 (Threads)

| 이벤트 | 페이로드 핵심 | 처리 |
|---|---|---|
| `threads-replies` | `reply_id`, `thread_id`, `from.username`, `text`, `timestamp` | 자동화 응대 큐 |
| `threads-mentions` | `mention_id`, `thread_id` | 멘션 추적 |
| `threads-media-update` | 미디어 상태 변경 (삭제 등) | publication_attempt 상태 동기화 |

## 3. 속도 제한

- **Threads API 자체 제한**: 분당 약 100 호출 (계정별)
- **게시**: 분당 약 10회 (안전 마진), 시간당 100건
- **답글**: 분당 약 30회
- **소희 측 안전 제한**: 분당 5회 게시, 시간당 30건 (사업장별, 더 보수적)

## 4. 제한 사항

- 텍스트 최대 500자
- 이미지: 최대 8장 캐러셀, 권장 1080×1080
- 비디오: 최대 5분 (2026년 기준 변경 가능 — 공식 문서 확인)
- 자동 답글은 **공개 답글만** (DM은 별도 정책)
- 인용 게시는 자동화에서 신중 — 원본 게시물 작성자 동의 추정 어려움

## 5. 공식 API로 해결 안 되는 것

| 항목 | 정책 |
|---|---|
| 팔로우/언팔로우 | ❌ Meta 정책 + 소희 정책 위반 |
| 대량 좋아요/리포스트 | ❌ 정책 위반 |
| DM 스팸 | ❌ 정책 위반 |
| 비공개 게시물 접근 | ❌ 불가 |
| 검색 기반 대량 크롤링 | ❌ 정책 위반 |

## 6. Playwright 보조 검증 범위

| 용도 | 사용 |
|---|---|
| Threads 게시물 실제 표시 확인 | OK (테스트 계정, 소량) |
| 답글 표시 확인 | OK |
| 멘션 표시 확인 | OK |
| 자동 팔로우/대량 답글 검증 | ❌ **절대 사용 안 함** |

## 7. Threads 특이사항

- Threads는 **공개 프로필** 기본값 — 비공개 설정 시 API 접근 제한
- Threads API는 상대적으로 신생 — 정책·엔드포인트 빈번 변경
- 모든 자동화 코드는 **API 버전 명시** (`THREADS_API_VERSION=v1.0`)
- Graph Explorer 또는 Threads API Explorer에서 수동 테스트 필수
- `threads_search_public_posts`는 키워드 기반 공개 검색만 (대량 크롤링 불가)