# 공개 영역 전수 조사 보고서 (Public Surface Audit)

**조사 일자**: 2026-07-11  
**조사 범위**: docs/, app/views/public/, app/views/user_sessions/, app/views/signups/, app/controllers/public/, app/views/layouts/public.html.erb  
**조사 기준**: "소희 프로젝트 3차 대대적 리뉴얼 지시서" 0절 (절대 준수 원칙) + 1절 (전수 조사) + 2절 (공개 영역 긴급 정리)

---

## 1. 랜딩 페이지 (`docs/index.html`, 462 lines)

### 1.1 식별 위험 노출

| # | 위치 (라인) | 노출 텍스트 | 위험 등급 | 처리 |
|---|------------|------------|----------|------|
| 1 | `<meta description>` (7) | "퍼플앤트가 세팅하고, 소희가 일하고..." | 운영사 노출 | **삭제** |
| 2 | `<meta og:description>` (9) | "바이름 청라점이 첫 파트너" | 실명+지역 | **삭제** |
| 3 | `.compare-col` CSS (81) | "(소희/퍼플앤트)" | 운영사 노출 | **삭제** |
| 4 | 내비 (155) | `#byreum` 앵커 | 실명 슬러그 | **익명 슬러그로 교체** |
| 5 | 내비 (157) | `trycloudflare.com/app` 관리자 CTA | 임시 도메인 노출 | **삭제** |
| 6 | hero-meta (166) | "초기 파트너: 바이름 청라점 · 인천 청라 · 25년 경력" | 실명+지역+경력 | **삭제** |
| 7 | hero-disclaimer (171) | "퍼플앤트가 세팅하고, 소희가 일합니다" | 운영사 노출 | **수정** |
| 8 | step 카드 (281) | "운영 대시보드 — 바이름 청라점" | 실명 | **익명** |
| 9 | step 카드 (296) | "고객 김선영 님" | 실명 고객 | **삭제/익명화** |
| 10 | 섹션 헤딩 (316) | "바이름 청라점이 소희의 첫 매장입니다" | 실명+지역 | **삭제** |
| 11 | 섹션 본문 (317) | "25년 경력의 이아름 원장님" | 실명+경력 | **삭제** |
| 12 | 케이스 박스 (322~338) | "바이름 청라점 / 인천 청라 / 이아름 원장" | 실명 다중 | **익명화** |
| 13 | 가격 섹션 (380) | "현재 바이름 청라점을 포함한..." | 실명 | **삭제** |
| 14 | FAQ 답변 (396, 420) | "퍼플앤트가 세팅하고..." | 운영사 노출 | **수정** |
| 15 | 푸터 (441) | "관리자 페이지" trycloudflare 링크 | 임시 도메인 | **삭제** |
| 16 | 푸터 (443) | "바이름 사례" | 실명 | **삭제** |
| 17 | 푸터 (447) | `hello@soheeproject.example` | placeholder 이메일 | **삭제** |
| 18 | 푸터 (448) | trycloudflare 상담 링크 | 임시 도메인 | **삭제** |
| 19 | 푸터 (452~453) | `/p/terms`, `/p/privacy` 약관 링크 | 미완성 약관 | **임시 정책으로 교체** |
| 20 | 푸터 (457) | "© 2026 소희 프로젝트 · 퍼플앤트 운영" | 운영사 노출 | **수정** |

### 1.2 검증되지 않은 성과 수치

| # | 위치 | 노출 텍스트 | 위험 등급 | 처리 |
|---|------|------------|----------|------|
| 1 | 케이스스터디 컨트롤러 (CASE_STUDIES) | "주간 자동 생성 32건 / 검수 자동 통과 85% / 초안 절감 주 4.5시간" | 검증되지 않은 가상 수치 | **전부 삭제 또는 "검증 중" 표현** |
| 2 | 케이스스터디 컨트롤러 (bookkeeping) | "월간 응대 1,180건 / 자동 처리 62% / 사람 전환 9%" | 검증되지 않은 가상 수치 | **삭제** |

### 1.3 가격 노출

| # | 위치 | 노출 텍스트 | 위험 등급 | 처리 |
|---|------|------------|----------|------|
| 1 | `branding.yml` | `beta_monthly_krw: 300000` / `beta_deposit_krw: 500000` | 가격 노출 | **공개 영역에서 완전 제거** |
| 2 | `app/views/public/pricing/show.html.erb` | "3가지 요금제 / VAT 포함 / 베타 월정액 / 보증금" | 가격 노출 | **전면 삭제** |

### 1.4 권장 처리

- 랜딩을 14섹션 신규 구조로 전면 재작성 (지시서 4장)
- CTA: 모두 `/contact` 또는 `/contact/thanks` (현재 Rails 앱의 자체 폼)로 연결
- 외부 임시 도메인 (trycloudflare / ngrok) 절대 노출 금지

---

## 2. 공개 페이지 (Rails app/views/public/)

