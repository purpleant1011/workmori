# frozen_string_literal: true
#
# Routes AI employee responses to the right locale, applies channel-specific
# tone, and enforces length limits per channel. Designed to be called by
# automation rules, manual reply flows, or safety-guarded pipelines.
#
# Inputs:
#   account      — Account scope (so the AI employee + tone settings are looked up)
#   channel_kind — e.g. "instagram", "email", "kakao_channel", "naver_place"
#   text         — the customer's inbound message (used for language detection)
#   intent       — optional short intent hint ("faq", "greeting", "handoff", etc.)
#   locale       — optional override; if nil, LanguageDetector is used.
#
# Result fields:
#   ok               — true when reply is renderable
#   reply            — composed reply string (may be empty when ok is false)
#   locale_used      — locale code that was actually picked
#   detected_locale  — locale inferred from the inbound text
#   tone             — tone key resolved from channel_behaviors_json[channel_kind]
#   needs_handoff    — true if intent says this should be handed off
#   skipped_reason   — populated when ok is false (handoff, locale unsupported, etc.)
class ResponseComposer
  Result = Struct.new(
    :ok, :reply, :locale_used, :detected_locale, :tone,
    :needs_handoff, :skipped_reason,
    keyword_init: true
  )

  DEFAULT_MAX_LENGTH = {
    "instagram"    => 2_200,
    "mastodon"     => 500,
    "kakao_channel" => 1_000,
    "naver_place"  => 1_000,
    "blog"         => 5_000,
    "email"        => 10_000,
    "threads"      => 500,
    "discord"      => 2_000,
    "daangn"       => 1_000
  }.freeze

  TEMPLATES = {
    "greeting" => {
      "ko" => "안녕하세요, %<shop>s입니다. 무엇을 도와드릴까요?",
      "en" => "Hi, this is %<shop>s. How can I help you?",
      "ja" => "こんにちは、%<shop>sです。ご用件をどうぞ。",
      "zh" => "您好，这里是 %<shop>s。请问有什么可以帮您？"
    },
    "ack" => {
      "ko" => "확인했습니다. %<extra>s",
      "en" => "Got it. %<extra>s",
      "ja" => "確認しました。%<extra>s",
      "zh" => "已确认。%<extra>s"
    },
    "handoff" => {
      "ko" => "담당자에게 연결해드릴게요. 잠시만 기다려 주세요.",
      "en" => "Let me connect you to a teammate. One moment please.",
      "ja" => "担当者にお繋ぎします。少しお待ちください。",
      "zh" => "正在为您转接负责同事，请稍等。"
    },
    "thanks" => {
      "ko" => "감사합니다. 또 필요하신 게 있으시면 알려주세요.",
      "en" => "Thank you. Let us know if there's anything else.",
      "ja" => "ありがとうございます。他にもあればお知らせください。",
      "zh" => "谢谢。如果还有其他需要请告诉我们。"
    }
  }.freeze

  # Compose a reply.
  def self.compose(account:, channel_kind:, text: "", intent: nil, locale: nil)
    ai   = pick_ai(account)
    detected = locale.presence || LanguageDetector.detect(text.to_s)
    supported = parse_list(ai&.supported_locales)
    fallback  = ai&.fallback_locale.presence || "ko"
    locale_used =
      if supported.include?(detected)
        detected
      elsif supported.any?
        supported.first
      else
        fallback
      end

    # Tone per channel — channel_behaviors_json may set "tone": "casual" etc.
    tone = resolve_tone(ai, channel_kind)

    # Handoff-required intents skip the AI path.
    if intent.to_s == "handoff"
      return Result.new(
        ok: false, reply: "", locale_used: locale_used,
        detected_locale: detected, tone: tone, needs_handoff: true,
        skipped_reason: "handoff_requested"
      )
    end

    base = render_template(intent: intent, locale: locale_used,
                           shop: account&.name.to_s, extra: text.to_s.strip)
    composed = apply_channel_behavior(base: base, ai: ai, channel_kind: channel_kind, locale: locale_used)
    composed = truncate_to_channel(composed, channel_kind)

    Result.new(
      ok: true, reply: composed,
      locale_used: locale_used, detected_locale: detected,
      tone: tone, needs_handoff: false, skipped_reason: nil
    )
  end

  def self.pick_ai(account)
    return nil if account.nil?
    account.ai_employees.order(:id).first
  end

  def self.parse_list(raw)
    return [] if raw.blank?
    raw.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def self.resolve_tone(ai, channel_kind)
    return "calm_professional" if ai.nil?
    behaviors = read_channel_behaviors(ai)
    behaviors[channel_kind.to_s]&.dig("tone").presence ||
      behaviors["default"]&.dig("tone").presence ||
      ai.tone.presence ||
      "calm_professional"
  end

  # json_attr transparently parses the column to a Hash; but when we update!
  # via raw hash, the column may still hold the JSON string. Handle both.
  def self.read_channel_behaviors(ai)
    raw = ai.respond_to?(:channel_behaviors) ? ai.channel_behaviors : ai[:channel_behaviors_json]
    case raw
    when Hash  then raw
    when String then
      begin
        JSON.parse(raw)
      rescue
        {}
      end
    else
      {}
    end
  end

  def self.render_template(intent:, locale:, shop:, extra:)
    key = intent.to_s.presence || "ack"
    pool = TEMPLATES[key] || TEMPLATES["ack"]
    tmpl = pool[locale] || pool["ko"]
    format(tmpl, shop: shop, extra: extra.to_s)
  end

  # Add channel-specific phrasing hints: emojis for social, formal for email, etc.
  def self.apply_channel_behavior(base:, ai:, channel_kind:, locale:)
    # (tone handled separately; this only adds prefix/suffix flavoring)
    prefix = case channel_kind.to_s
             when "instagram", "threads", "mastodon"
               "🙂 "
             when "email"
               ""
             else
               ""
             end
    suffix = case channel_kind.to_s
             when "email"
               locale == "en" ? "\n\nBest regards,\nThe #{ai&.name || 'Team'}" :
               locale == "ja" ? "\n\nよろしくお願いいたします。\n#{ai&.name || 'チーム'}" :
               locale == "zh" ? "\n\n此致\n#{ai&.name || '团队'}" :
               "\n\n감사합니다.\n#{ai&.name || '팀'} 드림"
             else
               ""
             end
    "#{prefix}#{base}#{suffix}"
  end

  def self.truncate_to_channel(text, channel_kind)
    max = DEFAULT_MAX_LENGTH[channel_kind.to_s] || 1_000
    return text if text.length <= max
    text[0, max - 1] + "…"
  end
end