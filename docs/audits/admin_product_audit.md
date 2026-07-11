# 관리자 제품 전수 조사 보고서 (Admin Product Audit)

**조사 일자**: 2026-07-11  
**조사 범위**: `/app/*` 사업자 대시보드 + `/platform/*` 운영자 콘솔 + API (`/api/v1/*`)  
**조사 기준**: "소희 프로젝트 3차 대대적 리뉴얼 지시서" 6~18장

---

## 1. 사용자 모드

현재 코드베이스에는 **명시적인 두 모드 분리는 없음**. ApplicationController의 헬퍼로 `current_user`, `signed_in_as_business?`, `signed_in_as_platform?`가 존재하지만, **app 레이아웃은 사업자 모드 단일**, **platform 레이아웃은 운영자 모드 단일**로 분리되어 있음.

### 1.1 사업자 모드 (현재)

- **라우트 prefix**: `/app/*`
- **레이아웃**: `app/views/layouts/app.html.erb`
- **로그인**: `/login` → `UserSessionsController`
- **인증 토큰**: `cookies.signed[:workmori_user_token]` + `Session.find_by(token_hash:)`
- **인증 클래스**: `Session`, `User`, `Membership`, `Account`
- **계정 종류**: `Membership.role` (%w[owner operator reviewer])

### 1.2 운영자 모드 (현재)

- **라우트 prefix**: `/platform/*`
- **레이아웃**: `app/views/layouts/platform.html.erb`
- **로그인**: `/platform/login` → `Platform::SessionsController`
- **인증 토큰**: 별도 (PlatformSession)
- **계정 종류**: `PlatformStaff.role` (%w[admin operator viewer])

### 1.3 신규 지시서 요구 (6장)

| 지시 | 현재 | 갭 |
|------|------|-----|
| A. 운영자 모드 - 모든 설정/프롬프트/RAG/스킬/루틴/채널 인증/실행 로그/장애/계약 정보/배포 버전 | 부분 충족 (각 컨트롤러 존재, 통합 부재) | **"셋업 준비도" 화면, Runtime Configuration Bundle, 통합 IA 필요** |
| B. 사업자 모드 - 오늘 한 일 / 확인 필요 / 미리보기 / 문의 인계 / 피드백 / 보고서 / 사업장 정보 수정 요청 | 부분 충족 (dashboard, content_items, handoffs, reports, business_profiles 존재) | **기술 용어 은어 처리 (RAG→사업장지식, Prompt→업무기준 등) 필요** |

### 1.4 신규 지시서 요구 - 사업자 UI 용어 치환 (6장)

| 기술 용어 | 사업자 노출 용어 | 현재 노출 상태 | 처리 |
|----------|---------------|--------------|------|
| RAG | 사업장 지식 | 일부 뷰에서 RAG 그대로 노출 | **치환** |
| Prompt | 업무 기준 | 일부만 치환 | **전면 치환** |
| Agent skill | 소희가 할 수 있는 일 | 미사용 | **신규 도입** |
| Runtime config | 현재 적용 중인 설정 | 미사용 | **신규 도입** |
| Escalation | 원장님 확인 필요 | 일부 "handoffs" 노출 | **치환** |
| Automation routine | 반복 업무 일정 | 일부 "automation_rules" 노출 | **치환** |

---

## 2. 사업자 모드 (`/app/*`) - 기존 IA (조사 시점)

### 2.1 컨트롤러 + 라우트 매핑

