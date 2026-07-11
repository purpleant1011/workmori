module Safety
  # Lightweight content safety checker. Inspects user-facing text against a
  # static rule set, persists a `SafetyLog` row, and returns a verdict hash so
  # callers can branch (block, needs_review, warn, pass).
  #
  # Why static rules + log: this is the local, deterministic safety net. The
  # AI adapter layer (when wired) should re-evaluate text, but every decision
  # is recorded for audit and BI.
  class Policy
    DEFAULT_RULES = {
      "forbidden_phrase_guarantee"  => %w[100% 보장 무조건 효과 전후사진 100%],
      "forbidden_phrase_medical"    => %w[시술 후 안전 완치],
      "forbidden_phrase_discount"   => %w[병원 할인 일반소매업 의료할인],
      "forbidden_phrase_review"     => %w[리뷰 조작 가짜후기 삭제해드립니다],
      "forbidden_topic"             => %w[자단연],
      "sensitive_topic_pricing"     => %w[요금 가격 결제],
      "sensitive_topic_security"    => %w[보안 유출 해킹]
    }.freeze

    SENSITIVE_VERDICTS = {
      "sensitive_topic_pricing"  => "needs_review",
      "sensitive_topic_security" => "needs_review"
    }.freeze

    BLOCK_VERDICTS = %w[forbidden_phrase_guarantee forbidden_phrase_medical
                        forbidden_phrase_discount forbidden_phrase_review
                        forbidden_topic].freeze

    Result = Struct.new(:verdict, :hits, :rules, :notes, keyword_init: true)

    def self.check!(content:, account: nil, stage: "pre_publish",
                    rules: DEFAULT_RULES, content_item: nil, conversation: nil,
                    persist: true)
      new(rules).check(content: content, account: account, stage: stage,
                       content_item: content_item, conversation: conversation,
                       persist: persist)
    end

    def initialize(rules)
      @rules = rules
    end

    def check(content:, account:, stage:, content_item: nil, conversation: nil, persist: true)
      text = content.to_s
      hits = []
      @rules.each do |rid, words|
        Array(words).each do |w|
          next if w.to_s.empty?
          if text.include?(w)
            hits << { rule_id: rid, match: w }
          end
        end
      end

      verdict =
        if hits.any? { |h| BLOCK_VERDICTS.include?(h[:rule_id]) }
          "blocked"
        elsif hits.any? { |h| SENSITIVE_VERDICTS.key?(h[:rule_id]) }
          SENSITIVE_VERDICTS[hits.find { |h| SENSITIVE_VERDICTS.key?(h[:rule_id]) }[:rule_id]]
        elsif hits.any?
          "warn"
        else
          "passed"
        end

      notes = build_notes(verdict, hits, text)

      if persist && account
        begin
          SafetyLog.create!(
            account: account,
            content_item: content_item,
            conversation: conversation,
            stage: stage,
            verdict: verdict,
            rules_json: @rules,
            hits_json: hits,
            notes: notes
          )
        rescue ActiveRecord::RecordInvalid
          # stage/verdict may be a custom value; degrade silently to log-only
          nil
        end
      end

      Result.new(verdict: verdict, hits: hits, rules: @rules, notes: notes)
    end

    private

    def build_notes(verdict, hits, text)
      return nil if hits.empty?
      sample = text.to_s[0, 120].gsub(/\s+/, " ")
      "verdict=#{verdict}, #{hits.size} hits, sample=#{sample}"
    end
  end
end
