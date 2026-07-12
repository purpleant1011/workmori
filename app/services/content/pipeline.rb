# Content::Pipeline — 콘텐츠 생성 → 안전 검증 → 승인 흐름
class Content::Pipeline
  Result = Struct.new(:content_item, :approval_request, :safety_result, keyword_init: true)

  INTENT_TO_KIND = {
    "post" => "feed",
    "reply" => "feed",
    "report" => "feed",
    "faq_update" => "feed",
    "data_export" => "feed"
  }.freeze

  def self.run(account:, ai_employee:, automation_rule: nil, intent: nil, schedule_kind: "manual")
    new(account: account, ai_employee: ai_employee, automation_rule: automation_rule, intent: intent, schedule_kind: schedule_kind).run!
  end

  def initialize(account:, ai_employee:, automation_rule: nil, intent: nil, schedule_kind: "manual")
    @account = account
    @ai_employee = ai_employee
    @rule = automation_rule
    @intent = intent || @rule&.intent_kind || "post"
    @schedule_kind = schedule_kind
  end

  def run!
    knowledge_ctx = build_knowledge_context
    draft = build_draft(knowledge_ctx)
    content_kind = resolve_content_kind

    content_item = ContentItem.create!(
      account: @account,
      ai_employee: @ai_employee,
      automation_rule: @rule,
      title: draft[:title],
      body: draft[:body],
      caption: draft[:caption],
      hashtags_json: draft[:hashtags].to_json,
      content_kind: content_kind,
      state: "draft",
      safety_state: "unchecked",
      target_channel_kind: draft[:target_channel_kind],
      scheduled_at: compute_schedule_time,
      safety_notes: {},
      evidence_chunks_json: knowledge_ctx.to_json,
    )

    # Pre-publish safety check
    safety = Safety::Policy.check!(content: draft[:body].to_s + "\n" + draft[:caption].to_s, account: @account, stage: "pre_publish", persist: true)

    approval = nil
    new_state =
      case safety.verdict
      when "blocked"
        content_item.update!(safety_state: "blocked", safety_notes: { hits: safety.hits, rules: safety.rules }, state: "needs_review")
        needs_manual_review(safety) # blocked도 사용자 검토 후 발행 가능 → ApprovalRequest pending
      when "needs_review"
        content_item.update!(safety_state: "needs_review", safety_notes: { hits: safety.hits, rules: safety.rules }, state: "needs_review")
        needs_manual_review(safety)
      when "warn"
        content_item.update!(safety_state: "passed", safety_notes: { verdict: safety.verdict, hits: safety.hits, rules: safety.rules }, state: "approved")
        nil # 안전 통과 + 자동 발행 OK
      else # passed
        content_item.update!(safety_state: "passed", safety_notes: { verdict: safety.verdict, rules: safety.rules }, state: "approved")
        nil
      end

    # Versioning
    ContentVersion.create!(
      account: @account,
      content_item: content_item,
      version_number: 1,
      body: draft[:body],
      caption: draft[:caption],
      hashtags_json: draft[:hashtags].to_json,
      diff_from_previous: {},
      changed_by_user_id: nil,
    )

    # Auto-schedule if approved + scheduled_at present
    if new_state.nil? && content_item.scheduled_at && content_item.state == "approved"
      Content::Scheduler.enqueue_publisher(content_item)
    end

    Result.new(
      content_item: content_item,
      approval_request: approval,
      safety_result: { verdict: safety.verdict, hits: safety.hits, rules: safety.rules },
    )
  end

  def resolve_content_kind
    allowed = ContentItem.const_defined?(:KINDS) ? ContentItem::KINDS : %w[feed]
    return @intent if allowed.include?(@intent)
    return @intent if %w[feed reel_script blog thread place_post daangn_post cardnews shortform].include?(@intent)
    INTENT_TO_KIND[@intent] || allowed.first || "feed"
  end

  private

  def build_knowledge_context
    docs = @account.knowledge_documents.order(updated_at: :desc).limit(5)
    docs.map { |d| { title: d.title, snippet: d.body.to_s[0, 200] } }
  end

  def build_draft(knowledge_ctx)
    persona = @ai_employee.persona_preset || "친근하고 공손한 매장 안내 직원"
    topics_sample = Array(@ai_employee.memory["topics"]).last(3).join(", ")
    seed_text = knowledge_ctx.first&.dig(:snippet).presence || "저희 매장 정보를 알려드릴게요."

    # P3 Antigravity 통합 (2026-07-12): antigravity_cli_enabled 일 때
    # 워커 호출해 진짜 글 작성. 아니면 템플릿 fallback.
    if FeatureFlags.enabled?(:antigravity_cli_enabled)
      draft = build_draft_via_antigravity(persona, topics_sample, seed_text, knowledge_ctx)
      return draft if draft
    end

    case @intent
    when "feed"
      {
        title: "#{@account.name} 추천 안내",
        body: "#{@account.name}에서 알려드려요.\n\n#{seed_text}\n\n자세한 내용은 언제든 편하게 물어봐 주세요. #{persona}",
        caption: "✨#{@account.name} 안내 ✨\n자세한 내용은 프로필 링크에서 확인하실 수 있어요.",
        hashtags: ["#한국소상공인", "##{@account.name.gsub(/\s+/, '')}", "#매장안내"],
        target_channel_kind: "instagram_feed",
      }
    when "blog"
      {
        title: "#{@account.name} 매장 소개",
        body: "안녕하세요. #{@account.name}입니다.\n\n#{seed_text}\n\n#{persona}",
        caption: "",
        hashtags: ["#매장소개", "##{@account.name.gsub(/\s+/, '')}"],
        target_channel_kind: "blog",
      }
    when "shortform", "reel_script"
      {
        title: "#{@account.name} 숏폼 스크립트",
        body: "[0~5초] 한 줄 인사로 시작\n[5~30초] 핵심 정보 전달\n[30~50초] CTA\n\n#{seed_text}",
        caption: "🔥 30초 요약 #{@account.name}",
        hashtags: ["#숏폼", "#30초요약", "##{@account.name.gsub(/\s+/, '')}"],
        target_channel_kind: "instagram_reel",
      }
    else
      {
        title: "#{@account.name} 안내글",
        body: seed_text,
        caption: "#{@account.name} 안내드림",
        hashtags: ["##{@account.name.gsub(/\s+/, '')}"],
        target_channel_kind: "blog",
      }
    end
  end

  def build_draft_via_antigravity(persona, topics_sample, seed_text, knowledge_ctx)
    bp = BusinessProfile.find_by(account_id: @account.id)
    memories = bp ? BusinessMemory.recall(business_profile: bp, limit: 5) : []
    context_memories = memories.map { |m| { id: m.id, scope: m.scope, kind: m.memory_kind, content: m.content } }

    system_prompt = "당신은 소상공인 매장의 SNS 마케터입니다. 한국어로 자연스럽고 진정성 있게 작성하세요."
    user_prompt = <<~PROMPT
      매장: #{@account.name}
      페르소나: #{persona}
      최근 관심 주제: #{topics_sample.presence || "(없음)"}
      참고 정보: #{seed_text}
      작성 형식: #{@intent}
      출력 형식: {"title": "...", "body": "...", "caption": "...", "hashtags": ["#..."]}
    PROMPT

    response = AntigravityClient.invoke(
      business_profile_id: BusinessProfile.find_by(account_id: @account.id)&.id || @account.id,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ],
      structured_output: "content_draft",
      context_memories: context_memories
    )

    parsed = response["structured"] || parse_text_to_structured(response["text"].to_s)
    return nil unless parsed.is_a?(Hash)

    {
      title: parsed["title"].to_s[0, 200].presence || "#{@account.name} 안내",
      body: parsed["body"].to_s.presence || seed_text,
      caption: parsed["caption"].to_s,
      hashtags: Array(parsed["hashtags"]).presence || ["##{@account.name.gsub(/\s+/, '')}"],
      target_channel_kind: target_channel_for(@intent)
    }
  rescue AntigravityClient::Error => e
    Rails.logger.warn("[Content::Pipeline] antigravity fallback: #{e.message}")
    nil
  end

  def parse_text_to_structured(text)
    return nil unless text.include?("{")
    json_str = text[text.index("{")..]
    json_str = json_str[0..json_str.rindex("}")] if json_str.include?("}")
    JSON.parse(json_str)
  rescue JSON::ParserError
    nil
  end

  def target_channel_for(intent)
    case intent
    when "feed" then "instagram_feed"
    when "blog" then "blog"
    when "shortform", "reel_script" then "instagram_reel"
    when "thread" then "threads"
    when "place_post" then "naver_place"
    when "daangn_post" then "daangn"
    when "cardnews" then "instagram_feed"
    else "blog"
    end
  end

  def compute_schedule_time
    if @schedule_kind == "manual"
      nil
    elsif @schedule_kind == "now"
      Time.current
    elsif @schedule_kind == "tick"
      Time.current + 30.minutes
    else
      nil
    end
  end

  def needs_manual_review(safety)
    content_item = ContentItem.find_by(automation_rule: @rule, state: "needs_review")
    return nil unless content_item
    ApprovalRequest.create!(
      account: @account,
      content_item: content_item,
      automation_execution: nil,
      state: "pending",
      requested_from_user_id: nil, # system-generated
      expires_at: Time.current + 24.hours,
    )
  end
end
