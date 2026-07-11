# 개인정보 노출 위험 감사 (Privacy Exposure Audit)

**조사 일자**: 2026-07-11  
**조사 범위**: HTML source / metadata / sitemap / URL slug / seed / placeholder / 메타태그 / 푸터 / OG 태그 / JS 번들 / CSS / asset path / config / fixture / admin 화면 노출 / 디버그 로그

---

## 1. 금지 키워드 노출 (저장소 전수 검색)

### 1.1 검색 결과 (공개 영역 한정)

| 키워드 | docs/ | app/views/public/ | app/views/layouts/public | app/views/user_sessions/ | app/views/signups/ | 기타 |
|--------|-------|-------------------|--------------------------|--------------------------|--------------------|------|
| 바이름 | ✅ docs/index.html | - | - | - | - | ai_employees/index (내부) |
| 청라 | ✅ docs/index.html | case_studies_controller (내부) | - | - | - | - |
| 이아름 | ✅ docs/index.html | - | - | - | - | ai_employees/index (내부) |
| 퍼플앤트 | ✅ docs/index.html (다수) | - | ✅ app.html.erb (내부) | - | - | pages_controller (내부) |
| 김선영 | ✅ docs/index.html | - | - | - | - | - |
| byreum | ✅ docs/index.html | case_studies_controller | - | - | - | dashboards, ai_employees, migrations |
| chungra | - | case_studies_controller | - | - | - | - |
| 청라점 | ✅ docs/index.html | - | - | - | - | ai_employees/index (내부) |
| owner@demo.example | - | - | - | ✅ new.html.erb | - | seed (내부) |
| hello@soheeproject.example | ✅ docs/index.html (메타) | - | - | - | - | branding.yml (config) |
| config/branding.yml | - | - | ✅ public.html.erb | - | - | - |
| 가칭 | - | - | ✅ public.html.erb | - | - | - |
| 개발 환경 안내 | - | - | ✅ public.html.erb | - | - | - |
| dev_login | - | - | - | ✅ new.html.erb | - | routes.rb (내부) |
| trycloudflare | ✅ docs/index.html (다수) | - | - | - | - | development.rb (내부) |
| 300,000 | - | - | - | - | - | branding.yml (config) |
| 500,000 | - | - | - | - | - | branding.yml (config) |
| 99,000 / 199,000 / 450,000 | (저장소에서 발견 안 됨) | - | - | - | - | - |
| 환각 원천 차단 | (저장소에서 발견 안 됨) | - | - | - | - | - |

### 1.2 핵심 발견

1. **`docs/index.html`**: 14개 위험 키워드가 동시 노출되는 핵심 공개 페이지
2. **`app/views/layouts/public.html.erb`**: "가칭" 배지 + "개발 환경 안내" 푸터 + config/branding.yml 경로 노출
3. **`app/views/user_sessions/new.html.erb:45`**: dev_login 안내 + demo 계정 노출
4. **`app/controllers/public/case_studies_controller.rb`**: `byreum-chungra-2026q3` 슬러그 + 검증 안 된 가상 수치 다수
5. **`app/views/public/pricing/show.html.erb`**: 가격/보증금/부가세 노출

---

## 2. 위험 분류 (P0 처리 대상)

### 2.1 즉시 삭제 (공개 영역)

- `docs/index.html` 위험 키워드 14종 → **랜딩 전면 재작성**
- `app/views/layouts/public.html.erb` 가칭/개발환경/config 경로 → **즉시 삭제**
- `app/views/user_sessions/new.html.erb` dev_login 안내 → **즉시 삭제**
- `app/views/public/pricing/show.html.erb` 가격/보증금/부가세 → **즉시 삭제**
- `app/controllers/public/case_studies_controller.rb` byreum-chungra 슬러그 + 가상수치 → **익명화**
- `docs/index.html`의 trycloudflare URL → **전부 삭제**

### 2.2 코드 설정값으로 이동 (개발 환경 노출)

- `config/branding.yml`의 `beta_monthly_krw: 300000` / `beta_deposit_krw: 500000` → **공개 노출 차단** (값 자체는 내부 config에 유지, 화면/HTML에서만 마스킹)
- `hello@soheeproject.example` → **공개 화면 노출 제거, 운영 콘솔/연락처용으로만 사용**

### 2.3 테스트 fixture에서 가명으로 교체

- `script/seed_byreum.rb`, `script/seed_byreum_content.rb`, `db/seeds.rb` → 별도 처리 (P2에서 익명 마이그레이션, P0에서는 시드 실행 결과만 정리)

