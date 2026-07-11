# Workmori(가칭)

> **사장님의 일을 기억하고 스스로 이어가는 AI 직원**
> **가칭 상태** — 도메인·상표 미확정.

소상공인 사장님이 홍보와 마케팅을 담당하는 **가상 AI 직원**을 고용하고,
웹 관리자 페이지에서 그 직원의 **성격, 지식, 업무 범위, 일정, 채널, 승인 방식, 비용 한도**를
설정할 수 있는 **다중 고객형 SaaS**.

---

## 빠른 시작

### 1) 의존성
```bash
bundle install
npm install
```

### 2) DB
```bash
cp .env.example .env
# PGPORT=5432, PGUSER=$(whoami) 등 환경에 맞게 조정
bin/rails db:create db:migrate db:seed
bin/rails runner bin/seed_full.rb  # 풀 시드 (다중 사업장 + 채널 + 계약 + 데이터)
```

### 3) 실행

#### 개발 (Rails web + Solid Queue worker 동시)
```bash
bin/dev
# 또는
foreman start -f Procfile.dev
```

#### Mac mini 24/7 운영 (launchd)
```bash
# plist 설치
cp com.workmori.web.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.workmori.web.plist

# 상태 확인
launchctl list | grep workmori
```

### 4) 접속
- **Rails 웹**: http://127.0.0.1:3001
- **데모 사업자**: `owner@demo.example` / 비밀번호 자유 / `POST /dev_login/business`
- **데모 운영자**: `ops@workmori.example` / `POST /dev_login/platform`

---

## 환경

| 항목 | 버전 |
|------|------|
| Ruby | 3.4.10 (mise) |
| Rails | 8.0.5 |
| PostgreSQL | 16 (포트 5432) |
| Node | 22 |
| Tailwind CSS | 3 |
| Solid Queue | (Rails 8 내장) |
| Playwright (워커) | Node.js 22 |

---

## 디렉토리 구조

```
app/
├── controllers/         # 컨트롤러
│   ├── app/             # 사업자 영역 (/app/*)
│   ├── platform/        # 운영자 영역 (/platform/*)
│   └── public/          # 공개 영역 (마이크로사이트)
├── models/              # ActiveRecord 모델 (~30개)
├── services/            # 도메인 서비스 (~25개)
├── jobs/                # ActiveJob 워커
├── views/               # ERB 템플릿
└── javascript/          # importmap + Stimulus

workers/                 # Hermes 실행 어댑터 (MVP: in-process Fake)
script/                  # 검증·유틸 스크립트 (~14개 verify_*.rb)
bin/                     # Rails + dev 도구
storage/                 # 업로드 + 데이터 익스포트 파일
tmp/                     # 로그 + pid
docs/                    # 제품/운영 문서

config/
├── database.yml         # PG 설정 (env 기반)
├── routes.rb            # ~272 routes
└── credentials.yml.enc  # 암호화 비밀번호
```

---

## 도메인 모듈

모듈은 `app/models/<module>/` 또는 단일 모델로 구성:

- **Identity** — User, Session, MagicLinkRequest, PlatformStaff, PlatformSession
- **Tenancy** — Account (multi-tenant 격리)
- **BusinessProfiles** — 사업장 정보 + 브랜드 톤
- **AiEmployees** — 가상 직원 설정 + 역할 + 검수 규칙
- **Knowledge** — Product, Service, Faq, KnowledgeSource, KnowledgeDocument
- **ContentStudio** — ContentItem, ContentVersion, PublicationAttempt
- **Conversations** — Conversation, Message, CsatResponse
- **Channels** — ChannelConnection (mock: 5종 시드)
- **AiGateway** — HermeService (in-process MVP 어댑터)
- **Billing** — Plan, Subscription, Invoice, Payment, ContractTerm
- **Referrals** — 추천 코드
- **Terminations** — 계약 종료/환불
- **AdminOps** — 운영자 검수 큐
- **Audit** — AuditEvent, DeliveryLog
- **Reporting** — 주간/월간 리포트
- **DataExport** — 백업/익스포트 (CSV/JSONB)

---

## 핵심 가치/금지

코드/시드에 강제:

- **과대 광고·허위 사실** 자동 차단 (예: "100%", "완치", "무부작용", "전후사진 100%")
- **시술 후 안전 보장** 표현 금지
- **의료/법률/금융** 민감 문의는 사람 상담 안내
- **자단연/연쇄 추천** 금지
- **할인 정책** (병의원, 일반소매업) 금지
- **허위 후기·리뷰 조작** 금지
- **성과 보장** 금지

