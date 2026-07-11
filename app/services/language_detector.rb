# frozen_string_literal: true
#
# Lightweight language detector used to route AI responses to the right locale.
# No external libraries — pure Unicode block heuristics.
#
# Usage:
#   LanguageDetector.detect("안녕하세요") # => "ko"
#   LanguageDetector.detect("Hello there") # => "en"
#
# Designed for short customer messages (Korean / English / Japanese / Chinese).
# Falls back to "ko" when no signal is strong enough.
class LanguageDetector
  SUPPORTED_LOCALES = %w[ko en ja zh].freeze

  # Han characters (CJK ideographs) — used for both Japanese kanji and Chinese.
  HAN_RE         = /\p{Han}/u
  # Hiragana and Katakana — Japanese only.
  HIRAGANA_RE    = /[\u3040-\u309F]/u
  KATAKANA_RE    = /[\u30A0-\u30FF]/u
  # Hangul (Korean alphabet) + Hangul compatibility jamo.
  HANGUL_RE      = /[\uAC00-\uD7AF\u1100-\u11FF\u3130-\u318F]/u
  # ASCII letters — strong English signal.
  ASCII_LETTER_RE = /[A-Za-z]/

  # Returns one of SUPPORTED_LOCALES.
  def self.detect(text)
    return "ko" if text.blank?
    s = text.to_s

    counts = {
      "ko" => (s.scan(HANGUL_RE).size),
      "ja" => (s.scan(HIRAGANA_RE).size + s.scan(KATAKANA_RE).size),
      "zh" => 0,
      "en" => (s.scan(ASCII_LETTER_RE).size)
    }
    han = s.scan(HAN_RE).size
    # Heuristic: if Hangul is present → Korean wins regardless of kanji.
    if counts["ko"] > 0
      return "ko"
    end
    # If kana present, it's Japanese.
    if counts["ja"] > 0
      return "ja"
    end
    # Han without kana, no Hangul → Chinese.
    if han > 0 && counts["ko"].zero? && counts["ja"].zero?
      return "zh"
    end
    # ASCII letters only → English.
    return "en" if counts["en"] >= 3 && han.zero? && counts["ko"].zero?

    # Default fallback — Korean is the business's primary locale.
    "ko"
  end

  # Quick test of confidence. Useful when an AI employee has multiple supported
  # locales and we want to know whether to trust the heuristic.
  def self.confidence(text)
    return 0.0 if text.blank?
    s   = text.to_s
    total = s.length.to_f
    return 0.0 if total.zero?
    primary = detect(s)
    signal =
      case primary
      when "ko" then s.scan(HANGUL_RE).size
      when "ja" then s.scan(HIRAGANA_RE).size + s.scan(KATAKANA_RE).size
      when "zh" then s.scan(HAN_RE).size
      when "en" then s.scan(ASCII_LETTER_RE).size
      end
    (signal.to_f / total).round(3)
  end
end