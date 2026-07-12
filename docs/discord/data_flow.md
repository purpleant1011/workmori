# Discord-Native 확장 — 데이터 흐름 (3단계)

> 기준: `architecture.md` (2단계)
> 모든 흐름은 **변경 제안 → 확인 → 적용** 원칙을 따른다.

---

## 1. 일반 대화 (casual_chat)

```
[Discord #소희-대화]
  사업자: "오늘 하루 어땠어?"
     │
     ▼
[A. Discord Gateway]  event_handler.ts
     │  ① 메시지 수신
     │  ② typing 표시
     │  ③ POST /api/v1/discord/events (Bearer)
     ▼
[B. Rails Control Plane]  DiscordEventsController#create
     │  ① 멱등 키 검사 (idempotency_key 중복 시 200 즉시 응답)
     │  ② DiscordIdentity 권한 검증
     │  ③ ConversationSession 열기/이어가기
     │  ④ DiscordMessageEvent 저장 (raw_payload_encrypted)
     │  ⑤ Message 저장 (direction: inbound, author_kind: customer)
     │  ⑥ Enqueue: GenerateDiscordReplyJob
     │  → 200 OK
     ▼
[Job] GenerateDiscordReplyJob (Solid Queue)
     │  ① ConversationSession 컨텍스트 로딩
     │  ② context_type = "owner_conversation_context"
     │  ③ Enqueue: GeminiConversationService.call(task="converse")
     ▼
[C. Gemini Conversation Service]
     │  ① GeminiApiProvider.converse()
     │  ② model: gemini-3.5-flash, thinking: low
     │  ③ 응답 텍스트 반환
     ▼
[Job] (이어서) GenerateDiscordReplyJob
     │  ① Outbound 큐 적재: discord_outbound_jobs.insert(
     │     kind: "message", target_channel_id, payload: { content })
     │  ② AuditEvent 기록 (actor_kind: ai, action: discord.reply.queued)
     ▼
[A. Discord Gateway]  outbound_worker.ts
     │  ① GET /api/v1/discord/outbound?since=... (30초 간격)
     │  ② Discord channel.sendMessage(content)
     │  ③ POST /api/v1/discord/outbound/:id/ack
     ▼
[Discord #소희-대화]
  소희: "오늘도 콘텐츠 3건 발행 완료했습니다. 질문 있으신가요?"
```

**DB 변경**: 없음 (대화 로그만)
**Runtime 변경**: 없음

---

## 2. 영구 변경 (brand_preference / operating_rule)

```
[Discord #소희-대화]
  사업자: "영업시간을 10시~22시로 바꿔줘. 토요일은 12시부터."
     │
     ▼
[A] → [B] (위와 동일, EventType: MESSAGE_CREATE)
     │
[B] DiscordEventsController → DiscordMessageEvent 저장
     │  Enqueue: GenerateDiscordReplyJob + ExtractChangeProposalJob
     ▼
[Job] ExtractChangeProposalJob
     │  ① 컨텍스트 로딩 (active Runtime, brand_rules, business_profile)
     │  ② Enqueue: Gemini.extract_change(task="extract_change")
     ▼
[C] Gemini.extract_change()
     │  Output (strict JSON):
     │  {
     │    "change_type": "business_hours",
     │    "current_value": { "mon~fri": "09:00~21:00", "sat": "10:00~20:00" },
     │    "proposed_value": { "mon~fri": "10:00~22:00", "sat": "12:00~22:00" },
     │    "reason": "...",
     │    "confidence": 0.92,
     │    "risk_level": "low",
     │    "effective_from": "2026-07-13",
     │    "expires_at": null,
     │    "is_one_time": false
     │  }
     ▼
[Job] ExtractChangeProposalJob (이어서)
     │  ① ChangeProposal INSERT (status: pending)
     │  ② Enqueue: GenerateDiscordReplyJob (변경 카드 메시지)
     ▼
[Job] GenerateDiscordReplyJob → Outbound 적재
     │  payload: { kind: "approval_card", change_proposal_id: 42,
     │             embed: { 변경 항목 / 기존 값 / 새 값 / 적용 시점 / 영향 채널 / 위험도 },
     │             buttons: ["적용", "수정", "이번만", "운영팀 검토", "취소"] }
     ▼
[A] outbound_worker → Discord 메시지 전송 (Embed + Buttons)
     │
[Discord #확인-승인 채널]  카드 표시
     │
[사업자] "적용" 버튼 클릭
     │
     ▼
[A] interaction_handler → POST /api/v1/discord/interactions
     ▼
[B] DiscordInteractionsController#create
     │  ① ChangeProposal.status = approved
     │  ② ChangeApproval INSERT (decision: apply)
     │  ③ Rails transaction:
     │    - BusinessProfile.update!(business_hours_json: ...)
     │    - AuditEvent(action: business_profile.changed)
     │    - RuntimeConfig.create!(status: draft, bundle_json: snapshot_v2_for(account))
     │    - RuntimeConfig.new.activate!(by_user)
     │      (기존 active → archived, 신규 active로 승격)
     │  ④ Enqueue: DispatchHermesJob (RuntimeConfig 동기화)
     │  ⑤ Outbound: Discord 적용 완료 메시지 큐
     │  → 200 OK (Interaction ACK)
     ▼
[Job] DispatchHermesJob
     │  ① POST Hermes MCP: notify_runtime_change (account_id, runtime_config_id)
     │  ② RuntimeSync INSERT (status: pending)
     │  ③ Hermes ACK 수신 → RuntimeSync.status = acknowledged
     │  ④ ACK 실패 → 3회 재시도, 실패 시 Incident 생성
     ▼
[Discord #확인-승인 채널]
  소희: "✅ 영업시간이 업데이트되었습니다. 새 영업시간으로 즉시 응답합니다."
```