| 신규 지시서 IA (16메뉴, 7장) | 현재 라우트 | 컨트롤러 | 상태 |
|----------------------------|-----------|---------|------|
| 1. 오늘의 업무 | `/app` | `DashboardsController#show` | ✅ 존재 (확장 필요) |
| 2. 셋업 현황 (준비도 점수) | **없음** | - | ❌ **신규 구축** |
| 3. 사업장 프로필 | `/app/business_profile` | `BusinessProfilesController` | ✅ 존재 (확장 필요) |
| 4. 소희 페르소나 | `/app/ai_employees` | `AiEmployeesController` | ✅ 존재 (확장 필요 - 채널별/버전관리 강화) |
| 5. 사업장 지식 | `/app/knowledge` | `KnowledgeSourcesController` | ✅ 존재 (확장 필요 - 메타데이터 강화) |
| 6. 스킬 | **없음** | - | ❌ **신규 구축** (12장 스킬 레지스트리) |
| 7. 자동화 루틴 | `/app/automations/rules` | `AutomationRulesController` | ✅ 존재 (확장 필요 - approval_mode/failure_action 등 신규 필드) |
| 8. 채널 | `/app/channels` | `ChannelsController` | ✅ 존재 (확장 필요 - env/posting_mode 등 신규 필드) |
| 9. 콘텐츠 | `/app/content/items` | `ContentItemsController` | ✅ 존재 (강화) |
| 10. 문의·인계 | `/app/conversations`, `/app/handoffs` | `ConversationsController`, `HandoffsController` | ✅ 존재 (강화) |
| 11. 테스트 랩 | **없음** | - | ❌ **신규 구축** (15장) |
| 12. 보고서 | `/app/reports` | `ReportsController` | ✅ 존재 (강화) |
| 13. 실행 로그 | `/app/delivery_logs`, `/app/automations/executions` | `DeliveryLogsController`, `AutomationExecutionsController` | ✅ 존재 (강화) |
| 14. 설정 배포 | **없음** | - | ❌ **신규 구축** (17장 Runtime Configuration Bundle) |
| 15. 계약·운영 정보 | `/app/billing`, `/app/plans` | `BillingController`, `PlansController` | ✅ 존재 (가격 비공개 처리) |
| 16. 보안·권한 | `/app/settings`, `/app/data_exports`, `/app/deletion_requests` | `SettingsController`, `DataExportsController`, `DeletionRequestsController` | ✅ 존재 (강화) |

### 2.2 사업자 IA 통계

- **총 라우트**: 약 130개 (단순 카운트)
- **컨트롤러**: 27개 (`app/controllers/app/*.rb`)
- **누락**: 셋업 준비도 / 스킬 / 테스트 랩 / 설정 배포 = 4개 신규

### 2.3 비즈니스 워크플로우 충족도

| 신규 지시서 기능 (P2) | 현재 상태 | 작업 |
|---------------------|---------|------|
| 셋업 준비도 점수 (0~100%) | ❌ | **신규 모델 + 신규 화면 + 신규 컨트롤러** |
| 페르소나 버전 관리 (draft/review/active/archived + 변경이력) | △ (`AiEmployeeVersion` 모델 존재, UI 약함) | **UI 강화 + 상태 enum + 변경이력 화면** |
| RAG 메타데이터 (12종 + 7상태) | △ (KnowledgeDocument 모델 존재, 메타 일부 누락) | **컬럼 추가 + 만료/상충 감지 로직** |
| 스킬 레지스트리 (12개 + 19필드) | ❌ | **신규 모델 + 컨트롤러 + 화면** |
| 자동화 루틴 필드 확장 (approval_mode, failure_action 등) | △ (AutomationRule 모델 존재, 일부 누락) | **컬럼 추가** |
| 채널 env/test·official + posting_mode | △ (ChannelConnection 존재, enum 일부) | **enum 추가** |
| 테스트 랩 (14종 시나리오 + 합격 기준) | ❌ | **신규 모델 + 컨트롤러 + 화면** |
| 피드백 흐름 (즉시 학습 금지 → 운영자 검토) | △ | **버튼 + 큐 + 승인 흐름** |
| 지식 공백 큐 | ❌ | **신규 모델 + 화면** |
| Runtime Configuration Bundle | ❌ | **신규 모델 + JSON 컴파일러 + API** |
| Hermes heartbeat / jobs API | ❌ | **신규 API + 화면** |
| 대시보드 재설계 (사업자/운영자 분리) | △ | **재설계** |

---

## 3. 운영자 모드 (`/platform/*`) - 기존 IA

### 3.1 컨트롤러 + 라우트 매핑