### 2.4 완전 삭제

- `case_studies#show`의 `bookkeeping-solo-2026q3` (가상 사례이지만 검증 안 된 수치 다수) → **삭제 또는 익명화**
- `case_studies#show`의 모든 metrics 필드 → **삭제 또는 "검증 중" 표현**

---

## 3. 메타데이터 / Sitemap / robots.txt 검사

### 3.1 메타 태그 (`docs/index.html`)

| 라인 | 메타 | 위험 노출 |
|------|------|----------|
| 7 | `<meta name="description">` | "퍼플앤트가 세팅하고" (운영사) |
| 8 | `<meta property="og:title">` | 무해 |
| 9 | `<meta property="og:description">` | "바이름 청라점이 첫 파트너" (실명) |
| (확인필요) | og:image / twitter:card | (없음 — OK) |

### 3.2 Sitemap / robots

- `docs/` 폴더에 `sitemap.xml`, `robots.txt` 없음 (확인 필요 — GitHub Pages 기본 robots 사용)

### 3.3 GitHub Pages 정적 사이트 특성

- `docs/index.html` 단일 파일 = 모든 메타가 노출됨
- 메타 description이 소셜 공유 시 그대로 노출되므로 **P0에서 가장 먼저 수정**

---

## 4. URL slug 검사

### 4.1 공개 라우트 slug

| 라우트 | 위험 | 처리 |
|--------|------|------|
| `/` (public_root) | 무해 | - |
| `/about`, `/about/principles` | 무해 | - |
| `/products/ai-employee` | 무해 | - |
| `/case-studies` | 무해 | - |
| `/case-studies/:slug` | **`byreum-chungra-2026q3`** (실명+지역 추정) | **익명 슬러그로 교체** |
| `/case-studies/:slug` | `bookkeeping-solo-2026q3` | **삭제 또는 별도 폴더** |
| `/pricing` | 무해 (단, 가격 페이지 자체는 노출 위험) | **전면 재작성** |
| `/p/:slug` | 약관/개인정보 페이지 - 미완성 | **임시 정책으로 교체** |
| `/contact`, `/contact/thanks` | 무해 | - |
| `/industries` | 업종 4종 (스킨케어/카페/소매/기타) | **공개 내비에서 제거** |
| `/signup` | 셀프 가입 노출 | **`/contact`로 302 리다이렉트** |
| `/login` | dev_login 안내 노출 | **즉시 삭제** |

### 4.2 식별 가능한 slug 일람

| slug | 식별 가능성 | 처리 |
|------|----------|------|
| `byreum-chungra-2026q3` | 바이름+청라 + 분기 | **삭제 또는 `pilot-beauty-studio-01`** |
| `byreum-cheongna` (account slug, 시드) | 바이름+청라 | **P2에서 익명 슬러그 마이그레이션** |
| `bookkeeping-solo-2026q3` | (저위험, 단 가상 수치 다수) | **삭제** |

---

## 5. 디버그 / 로그 / HTML source 검사

### 5.1 HTML 주석

- (별도 점검 필요 - P0 진행 시 발견되는 대로)

### 5.2 production log 노출

- `log/production.log` - GitHub Pages에는 없음
- Rails 앱 production 환경 로그 - 외부 노출 없음

### 5.3 콘솔 로그 / 디버그 출력

- `rails console` 등 운영 콘솔은 내부 전용 (공개 사이트와 무관)

---

## 6. 권한 분리 검토

### 6.1 현재

- `app/controllers/app/base_controller.rb` - 사업자 영역 (로그인 필수)
- `app/controllers/platform/base_controller.rb` - 운영자 영역 (platform_staff 로그인 필수)
- `app/controllers/public/base_controller.rb` - 공개 (인증 불필요)

### 6.2 신규 지시서 (19장 - 보안)

- ✅ 역할 기반 권한 (현재 충족)
- ⚠️ 공식 계정 자격증명 암호화 (현재 미흡 - `ApiToken`은 존재하나 화면 노출 검토 필요)
- ✅ 감사 로그 (`AuditEvent` 존재)
- ⚠️ PII 자동 감지 (신규)
- ⚠️ 화면 마스킹 (현재 일부만)
- ✅ 데이터 보관 기간 / 삭제 (DeletionRequest 존재)
- ⚠️ 테스트와 공식 환경 분리 (Channel env enum 필요)

---

## 7. 노출 위험도 매트릭스