### 2.1 `/` (home)

| 항목 | 상태 |
|------|------|
| 컨트롤러 | `Public::HomeController#show` |
| 뷰 | `app/views/public/home/show.html.erb` |
| 노출 위험 | (홈은 대시보드 형태 — 자세한 조사는 home 컨트롤러에서 확인 필요) |

### 2.2 `/about`, `/about/principles`

| 항목 | 상태 |
|------|------|
| 컨트롤러 | `Public::AboutController` |
| 뷰 | `app/views/public/about/` |
| 노출 위험 | 별도 확인 필요 (P0 진행 시 우선순위 낮음) |

### 2.3 `/products/ai-employee` (구 product)

| 항목 | 상태 |
|------|------|
| 컨트롤러 | `Public::AiEmployeeController` |
| 뷰 | `app/views/public/ai_employee/` |
| 노출 위험 | 지시서 4-3 (핵심 해결책) 섹션으로 통합 검토 |

### 2.4 `/case-studies`, `/case-studies/:slug`

| 항목 | 상태 |
|------|------|
| 컨트롤러 | `Public::CaseStudiesController` |
| 슬러그 | `byreum-chungra-2026q3` (실명 추정 가능 — **P0에서 익명화 필수**) |
| 데이터 | 하드코딩된 가상 사례 (검증되지 않은 수치 다수) |
| 처리 권장 | **공개 사이트에서 익명 사례 1건만 (`pilot-beauty-studio-01`) 유지, 나머지 삭제 또는 비공개** |

### 2.5 `/pricing`

| 항목 | 상태 |
|------|------|
| 컨트롤러 | `Public::PricingController#show` |
| 뷰 | `app/views/public/pricing/show.html.erb` |
| 노출 위험 | **가격 3종 / 보증금 / 부가세 — 전면 삭제** |
| 처리 권장 | "가격 정책은 준비 중" 단일 섹션으로 교체, 실제 가격/플랜 정보 완전 제거 |

### 2.6 `/contact` (상담 폼)

| 항목 | 상태 |
|------|------|
| 컨트롤러 | `Public::ContactsController` (new/create/thanks) |
| 뷰 | `app/views/public/contacts/` |
| 노출 위험 | 폼 자체는 양호 — CTA가 trycloudflare로 연결되는 게 문제 |

### 2.7 `/industries` (업종 페이지)

| 항목 | 상태 |
|------|------|
| 컨트롤러 | `Public::IndustriesController` |
| 뷰 | `app/views/public/industries/` |
| 처리 권장 | 지시서 5장에 따라 **공개 내비게이션에서 제거**, 핵심 타깃 6종만 운영자가 내부 참고용으로 유지 |

### 2.8 `/p/:slug` (이용약관/개인정보)

| 항목 | 상태 |
|------|------|
| 컨트롤러 | `Public::PagesController` |
| 노출 위험 | "가칭" 표시, 정식 약관 미완성 |
| 처리 권장 | 미완성 약관/개인정보처리방침은 **실제 서비스 동작과 일치하는 임시 정책**으로 교체 (지시서 21장) |

---

## 3. 로그인 화면 (`/login`)

### 3.1 식별 위험 노출

| # | 위치 | 노출 텍스트 | 위험 등급 | 처리 |
|---|------|------------|----------|------|
| 1 | `user_sessions/new.html.erb:45` | "데모용 dev 로그인은 POST /dev_login/business에 이메일 owner@demo.example로 호출하세요" | **demo 계정 노출 + dev_login 안내** | **즉시 삭제** |
| 2 | 데모 계정 박스 | `owner@demo.example / OwnerPass!23` | demo 계정 노출 | **공개 사이트에서 데모 박스 제거, 로그인 자체는 /login에 단독 배치** |

### 3.2 권장 처리

- 공개 사이트 랜딩에서 "로그인" 메뉴 자체를 **고객용 사장님 영역과 운영자 콘솔 영역으로 분리**
- 사장님 영역 로그인은 **도입 상담 승인 후 사업장 계정 발급 구조**이므로 셀프 노출 불필요
- 운영자 콘솔은 `/login`에 두고 별도 안내(예: "운영자이시면 로그인") 또는 별도 경로(`/console/login`)로 분리 검토

---

## 4. 회원가입 화면 (`/signup`)

### 4.1 식별 위험 노출

| # | 위치 | 노출 텍스트 | 위험 등급 | 처리 |
|---|------|------------|----------|------|
| 1 | `signups/new.html.erb` | "1분 안에 데모 사업장이 생성됩니다" | 셀프 가입 유도 | **P0에서 /contact 로 리다이렉트** |
| 2 | 폼 필드 | 업종 4종 (뷰티/카페/소매/기타) | 광범위 업종 노출 | **/signup 자체 비공개 전환 시 자연 해결** |

### 4.2 권장 처리