| 운영자 콘솔 기능 | 현재 라우트 | 컨트롤러 | 상태 |
|---------------|-----------|---------|------|
| 대시보드 | `/platform` | `Platform::DashboardsController#show` | ✅ |
| 계정 관리 | `/platform/accounts` | `Platform::AccountsController` | ✅ |
| 운영 직원 | `/platform/platform_staff` | `Platform::PlatformStaffsController` | ✅ |
| 문의 | `/platform/inquiries` | `Platform::InquiriesController` | ✅ |
| 피처 플래그 | `/platform/feature_flags` | `Platform::FeatureFlagsController` | ✅ |
| 감사 이벤트 | `/platform/audit_events` | `Platform::AuditEventsController` | ✅ |
| 인시던트 | `/platform/incidents` | `Platform::IncidentsController` | ✅ |
| 모델 카탈로그 | `/platform/model_catalog_entries` | `Platform::ModelCatalogEntriesController` | ✅ |
| 요금제 | `/platform/plans` | `Platform::PlansController` | ✅ |
| 업종 | `/platform/industries` | `Platform::IndustriesController` | ✅ |
| 업종 템플릿 | `/platform/industry_templates` | `Platform::IndustriesController` | ✅ |
| 프롬프트 템플릿 | `/platform/prompt_templates` | `Platform::PromptTemplatesController` | ✅ |
| 계약 | `/platform/contracts` | `Platform::ContractsController` | ✅ |
| 빌링 | `/platform/billings` | `Platform::BillingsController` | ✅ |
| 리포트 | `/platform/reports` | `Platform::ReportsController` | ✅ |
| Hermes (read-only) | `/platform/hermes` | `Platform::HermesController` | ✅ (단, 현재는 단순 read-only) |
| 공지사항 | `/platform/announcements` | `Platform::AnnouncementsController` | ✅ |

### 3.2 신규 지시서 - 운영자 대시보드 (18장)

| 카드 | 현재 상태 | 작업 |
|------|---------|------|
| 전체 고객사 상태 | ❌ | 신규 |
| 셋업 준비도 | ❌ | 신규 |
| Hermes heartbeat | ❌ | 신규 (read-only → 양방향) |
| 실패 작업 | △ | 강화 |
| 인증 만료 | ❌ | 신규 |
| 공식 전환 대기 | ❌ | 신규 |
| 지식 검수 대기 | ❌ | 신규 |
| 피드백 대기 | ❌ | 신규 |
| 월별 운영량 | △ | 강화 |

---

## 4. 인증/세션 구조

### 4.1 현재

- **사업자**: `cookies.signed[:workmori_user_token]` + `Session` 모델 (token_hash)
- **운영자**: `PlatformSession` 모델 (별도)
- **API**: `ApiToken` 모델 (service-account 인증)
- **Magic Link**: `MagicLink` 모델 (사업자/운영자 공용)

### 4.2 신규 (17장 - Hermes API)

```
GET /api/v1/agents/:agent_id/runtime-config
GET /api/v1/agents/:agent_id/runtime-config/version
POST /api/v1/agents/:agent_id/heartbeat
GET /api/v1/agents/:agent_id/jobs/next
POST /api/v1/jobs/:job_id/start
POST /api/v1/jobs/:job_id/succeed
POST /api/v1/jobs/:job_id/fail
POST /api/v1/jobs/:job_id/request-human
```

- **인증**: agent-specific token, token rotation, 최소 권한
- **secret 직접 노출 금지**: runtime config에는 reference만

---

## 5. 핵심 데이터 모델 (현황)

### 5.1 이미 존재 (강화 대상)

