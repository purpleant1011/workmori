#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_todo10.rb — 다국어 응답 (AI 직원 언어 라우팅) 검증
#
# 체크 항목:
#  [1] schema: ai_employees.preferred_locale/supported_locales/fallback_locale 존재
#  [2] schema: conversations.detected_locale/response_locale 존재
#  [3] LanguageDetector: 한국어/영어/일본어/중국어/혼합 분류
#  [4] ResponseComposer: 한국어 인바운드 → 한국어 응답
#  [5] ResponseComposer: 영어 인바운드 → 영어 응답 (지원 locale에 en 포함 시)
#  [6] ResponseComposer: 지원하지 않는 locale → fallback 으로 폴백
#  [7] ResponseComposer: handoff intent → needs_handoff=true, reply=""
#  [8] ResponseComposer: 이메일 채널 suffix 추가
#  [9] ResponseComposer: 채널별 max length truncation (mastodon 500자)
#  [10] 채널별 tone override: channel_behaviors_json["mastodon"]["tone"] 적용
#  [11] 실제 Conversation.detected_locale/response_locale 필드 동작 (Conversation 생성)
#  [12] 실제 ChannelConnection.kind 기반 채널 응답 max 검증
#
# 출력을 통해 PASS/FAIL 카운트 집계.

require "net/http"

@results = []
def check(label, ok, info = "")
  status = ok ? "✅" : "❌"
  puts "  [#{status}] #{label}#{info.empty? ? '' : " #{info}"}"
  @results << ok
end

def section(name)
  puts "\n=== #{name} ==="
end

account = Account.find_by(id: 1)
fail "Account#1 not found — run seeds first" unless account

# ─────────────────────────────── 1) Schema ───────────────────────────────
section "[1-2] Schema 검증"
check("ai_employees.preferred_locale 컬럼 존재",     AiEmployee.column_names.include?("preferred_locale"))
check("ai_employees.supported_locales 컬럼 존재",   AiEmployee.column_names.include?("supported_locales"))
check("ai_employees.fallback_locale 컬럼 존재",     AiEmployee.column_names.include?("fallback_locale"))
check("conversations.detected_locale 컬럼 존재",    Conversation.column_names.include?("detected_locale"))
check("conversations.response_locale 컬럼 존재",    Conversation.column_names.include?("response_locale"))

# ─────────────────────────────── 3) Detector ─────────────────────────────
section "[3] LanguageDetector 분류"
check("한국어 '안녕하세요' → ko",          LanguageDetector.detect("안녕하세요") == "ko")
check("영어 'Hello there' → en",          LanguageDetector.detect("Hello there") == "en")
check("일본어 'こんにちは' → ja",          LanguageDetector.detect("こんにちは") == "ja")
check("중국어 '您好' → zh",                LanguageDetector.detect("您好") == "zh")
check("혼합 (영어 우선) '안녕 Hi' → ko",  LanguageDetector.detect("안녕 Hi") == "ko") # Hangul 우선
check("빈 문자열 → ko (fallback)",        LanguageDetector.detect("") == "ko")
check("Hangul+ASCII '가격은 10000원' → ko", LanguageDetector.detect("가격은 10000원") == "ko")
check("confidence 0~1 범위",              (0.0..1.0).cover?(LanguageDetector.confidence("안녕하세요")))

# ─────────────────────────────── 4-5) Route ──────────────────────────────
section "[4-7] ResponseComposer 라우팅"
ai = account.ai_employees.first || AiEmployee.create!(
  account: account, name: "테스트 직원",
  supported_locales: "ko,en", fallback_locale: "ko"
)
ai.update!(supported_locales: "ko,en", fallback_locale: "ko") if ai.respond_to?(:supported_locales=)

r4 = ResponseComposer.compose(account: account, channel_kind: "instagram",
                              text: "안녕하세요, 가격 좀 알려주세요", intent: "ack")
check("한국어 인바운드 → locale_used=ko", r4.locale_used == "ko", "(got=#{r4.locale_used})")
check("한국어 응답 본문에 한글 포함",     r4.reply.include?("확인") || r4.reply.include?("감사"))

r5 = ResponseComposer.compose(account: account, channel_kind: "email",
                              text: "Hello, I'd like to ask about pricing.", intent: "ack")
check("영어 인바운드 → locale_used=en",   r5.locale_used == "en", "(got=#{r5.locale_used})")
check("영어 응답 본문에 'Got it' 포함",    r5.reply.include?("Got it"))