- 지시서 5장: "초기 운영 단계에서는 셀프 가입 대신 도입 상담으로 리다이렉트"
- `/signup` → `/contact` 302 리다이렉트
- `SignupsController`는 운영자가 내부적으로 사용하는 용도로 유지(필요 시), 공개 라우트만 차단

---

## 5. 공개 레이아웃 (`app/views/layouts/public.html.erb`)

### 5.1 식별 위험 노출

| # | 위치 | 노출 텍스트 | 위험 등급 | 처리 |
|---|------|------------|----------|------|
| 1 | 헤더 (23) | `<span ...>가칭</span>` 배지 | 미완성 표시 | **삭제** |
| 2 | 푸터 (49) | "개발 환경 안내: 브랜드명/도메인/상표는 가칭 상태입니다. `config/branding.yml`에서 교체하세요" | **개발 환경 노출 + config 파일 경로 노출** | **즉시 삭제** |
| 3 | 푸터 (63) | `brand.brand_provisional ? "(가칭)" : ""` | 가칭 표시 | **brand_provisional 제거** |

---

## 6. 가격/계약 데이터 (DB 시드)

### 6.1 `config/branding.yml`

| 키 | 값 | 노출 위험 | 처리 |
|---|----|----------|------|
| `pricing.beta_monthly_krw` | `300000` | 가격 | **공개 사이트에서 완전 제거, 내부 config에만 유지 (값 자체는 마스킹 또는 삭제 검토)** |
| `pricing.beta_deposit_krw` | `500000` | 보증금 | **공개 사이트에서 완전 제거** |
| `contact_email` | `hello@soheeproject.example` | placeholder 이메일 | **공개 노출 금지, 내부 contact만 보관** |
| `brand_provisional: true` | (development) | 가칭 표시 | **`brand_provisional` 자체를 모델/설정에서 제거** |

### 6.2 `db/seeds.rb`

| # | 라인 (대략) | 내용 | 위험 등급 | 처리 |
|---|------------|------|----------|------|
| 1 | 292 부근 | `owner@demo.example / OwnerPass!23` 출력 | demo 계정 노출 (관리자 콘솔) | **운영자 콘솔 안내에는 유지 가능, 공개 사이트에서는 완전 제거** |
| 2 | (다수) | `byreum-cheongna` 등 실명 슬러그 시드 | 실명 슬러그 | **익명 슬러그 (`pilot-beauty-studio-01`)로 마이그레이션** |

### 6.3 `script/seed_byreum.rb`, `script/seed_byreum_content.rb`

- 바이름/청라/이아름/퍼플앤트/김선영 다수 노출
- **P0에서는 별도 처리하지 않고, P1/P2에서 익명 슬러그로 마이그레이션 시 함께 정리**
- 단, **공개 라우트에서 직접 노출되는 케이스스터디 슬러그는 P0에서 익명화 필수**

---

## 7. 즉시 제거 대상 (P0)

1. `docs/index.html` 전체 재작성 (지시서 4장 14섹션 구조)
2. `app/views/layouts/public.html.erb`의 "가칭", "개발 환경 안내" 완전 삭제
3. `app/views/user_sessions/new.html.erb`의 dev_login 안내 + demo 계정 박스 공개 노출 제거
4. `app/views/public/pricing/show.html.erb` 전면 재작성 (가격/플랜/보증금/부가세 완전 제거)
5. `app/views/public/case_studies/show.html.erb` 슬러그 익명화 + 검증되지 않은 수치 삭제
6. `app/views/signups/new.html.erb` → `/contact` 302 리다이렉트
7. `app/controllers/public/case_studies_controller.rb`의 `byreum-chungra-2026q3` 슬러그 → `pilot-beauty-studio-01`로 변경

## 8. 즉시 차단 대상 (P0)

1. `routes.rb`: `get "/case-studies"` 및 `get "/case-studies/:slug"` 라우트 비활성화 또는 익명화
2. `routes.rb`: `get "/signup"` → `/contact`로 redirect
3. `routes.rb`: `get "/signup"` 후속 `resources :industries` 공개 라우트도 제한

## 9. 검증 방법

```bash
# 공개 영역에서 즉시 노출 검사 (P0 완료 후 모두 0건이어야 함)
for kw in "바이름" "청라" "이아름" "퍼플앤트" "김선영" "byreum" "chungra" \
          "300,000" "500,000" "99,000" "199,000" "450,000" \
          "owner@demo.example" "hello@soheeproject.example" \
          "config/branding.yml" "가칭" "개발 환경 안내" "dev_login" "trycloudflare" \
          "환각 원천 차단"; do
  hits=$(grep -r --include="*.html" --include="*.md" --include="*.yml" --include="*.rb" --include="*.erb" \
         -l "$kw" docs/ app/views/public/ app/views/layouts/public.html.erb app/views/user_sessions/ 2>/dev/null \
         | grep -v node_modules)
  echo "$kw: ${hits:-none}"
done
```