**DB 변경**: `business_profiles`, `change_proposals`, `change_approvals`, `runtime_configs`, `runtime_syncs`, `audit_events`
**Runtime 변경**: draft → active 승격 (이전 active는 archived)

---

## 3. 일회성 작업 (one_time_task)

```
[Discord #소희-대화]
  사업자: "오늘 6시에 신메뉴 카드뉴스 하나만 발행해줘. 주제는 딸기라떼."
     │
     ▼
[A] → [B] (EventType: MESSAGE_CREATE)
     │
[B] DiscordMessageEvent 저장 → Enqueue: ExtractChangeProposalJob + GenerateDiscordReplyJob
     │
[C] Gemini.extract_change() → ChangeProposal
     │  { change_type: "one_time_post",
     │    proposed_value: { kind: "cardnews", topic: "딸기라떼", scheduled_at: "18:00" },
     │    is_one_time: true, expires_at: "2026-07-12T19:00:00+09:00",
     │    confidence: 0.85, risk_level: "low" }
     │
[B] ChangeProposal INSERT (status: pending, is_one_time: true)
     │  Outbound: Discord 카드 (영구 변경이 아님 명시)
     │
[Discord #확인-승인 채널]
  사업자: "이번만" 버튼 클릭 (영구 저장 X)
     │
[B] DiscordInteractionsController
     │  ① ChangeApproval INSERT (decision: one_time_apply)
     │  ② RuntimeConfig는 변경하지 않음 (영구 규칙 X)
     │  ③ AutomationExecution INSERT (kind: one_time, scheduled_at: 18:00)
     │  ④ Enqueue: DispatchHermesJob (job claim)
     │  ⑤ AuditEvent 기록
     │
[시간 경과: 18:00]
[Job] AutomationExecution.tick
     │  ① ContentItem 초안 생성 (Gemini.generate_content)
     │  ② Discord 검수 카드
     │  ③ 발행 승인 후 Hermes 호출
```

**DB 변경**: `change_proposals`, `change_approvals`, `automation_executions`, `audit_events`
**Runtime 변경**: 없음 (영구 X)

---

## 4. 민감 문의 인계 (sensitive_data / escalation)

```
[Discord #소희-대화 또는 DM]
  손님(고객 응대): "어제 시술하고 알레르기 생겼는데 환불 되나요?"
     │
     ▼
[B] (DM은 별도 ConversationSession으로)
     │  Message 저장 (author_kind: customer, channel_kind: dm)
     │  Enqueue: ClassifyInquiryJob
     ▼
[C] Gemini.classify_inquiry()
     │  { category: "refund", risk: "high", needs_human: true,
     │    topic: "medical_adverse_event" }
     ▼
[B] Handoff INSERT (state: open, priority: high, reason: medical_adverse_event)
     │  Outbound: Discord #문의-인계 채널에 알림
     │  Discord DM에는 "곧 담당자가 연결됩니다" 자동 응답
     │  AuditEvent 기록
     ▼
[운영팀 콘솔 / Discord #문의-인계]
  운영자가 직접 응대
```