---

## 라우트 (총 ~272개)

### 공개 (/)
- `/` — 랜딩
- `/pricing` — 요금제
- `/contact` — 문의
- `/legal/*` — 이용약관/개인정보/환불
- `/users/sign_in`, `/users/sign_up` — 사용자 인증
- `/platform/sign_in`, `/platform/sign_up` — 운영자 인증

### 사업자 (/app)
- `/app` — 대시보드
- `/app/profile`, `/app/ai_employees` — 사업장 설정
- `/app/products`, `/app/services`, `/app/faqs`, `/app/knowledge` — 지식
- `/app/contents` — 콘텐츠
- `/app/schedule` — 주간 일정
- `/app/channels` — 채널
- `/app/conversations` — 대화
- `/app/reports` — 리포트
- `/app/billing` — 결제
- `/app/data_exports` — 백업

### 운영자 (/platform)
- `/platform` — 운영자 대시보드
- `/platform/accounts`, `/platform/inquiries` — 고객/문의
- `/platform/billings`, `/platform/plans` — 결제/요금제

### API (예약)
- `/magic_link` — 매직 링크
- `/dev_login/business`, `/dev_login/platform` — 개발 로그인

---

## 데이터 백업/복구

### 백업
- **UI**: `/app/data_exports` → [새 내보내기 요청]
- **CLI**: `bin/rails runner script/export_data.rb <account_id>`

### 형식
- `json` — 단일 JSON 파일 (구조 보존, import 가능)
- `csv` — zip 안에 테이블별 CSV
- `zip` — data.json + csv/ 폴더

### 보관
- 파일 위치: `storage/exports/account_<id>/`
- 보관 기간: **30일** (변경 가능)
- 정리 워커: `DataExportRetention` 매일 실행 (cron/launchd)

### 복구
```bash
bin/rails runner "DataExportImporter.call(path: 'storage/exports/.../export.json')"
```

---

## 검증 (regression)

각 todo 별 verify 스크립트:

```bash
bin/rails runner script/verify_todo6.rb   # 공개 사이트
bin/rails runner script/verify_todo7.rb   # 인증
bin/rails runner script/verify_todo8.rb   # 사업자 흐름
bin/rails runner script/verify_todo9.rb   # 일정/콘텐츠
bin/rails runner script/verify_todo10.rb  # 결제
bin/rails runner script/verify_todo11.rb  # 채널/CSAT
bin/rails runner script/verify_todo12.rb  # 백업
bin/rails runner script/verify_todo13.rb  # 사용자 매뉴얼 + README + plist + 시드
bin/rails runner script/verify_todo14.rb  # e2e 회귀
```

---

## 운영

### launchd (Mac mini 24/7)

`com.workmori.web.plist` 가 설치되어 있으면 자동으로:
- 시스템 부팅 시 시작
- 죽으면 자동 재시작 (KeepAlive)
- 로그는 `~/Library/Logs/workmori/*.log`

수동:
```bash
launchctl load ~/Library/LaunchAgents/com.workmori.web.plist
launchctl unload ~/Library/LaunchAgents/com.workmori.web.plist
launchctl start com.workmori.web
launchctl stop com.workmori.web
```

### 데이터베이스 백업 (cron)
```bash
# 매일 새벽 3시
0 3 * * * pg_dump workmori_production > ~/backups/workmori_$(date +\%Y\%m\%d).sql
```

### 로그 로테이션
- `tmp/srv*.log` — puma 로그
- `log/*.log` — Rails 로그
- `~/Library/Logs/workmori/*.log` — launchd 로그

---

## 문서

- `docs/product-requirements.md` — PRD
- `docs/architecture.md` — 아키텍처
- `docs/erd.md` — ERD 요약
- `docs/assumptions.md` — 가정
- `docs/hermes-capability-matrix.md` — Hermes 인터페이스
- `docs/security-threat-model.md` — 위협 모델
- `docs/legal-review-checklist.md` — 법무 검토 체크리스트
- `docs/operations-runbook.md` — 운영 매뉴얼
- `docs/backup-restore-runbook.md` — 백업/복구
- `docs/incident-response.md` — 장애 대응
- `docs/deployment.md` — 배포
- `docs/testing.md` — 테스트
- `docs/api/openapi.yaml` — API 명세
- `USER_GUIDE.md` — **사업자용 사용자 가이드**
- `BLOCKED_BY_HUMAN.md` — 사람 작업 필요 목록

---

## 라이선스

비공개. 퍼플앤트 내부 자산.
© 2026 Workmori. All rights reserved.