| 모델 | 용도 | 강화 필요 |
|------|------|---------|
| `Account` | 사업장 | - |
| `User` / `Membership` | 사용자/역할 | - |
| `AiEmployee` / `AiEmployeeVersion` | 페르소나/버전 | 채널별 페르소나 필드 강화 |
| `BusinessProfile` | 사업장 프로필 | 브랜드/고객 필드 강화 |
| `KnowledgeDocument` | RAG | 메타 12종 추가 |
| `AutomationRule` / `AutomationSchedule` | 자동화 루틴 | approval_mode/failure_action 추가 |
| `ChannelConnection` | 채널 | env/posting_mode enum 강화 |
| `ContentItem` | 콘텐츠 | - |
| `Handoff` | 사람 인계 | - |
| `Session` / `PlatformSession` / `MagicLink` / `ApiToken` | 인증 | - |
| `AuditEvent` | 감사 | - |
| `Billing` / `Invoice` / `Payment` / `Plan` / `ContractTerm` / `Deposit` | 결제/계약 | 가격 비공개 처리 |
| `FeatureFlag` | 기능 플래그 | - |
| `EscalationRule` / `GuardrailPolicy` | 안전 | - |
| `IndustryTemplate` / `ModelCatalogEntry` / `PromptTemplate` | 카탈로그 | - |

### 5.2 신규 (P2/P3)

| 모델 | 용도 |
|------|------|
| `SetupReadinessScore` | 사업장별 준비도 점수 (12영역) |
| `Skill` | 스킬 레지스트리 (12개 기본) |
| `TestLabScenario` / `TestLabRun` | 테스트 랩 시나리오/실행결과 |
| `Feedback` / `KnowledgeGap` | 피드백/지식 공백 |
| `RuntimeConfigBundle` / `RuntimeConfigVersion` | Runtime Configuration Bundle |
| `HermesJob` / `HermesHeartbeat` | Hermes 작업 큐 / heartbeat |
| `OwnerFeedback` (또는 위 Feedback 활용) | 사업자 피드백 |
| `PiiDetectionRule` (선택) | PII 자동 감지 |

---

## 6. 즉시 개선 필요 (P0~P1)

### 6.1 P0 (보안/노출)

- 사업자 dashboard의 "바이름 청라점" 텍스트 → "초기 파트너 매장" 또는 익명화
- ai_employees/index의 "바이름 청라점 / 이아름 원장님" → 익명화
- 공개 레이아웃의 "퍼플앤트 운영" → "소희 프로젝트 운영"
- 공개 사이트에서 가격/보증금/부가세 노출 완전 제거
- trycloudflare / ngrok 주소 공개 사이트 절대 노출 금지
- dev_login 안내 공개 노출 제거

### 6.2 P1 (랜딩 개편)

- 14섹션 신규 랜딩 구조로 재작성
- 익명 사례 1건만 (`pilot-beauty-studio-01`) 노출
- CTA 모두 도입 상담 폼으로 연결

### 6.3 P2 (관리자 IA 개편)

- 신규 16메뉴 IA 구현 (셋업 준비도 + 스킬 + 테스트 랩 + 설정 배포 추가)
- 사업자 UI 용어 치환 (RAG → 사업장 지식 등)

### 6.4 P3 (Hermes 연동)

- Runtime Configuration Bundle JSON 컴파일러
- 8개 Hermes API 엔드포인트
- heartbeat / jobs / versioning / rollback

### 6.5 P4 (운영 고도화)

- 콘텐츠/문의/보고서/피드백/지식공백/실행로그/보안 강화

---

## 7. 검증 방법

```bash
# 컨트롤러 카운트
echo "App 컨트롤러: $(ls app/controllers/app/*.rb | wc -l)"
echo "Platform 컨트롤러: $(ls app/controllers/platform/*.rb | wc -l)"
echo "Public 컨트롤러: $(ls app/controllers/public/*.rb | wc -l)"

# 라우트 카운트
bin/rails routes | wc -l
bin/rails routes | grep -c "^[[:space:]]*app"
bin/rails routes | grep -c "^[[:space:]]*platform"
bin/rails routes | grep -c "^[[:space:]]*public"

# 모델 카운트
echo "모델: $(ls app/models/*.rb | wc -l)"
```

---

## 8. 다음 액션

1. **P0**: 공개 위험 제거 (별도 audit `public_surface_audit.md` 참조)
2. **P1**: 랜딩 14섹션 재설계
3. **P2**: 관리자 IA 16메뉴 + 셋업 준비도 + 페르소나/RAG/스킬/루틴 강화
4. **P3**: Hermes Runtime Configuration Bundle + 8 API
5. **P4**: 운영 고도화 + 보안 + 피드백 + 지식공백