**DB 변경**: `handoffs`, `audit_events`, `conversations`(state=escalated)
**Runtime 변경**: 없음

---

## 5. 캠페인 (temporary_campaign)

```
[Discord #소희-대화]
  사업자: "다음 주 추석 연휴 캠페인 시작하자. 9월 25일부터 28일까지, 전 메뉴 20% 할인."
     │
     ▼
[B] ExtractChangeProposalJob → ChangeProposal
     │  { change_type: "temporary_campaign",
     │    proposed_value: { name: "추석 캠페인", discount: "20%",
     │                       starts_at: "2026-09-25", ends_at: "2026-09-28" },
     │    effective_from: "2026-09-25", expires_at: "2026-09-29",
     │    is_one_time: false (but temporary), risk_level: "medium" }
     │
[Discord #확인-승인 채널]  카드 (만료일 명시)
  사업자: "적용"
     │
[B] ChangeApproval + RuntimeConfig Draft 생성
     │  RuntimeConfig.bundle_json.temporary_campaigns[] 에 추가
     │  RuntimeConfig.bundle_json.effective_at = "2026-09-25"
     │  expires_at 자동 설정 (만료 시 자동 비활성)
     │
[2026-09-29 00:00 야간 Reconciliation]
     │  만료된 캠페인 자동 제거
     │  RuntimeConfig 새 Draft 생성 (캠페인 제외 버전)
     │  활성화 + Hermes 동기화
     │  Discord #일일보고 채널에 보고
```

**DB 변경**: `runtime_configs` (캠페인 in/out), `audit_events`, `change_proposals`, `change_approvals`
**Runtime 변경**: 캠페인 추가 → 캠페인 제거 자동

---

## 6. 정합성 점검 (야간)

```
[launchd / cron]  매일 03:00 KST
     ▼
[Job] ReconcileDiscordMessagesJob
     │  ① DiscordMessageEvent 중 processed_at IS NULL AND occurred_at < 24h → 재처리 큐
     │  ② ChangeProposal status='pending' AND created_at < 48h → 만료 처리 + 알림
     │  ③ RuntimeConfig.temporary_campaigns[] 중 expires_at < NOW → 비활성 Draft 생성
     │  ④ RuntimeConfig.active 의 bundle_json.checksum != snapshot.checksum → 알림
     │  ⑤ RuntimeSync.status='pending' AND sent_at < 1h → 재시도 큐
     │  ⑥ AuditEvent.action = 'automation.execution.failed' GROUP BY account → 운영팀 Discord 보고
     │
[Discord 운영팀 채널]  종합 보고
```

---

## 7. 메시지 수정/삭제 (Discord)

```
[A] MESSAGE_UPDATE / MESSAGE_DELETE 수신
     │
[B] DiscordMessageEvent UPDATE (edited=true) 또는 처리 마킹 (deleted=true)
     │  원본 메시지는 AuditEvent에 보존 (raw_payload_encrypted)
     │  ConversationSession.summary 재계산 트리거
```

---

## 8. 긴급 중지

```
[Discord #소희-대화]
  사업자: "/소희 멈춤"
     │
[A] slash command handler → POST /api/v1/discord/interactions
     ▼
[B] DiscordInteractionsController
     │  ① AuditEvent(action: discord.emergency_stop)
     │  ② Account.feature_flags["emergency_stop"] = true (또는 별도 컬럼)
     │  ③ AutomationRule 중 status='active' 전부 일시정지
     │  ④ 실행 중 작업 cancel 시도
     │  ⑤ SNS 게시 보류
     │  ⑥ 댓글/DM 자동응답 off
     │  ⑦ Outbound: Discord 확인 메시지
     ▼
[Hermes]  다음 claim_job 시 emergency_stop flag 확인 → 작업 skip
```

---

## 시퀀스 다이어그램 요약

```
Discord ─→ Gateway ─→ Rails ─→ Gemini
                          │
                          ├──→ ChangeProposal → 승인 카드 → 적용
                          │                       │
                          │                       └─→ RuntimeConfig → Hermes Sync
                          │
                          ├──→ Content Draft → 검수 → 발행
                          │
                          └──→ Inquiry 분류 → Handoff → 운영팀

야간: Reconciliation Job → Discord 보고
```

---

다음 단계: `security_model.md` — 위협 모델 + 메시지 신뢰 + 권한 + Secret 관리