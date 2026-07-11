# Hermes 기능 매트릭스

본 문서는 로컬 환경에 설치된 Hermes의 실제 기능을 정리하고, 본 제품이 의존하는 인터페이스를 정의한다.

## A. 환경 정보 (조사 결과)

- **설치 위치**: `/Users/hochari/.hermes/` (이 제품 디렉토리가 아님)
- **상태**: 별도 데스크탑 에이전트 (Nous Research Hermes)
- **역할**: 본 제품은 Hermes가 아니며, Hermes의 일부가 될 수도 있고, 완전히 다른 시스템일 수도 있다
- **API 모드**: 표준화된 HTTP API 미노출 (조사 시점)

## B. 본 제품의 Hermes 의존성

- `AutomationProvider` 인터페이스 (`app/services/automation_provider.rb`) 만 정의
- **로컬 기본 구현**: `FakeHermesAdapter` — in-process, ActiveJob으로 실행, 가짜 결과 반환
- **실제 Hermes 어댑터 (향후)**: `RealHermesAdapter` — gRPC 또는 HTTPS, 토큰 인증
- **이점**: 본 제품이 Hermes 내부 구현에 묶이지 않음. Hermes가 바뀌어도 인터페이스만 유지되면 됨

## C. AutomationProvider 인터페이스 (계약)

```ruby
class AutomationProvider
  def enqueue_execution(execution)        # 새 실행 등록
  def claim_next(account_id:, worker_id:) # 다음 작업 가져오기
  def heartbeat(execution_id:)            # 실행 임대 갱신
  def complete(execution_id:, output:)    # 성공
  def fail(execution_id:, error:)         # 실패
  def cancel(execution_id:)               # 취소
end
```

## D. Discord 의존성

- **상태**: 첫 실제 연동 대상
- **인터페이스**: `Channel::DiscordAdapter`
- **로컬 기본**: `FakeDiscordAdapter` — 명령/이벤트를 in-memory로 처리, 운영자 화면에 결과 표시
- **필요한 것** (사람 작업): 디스코드 봇 토큰, 서버 ID, 채널 ID 목록, 명령 prefix

## E. 향후 작업

1. `RealHermesAdapter` 구현 (HTTPS, 토큰)
2. `DiscordAdapter` 실제 구현 (discordrb 또는 자체 봇)
3. 자동화 페이로드 스키마를 `docs/api/openapi.yaml` 에 명시
4. 운영 환경에서 `ENV["AUTOMATION_PROVIDER"] = "real_hermes"` 로 전환