| 항목 | 공개 노출 위험 | 내부 노출 위험 | 처리 |
|------|--------------|--------------|------|
| 바이름/청라/이아름/김선영 | 🟥 HIGH | 🟧 MED | P0: 즉시 익명화 |
| 퍼플앤트 | 🟧 MED (랜딩 메타/푸터) | 🟨 LOW | P0: 운영사 이름 노출 정리 |
| 가격 (300,000/500,000) | 🟥 HIGH (pricing 페이지) | 🟨 LOW (config) | P0: 가격 페이지 전면 삭제 |
| 검증 안 된 수치 (32건/85%/주4.5시간) | 🟥 HIGH | 🟧 MED | P0: 케이스스터디 전면 정리 |
| demo 계정 (owner@demo.example) | 🟥 HIGH (로그인 화면) | 🟨 LOW (시드/문서) | P0: 로그인 화면에서 노출 제거 |
| trycloudflare URL | 🟥 HIGH (랜딩 다수) | 🟨 LOW (config) | P0: 랜딩 전면 삭제 |
| dev_login 안내 | 🟥 HIGH (로그인 화면) | 🟨 LOW (routes) | P0: 공개 화면에서 즉시 삭제 |
| "가칭" / "개발 환경 안내" | 🟥 HIGH (public 레이아웃) | - | P0: 즉시 삭제 |
| placeholder 이메일 (hello@...) | 🟧 MED (랜딩 메타/푸터) | 🟨 LOW (config) | P0: 공개 노출 제거 |
| 환각 원천 차단 표현 | (저장소에서 발견 안 됨 - 신규 페이지 작성 시 주의) | - | 신규 작성 시 사용 금지 |
| 사업장 주소/영업시간/가격표 | - | 🟧 MED (BusinessProfile) | 내부용 - P2에서 마스킹 옵션 검토 |

---

## 8. 익명화 권장 매핑

| 실 데이터 | 익명 대체 |
|----------|---------|
| 바이름 청라점 | "1인 뷰티샵 파일럿" 또는 "초기 파트너 A" |
| 인천 청라 | "수도권" 또는 삭제 |
| 25년 경력 | (삭제 - 검증 안 됨) |
| 이아름 원장 | (삭제) |
| 김선영 님 | "고객 A" 또는 "문의 #1042" |
| byreum-chungra-2026q3 | pilot-beauty-studio-01 |
| 퍼플앤트 운영 | "소희 프로젝트 운영" 또는 "AI 직원 운영사" |
| hello@soheeproject.example | (공개 노출 금지) |
| owner@demo.example / OwnerPass!23 | 공개 화면 노출 금지 (운영 콘솔/문서에서만 사용) |

---

## 9. 검증 자동화 (P0 완료 후)

```bash
#!/bin/bash
# audit/scripts/check_privacy_exposure.sh
# P0 처리 후 모두 0이어야 통과

set -e
FAIL=0

check() {
  local kw="$1"
  local paths="$2"
  local hits=$(grep -r --include="*.html" --include="*.md" --include="*.yml" --include="*.rb" --include="*.erb" -l "$kw" $paths 2>/dev/null | grep -v node_modules | grep -v .git | grep -v audit | head)
  if [ -n "$hits" ]; then
    echo "❌ [$kw]"
    echo "$hits" | sed 's/^/   /'
    FAIL=$((FAIL+1))
  fi
}

PUBLIC_PATHS="docs/ app/views/public/ app/views/layouts/public.html.erb app/views/user_sessions/ app/views/signups/"

for kw in "바이름" "청라" "이아름" "퍼플앤트" "김선영" "byreum" "chungra" \
          "300,000" "500,000" "99,000" "199,000" "450,000" \
          "owner@demo.example" "hello@soheeproject.example" \
          "config/branding.yml" "가칭" "개발 환경 안내" "dev_login" "trycloudflare" \
          "환각 원천 차단"; do
  check "$kw" "$PUBLIC_PATHS"
done

if [ $FAIL -eq 0 ]; then
  echo "✅ 모든 공개 영역 위험 키워드 0건 — P0 통과"
  exit 0
else
  echo "❌ $FAIL건 카테고리에서 위험 노출 발견 — P0 미통과"
  exit 1
fi
```

---

## 10. 다음 액션

1. **즉시 (P0)**: 위에 명시된 모든 항목 처리
2. **검증**: 위 9장의 자동화 스크립트로 검증
3. **추후 (P2)**: 바이름 시드의 account slug 익명 마이그레이션 (`byreum-cheongna` → `pilot-beauty-studio-01`)