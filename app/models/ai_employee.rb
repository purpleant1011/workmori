class AiEmployee < ApplicationRecord
  include AccountScoped
  include JsonAttr

  # ActiveStorage 첨부 (비용 0: 로컬 디스크 사용)
  has_one_attached :avatar
  has_many_attached :reference_images

  json_attr :vocabulary_phrases_json, default: ->{ [] }
  json_attr :forbidden_phrases_json, default: ->{ [] }
  json_attr :can_answer_topics_json, default: ->{ [] }
  json_attr :must_handoff_topics_json, default: ->{ [] }
  json_attr :work_days_json, default: ->{ %w[mon tue wed thu fri] }
  json_attr :work_hours_json, default: ->{ { "start" => "09:00", "end" => "18:00" } }
  json_attr :channel_behaviors_json, default: ->{ {} }
  json_attr :applied_to_channel_kind  # no-op placeholder; avoids method_missing

  # memory_json shape: { "notes" => [], "topics" => [], "style_examples" => [] }
  # Use #memory accessor for a normalized hash; raw column also accessible via `super`.
  def memory
    raw = self[:memory_json]
    raw.is_a?(Hash) ? raw : { "notes" => [], "topics" => [], "style_examples" => [] }
  end

  def append_memory!(kind:, value:)
    current = memory
    bucket  = Array(current[kind.to_s])
    entry   = { "v" => value.to_s, "at" => Time.current.iso8601 }
    bucket  << entry
    bucket  = bucket.last(50) # ring buffer
    current[kind.to_s] = bucket
    update_columns(memory_json: current, last_memory_extracted_at: Time.current)
    entry
  end

  # Light-touch heuristic extractor. Real Hermes adapter will replace this.
  def extract_memory_from_conversation!(conversation)
    return [] unless conversation
    text = conversation.messages.to_s
    saved = []

    if text.match?(/자주\s*묻는\s*질문|FAQ|자주/)
      saved << append_memory!(kind: "topics", value: "고객이 자주 묻는 질문을 정리")
    end
    if text.match?(/프로모션|이벤트|할인/)
      saved << append_memory!(kind: "topics", value: "프로모션/이벤트 관심 빈도")
    end
    if text.match?(/예약|방문|예약일|시간/)
      saved << append_memory!(kind: "topics", value: "예약/방문 시간 문의 빈번")
    end
    update_columns(last_memory_extracted_at: Time.current) if saved.any?
    saved
  end

  belongs_to :account
  has_many :ai_employee_versions, dependent: :destroy
  has_many :guardrail_policies, dependent: :destroy
  has_many :escalation_rules, dependent: :destroy
  has_many :automation_rules, dependent: :destroy
  has_many :content_items, dependent: :destroy
  has_many :conversations, dependent: :destroy

  validates :name, presence: true
  validates :role_label, presence: true
  validates :tone, inclusion: { in: %w[calm_professional warm_casual bright_active] }
  validates :honorific, inclusion: { in: %w[formal semi casual] }
  validates :approval_mode, inclusion: { in: %w[none owner_review staff_review] }

  STATUSES = %w[active paused archived].freeze

  def pause!; update!(status: "paused"); end
  def resume!; update!(status: "active"); end

  def snapshot_for_version
    {
      name: name, role_label: role_label, industry_expertise: industry_expertise,
      tone: tone, friendliness: friendliness, expertise_level: expertise_level,
      proactiveness: proactiveness, honorific: honorific, sentence_length: sentence_length,
      vocabulary_phrases_json: vocabulary_phrases_json,
      forbidden_phrases_json: forbidden_phrases_json,
      can_answer_topics_json: can_answer_topics_json,
      must_handoff_topics_json: must_handoff_topics_json,
      work_days_json: work_days_json, work_hours_json: work_hours_json,
      daily_post_quota: daily_post_quota, weekly_post_quota: weekly_post_quota,
      approval_mode: approval_mode, channel_behaviors_json: channel_behaviors_json,
      monthly_token_budget: monthly_token_budget, daily_token_budget: daily_token_budget,
      monthly_cost_budget_krw: monthly_cost_budget_krw, daily_cost_budget_krw: daily_cost_budget_krw,
      natural_language_instructions: natural_language_instructions,
      status: status,
    }
  end

  def work_days_list
    Array(work_days_json).map(&:to_s)
  end
end