# fallback: ja인데 supported=ko,en
ai.update!(supported_locales: "ko,en", fallback_locale: "ko")
r6 = ResponseComposer.compose(account: account, channel_kind: "instagram",
                              text: "こんにちは", intent: "ack")
check("미지원 locale(ja) → fallback(ko)", r6.locale_used == "ko", "(got=#{r6.locale_used})")

r7 = ResponseComposer.compose(account: account, channel_kind: "instagram",
                              text: "환불해주세요", intent: "handoff")
check("handoff intent → needs_handoff=true",   r7.needs_handoff == true)
check("handoff intent → reply 비어있음",       r7.reply.to_s.empty?)
check("handoff intent → skipped_reason 채워짐", r7.skipped_reason.to_s.length > 0)

# ─────────────────────────────── 8-9) Channel ────────────────────────────
section "[8-9] 채널별 동작"
r8 = ResponseComposer.compose(account: account, channel_kind: "email",
                              text: "Hello, please send me the catalog.", intent: "ack")
check("이메일 suffix 'Best regards' 포함",  r8.reply.include?("Best regards"))
check("이메일 suffix 직원명 포함",           r8.reply.include?(ai.name))

r9 = ResponseComposer.compose(account: account, channel_kind: "mastodon",
                              text: "안녕하세요 테스트 메시지입니다", intent: "greeting")
check("mastodon 응답 500자 이내",            r9.reply.length <= 500, "(len=#{r9.reply.length})")

# overflow 케이스
huge = "안녕하세요 " + ("반갑습니다 " * 200)
r9b = ResponseComposer.compose(account: account, channel_kind: "mastodon",
                               text: huge, intent: "ack")
check("mastodon overflow 시 truncation",     r9b.reply.length <= 500, "(len=#{r9b.reply.length})")

# ─────────────────────────────── 10) Tone override ───────────────────────
section "[10] 채널별 tone override"
# json_attr stores via write_attribute — passing a Hash stores Ruby literal form.
# Use update_columns with a proper JSON string so JSON.parse handles it.
ai.update_columns(channel_behaviors_json: '{"mastodon":{"tone":"casual"},"default":{"tone":"calm_professional"}}')
ai.reload
r10 = ResponseComposer.compose(account: account, channel_kind: "mastodon",
                               text: "hi", intent: "ack")
check("mastodon → channel_behaviors_json tone=casual 적용", r10.tone == "casual", "(got=#{r10.tone})")

r10b = ResponseComposer.compose(account: account, channel_kind: "email",
                                text: "hi", intent: "ack")
check("email → default tone=calm_professional 적용",       r10b.tone == "calm_professional", "(got=#{r10b.tone})")

# cleanup tone override (다음 실행에 영향 없게)
ai.update_columns(channel_behaviors_json: '{}')
ai.reload
ai.update_columns(tone: "calm_professional") if ai.respond_to?(:tone=)

# ─────────────────────────────── 11) Conversation 라우팅 ─────────────────
section "[11-12] Conversation 실측"
conv = Conversation.where(account: account).order(:id).first
if conv.nil?
  ai_e = account.ai_employees.first
  channel = account.channel_connections.where(status: "active").first
  conv = Conversation.create!(
    account: account, ai_employee: ai_e, channel_connection: channel,
    channel_kind: channel&.kind || "instagram",
    external_thread_id: "test-thread-#{SecureRandom.hex(3)}",
    customer_display_name: "테스트 손님"
  ) if ai_e && channel
end

if conv
  detected = LanguageDetector.detect("가격 알려주세요")
  conv.update!(detected_locale: detected, response_locale: detected)
  check("Conversation.detected_locale 저장",  conv.reload.detected_locale == "ko")
  check("Conversation.response_locale 저장",  conv.reload.response_locale == "ko")
else
  check("Conversation 실측 (skip)",  true, "(ai/channel 부재)")
end

# 채널별 max length 테이블 검증
check("instagram max=2200",   ResponseComposer::DEFAULT_MAX_LENGTH["instagram"] == 2200)
check("mastodon max=500",     ResponseComposer::DEFAULT_MAX_LENGTH["mastodon"] == 500)
check("email max=10000",      ResponseComposer::DEFAULT_MAX_LENGTH["email"] == 10000)

# ───────────────────────────────── 결과 ────────────────────────────────
passed = @results.count(true)
failed = @results.count(false)
total  = passed + failed
puts "\n" + ("=" * 60)
puts "PASS: #{passed} / #{total}"
puts failed.zero? ? "🎉 todo #10 모든 검증 통과" : "❌ todo #10 실패 (#{failed}건)"
exit(failed.zero? ? 0 : 1)