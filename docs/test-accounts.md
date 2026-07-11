# 테스트 계정 가이드 (내부 전용)

> ⚠️ **이 문서는 운영 보안용 문서입니다. 로그인 페이지·랜딩 페이지·공개 README에는 절대 노출하지 마세요.**

운영/QA/내부 시연에서 사용할 수 있는 계정 모음. **실제 가입 시점의 비밀번호**를 기록해 두면 회귀 테스트와 디버깅이 빨라집니다.

---

## 1. 데모 사업자 (소희 데모)

| 항목 | 값 |
| --- | --- |
| 사업장 슬러그 | `demo-skincare` |
| 사업장 종류 | skincare/beauty (IndustryTemplate 시드) |
| 사용자 이메일 | `owner@demo.example` |
| 비밀번호 | `OwnerPass!23` |
| 역할 | Owner |
| 로그인 URL | `/app/login` |
| 로그인 ID 필드 | 이메일(`owner@demo.example`) **또는** 슬러그(`demo-skincare`) 둘 다 가능 |
| Trial 상태 | 없음 (정식 사업자 시드) |
| 빠른 로그인 (dev) | `POST /dev_login/business` |

비밀번호는 `db/seeds.rb` line 345 기준. 시드 재생성 후에도 동일.

---

## 2. 바이름 (byreum) 전용 사업자

| 항목 | 값 |
| --- | --- |
| 사업장 슬러그 | `byreum` |
| 사업장 종류 | skincare/beauty (바이름 매장 컨셉) |
| 사용자 이메일 | `byreum@soheeproject.example` |
| 비밀번호 | `pass1234!!` |
| 역할 | Owner |
| 로그인 URL | `/app/login` |
| Trial 상태 | 없음 (정식 사업자) |
| 빠른 로그인 (dev) | `POST /dev_login/business` (사업자명 `byreum` 매칭) |
| 비고 | 비밀번호 변경 후 회귀 테스트가 깨질 수 있음. 변경 시 본 문서 + `db/seeds.rb` line 110–111 함께 갱신. |

비밀번호 원복 1-liner:

```bash
bin/rails runner '
u = User.find_by(email_address: "byreum@soheeproject.example")
u.update!(password: "pass1234!!", password_confirmation: "pass1234!!")
puts u.authenticate("pass1234!!") ? "OK" : "FAIL"
'
```

---

## 3. 플랫폼 운영진

| 이메일 | 비밀번호 | 역할 |
| --- | --- | --- |
| `platform-admin@workmori.example` | `SuperSecret!23` | platform-admin |
| `ops@workmori.example` | `OpsPass!23` | platform-ops |

로그인: `/platform/session/new` (운영 콘솔).

---

## 4. E2E/통합 테스트에서 자동 생성되는 계정

Playwright 스펙이 그때그때 생성하는 임시 계정들. Trial 활성/만료 시나리오 검증용.

| 이메일 패턴 | 상태 | 비고 |
| --- | --- | --- |
| `test-<timestamp>@studio.example` | on_trial 14일 | 신규 셀프 가입 시뮬레이션 |
| `test-<timestamp>@studio.example` | trial 만료 | 만료 후 `/app/plans` 강제 이동 검증 |

비번은 Playwright 스펙마다 별도 생성. 정리:

```bash
bin/rails runner '
Account.where("slug LIKE ? OR slug LIKE ?", "e2e-%", "test-%").find_each do |a|
  a.users.find_each(&:destroy)
  a.destroy
end
puts "정리 완료"
'
```

---

## 5. 빠른 로그인 도우미 (development only)

개발 환경에서 비밀번호 입력 없이 사업자/플랫폼 콘솔로 진입:

```bash
# 사업자 콘솔 (바이름 데모 계정으로)
curl -X POST http://127.0.0.1:3001/dev_login/business

# 플랫폼 운영 콘솔
curl -X POST http://127.0.0.1:3001/dev_login/platform

# rate-limit 캐시 초기화 (E2E 반복 실행 시)
curl -X POST http://127.0.0.1:3001/dev_login/clear_rate_limit
```

`/dev_login/*` 라우트는 `Rails.env.production?` 환경에서 403으로 차단됩니다 (`DevOverridesController`).

---

## 6. 비밀번호 변경 후 체크리스트

1. `db/seeds.rb` line 110–111(바이름) 또는 line 345(데모) 갱신
2. 본 문서(`docs/test-accounts.md`) 갱신
3. 회귀 테스트 `e2e/byreum-account.spec.ts` 재실행 → 통과 확인
4. (해당 시) CSRF/form_with 변경 영향 확인 — form_with method: :patch는 폼마다 별도 토큰 발행

---

마지막 갱신: 2026-07-12