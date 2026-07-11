#!/usr/bin/env ruby
# frozen_string_literal: true

# bin/seed_full.rb — 풀 시드 (db/seeds.rb 기본 + 다중 사업장 + 요금제 + 채널 + 계약 + 데이터)
#
# 사용:
#   bin/rails runner bin/seed_full.rb
#
# 멱등성: find_or_initialize_by 패턴 + find_or_create_by! 로 재실행 안전.

puts "[seed_full] starting..."

ActiveRecord::Base.transaction do
  # ────────────────────────────────────────────────
  # 1) Plan 추가 (Starter / Growth / 바이름 특약)
  # ────────────────────────────────────────────────
  plans_data = [
    { code: "starter",     name: "스타터",       description: "소규모 사장님용 시작 플랜. AI 직원 1명, 채널 1개, 콘텐츠 8건/월.", monthly_price_krw:  99_000, monthly_price_vat_krw:   9_900, features: %w[ai_employee_1 channel_1 content_8 monthly] },
    { code: "growth",      name: "그로스",       description: "성장 중인 사업장용. AI 직원 3명, 채널 3개, 콘텐츠 30건/월.",     monthly_price_krw: 199_000, monthly_price_vat_krw:  19_900, features: %w[ai_employee_3 channel_3 content_30 weekly_reports] },
    { code: "byirim_special", name: "바이름 특약", description: "바이름 계약 전담 매니저 배정. 무제한. 보증금 50만원.",        monthly_price_krw: 300_000, monthly_price_vat_krw:  30_000, features: %w[ai_employee_unlimited channel_unlimited content_unlimited dedicated_manager deposit_500k] }
  ]

  plans_data.each do |pd|
    plan = Plan.find_or_initialize_by(code: pd[:code])
    plan.assign_attributes(pd.except(:code))
    plan.save! unless plan.persisted?
    puts "[seed_full] plan: #{plan.code} (id=#{plan.id})"
  end

  # ────────────────────────────────────────────────
  # 2) Demo 사업장 2개 추가 (cafe, retail)
  # ────────────────────────────────────────────────
  secondary_accounts = [
    {
      slug: "demo-cafe", name: "데모 카페", industry_code: "food", industry_subcategory: "cafe",
      brand_intro: "강남역 근처 작은 카페. 직장인 단골多. 매일 오전 7시 오픈.",
      account_owner_email: "cafe-owner@demo.example", ai_name: "루나 카페"
    },
    {
      slug: "demo-shop", name: "데모 편집숍", industry_code: "retail", industry_subcategory: "fashion",
      brand_intro: "홍대 인디 편집숍. 20~30대 여성 타깃. 주말 유동 多.",
      account_owner_email: "shop-owner@demo.example", ai_name: "카리스 편집"
    }
  ]

  secondary_accounts.each do |sd|
    acct = Account.find_or_initialize_by(slug: sd[:slug])
    acct.assign_attributes(
      name: sd[:name],
      status: "active",
      operator_managed: true,
      operator_managed_by_email: "platform-admin@workmori.example",
      timezone: "Asia/Seoul",
      country: "KR",
      settings_json: { onboarding_state: "seed_full", consents: { marketing: false } }
    )
    acct.save! unless acct.persisted?

    owner = User.find_or_initialize_by(email_address: sd[:account_owner_email])
    owner.assign_attributes(
      account: acct,
      name: "#{sd[:name]} 사장",
      role: "owner",
      locale: "ko",
      password: "OwnerPass!23",
      password_confirmation: "OwnerPass!23"
    )
    owner.save! unless owner.persisted?
    Membership.find_or_create_by!(user: owner, account: acct) { |m| m.role = "owner" }

    bp = BusinessProfile.find_or_initialize_by(account: acct)
    bp.assign_attributes(
      industry_code: sd[:industry_code],
      industry_subcategory: sd[:industry_subcategory],
      legal_name: sd[:name],
      trade_name: sd[:name],
      owner_name: owner.name,
      phone: "010-0000-0000",
      public_email: "#{sd[:slug]}@example.com",
      address: "서울특별시 #{sd[:name]} 주소",
      region_label: "서울",
      timezone: "Asia/Seoul",
      brand_intro: sd[:brand_intro],
      onboarding_step: 4,
      onboarding_complete: true,
      operator_managed: true,
      business_hours_json: { mon: "09:00-21:00", tue: "09:00-21:00", wed: "09:00-21:00", thu: "09:00-21:00", fri: "09:00-22:00", sat: "10:00-22:00", sun: "10:00-20:00" },
      products_json: [{ name: "대표 상품", price_krw: 5_000 }],
      services_json: [{ name: "기본 서비스", duration_min: 30 }],
      faqs_json: [{ q: "영업시간은?", a: "평일 9-21시, 주말 10-22시." }],
      forbidden_phrases_json: %w[100% 안전 보장 확실 무료],
      forbidden_topics_json: %w[할인 의료],
      preferred_channels_json: %w[instagram kakao],
      escalation_rules_json: [{ topic: "환불/클레임", handoff_to: "human" }]
    )
    bp.save! unless bp.persisted?

    employee = AiEmployee.find_or_initialize_by(account: acct, name: sd[:ai_name])
    employee.assign_attributes(
      role_label: "마케팅/CS",
      industry_expertise: sd[:industry_subcategory],
      tone: "warm_casual",
      friendliness: 4,
      expertise_level: 3,
      proactiveness: 3,
      honorific: "formal",
      sentence_length: 60,
      forbidden_phrases_json: %w[100% 안전 보장 확실],
      can_answer_topics_json: %w[가격 예약 FAQ 영업시간],
      must_handoff_topics_json: %w[환불 클레임 의료],
      work_days_json: %w[mon tue wed thu fri sat sun],
      work_hours_json: { start: "09:00", end: "21:00" },
      daily_post_quota: 2,
      weekly_post_quota: 8,
      approval_mode: "owner_review",
      monthly_token_budget: 200_000,
      daily_token_budget: 10_000,
      monthly_cost_budget_krw: 50_000,
      daily_cost_budget_krw: 3_000,
      channel_behaviors_json: { instagram: "short", kakao: "short" },
      natural_language_instructions: "친절하고 정중하게. 사실 기반. 출처 인용.",
      status: "active"
    )
    employee.save! unless employee.persisted?

    puts "[seed_full] secondary account: #{acct.slug} (id=#{acct.id})"
  end

  # ────────────────────────────────────────────────
  # 3) 채널 시드 (모든 사업장에 mock 채널 5종)
  # ────────────────────────────────────────────────
  Account.where(operator_managed: true).each do |acct|
    %w[instagram kakao_channel mastodon naver_place email].each_with_index do |kind, i|
      ch = ChannelConnection.find_or_initialize_by(account: acct, kind: kind)
      ch.assign_attributes(
        ai_employee: acct.ai_employees.first,
        connected_by_kind: "operator",
        external_id: "seed_#{acct.id}_#{kind}",
        handle: kind == "instagram" ? "@#{acct.slug.tr('-', '_')}_ig" :
                kind == "kakao_channel" ? "@#{acct.slug}" :
                kind == "mastodon"  ? "#{acct.slug}@mastodon.social" :
                kind == "naver_place" ? "#{acct.slug}_naver" :
                "#{acct.slug}@example.com",
        encrypted_token: "MOCK_TOKEN_SEED_#{acct.id}_#{kind}",
        scopes_json: kind == "instagram" ? %w[basic_publish read_insights] :
                     kind == "kakao_channel" ? %w[profile message_friends] :
                     kind == "mastodon"  ? %w[read write] :
                     kind == "naver_place" ? %w[reply reviews] :
                     %w[smtp imap],
        status: "active",
        last_verified_at: Time.current,
        connected_by_user_id: acct.users.first&.id
      )
      ch.save! unless ch.persisted?
    end
    puts "[seed_full] channels seeded for account=#{acct.slug}"
  end

  # ────────────────────────────────────────────────
  # 4) 바이름 특약 계약 시드
  # ────────────────────────────────────────────────
  demo = Account.find_by(slug: "demo-skincare")
  byirim = Plan.find_by(code: "byirim_special")
  if demo && byirim
    ct = ContractTerm.find_or_initialize_by(account: demo, contract_code: "BYIRIM-2026-001")
    ct.assign_attributes(
      plan: byirim,
      status: "active",
      monthly_price_krw: 300_000,
      monthly_price_vat_krw: 30_000,
      deposit_amount_krw: 500_000,
      billing_anchor_day: 1,
      price_overrides: { "monthly_price_krw" => 300_000, "monthly_price_vat_krw" => 30_000 },
      test_started_on: 30.days.ago.to_date,
      test_ends_on: 7.days.ago.to_date,
      official_service_started_on: 7.days.ago.to_date,
      notes: "바이름 대표 직접 계약. 전담 매니저 배정. 보증금 50만원."
    )
    ct.save! unless ct.persisted?
    puts "[seed_full] byirim contract: id=#{ct.id} code=#{ct.contract_code}"

    # 구독 + 첫 청구서
    sub = Subscription.find_or_initialize_by(account: demo)
    sub.assign_attributes(
      plan: byirim,
      contract_term: ct,
      state: "active",
      started_on: ct.official_service_started_on,
      current_period_start: Time.current.beginning_of_month.to_date,
      current_period_end: Time.current.end_of_month.to_date,
      next_billing_on: Time.current.end_of_month.to_date,
      monthly_price_krw: ct.monthly_price_krw,
      monthly_price_vat_krw: ct.monthly_price_vat_krw,
      deposit_krw: ct.deposit_amount_krw,
      auto_renew: true,
      metadata: { "byirim_special" => true }
    )
    sub.save! unless sub.persisted?

    # 첫 달 청구서
    if sub.persisted?
      Invoice.find_or_create_by!(account: demo, invoice_number: "INV-#{sub.id}-001") do |inv|
        inv.contract_term = ct
        inv.billing_period_start = Time.current.beginning_of_month.to_date
        inv.billing_period_end = Time.current.end_of_month.to_date
        inv.issued_on = Time.current.to_date
        inv.due_on = 7.days.from_now.to_date
        inv.supply_amount_krw = ct.monthly_price_krw
        inv.vat_amount_krw = ct.monthly_price_vat_krw
        inv.discount_amount_krw = 0
        inv.total_amount_krw = ct.monthly_price_krw + ct.monthly_price_vat_krw
        inv.final_amount_krw = ct.monthly_price_krw + ct.monthly_price_vat_krw
        inv.state = "issued"
      end
    end
    puts "[seed_full] subscription + invoice seeded for #{demo.slug}"
  end

  # 다른 두 사업장에 starter / growth 플랜
  {
    "demo-cafe" => "starter",
    "demo-shop" => "growth"
  }.each do |slug, plan_code|
    acct = Account.find_by(slug: slug)
    plan = Plan.find_by(code: plan_code)
    next unless acct && plan

    sub = Subscription.find_or_initialize_by(account: acct)
    sub.assign_attributes(
      plan: plan,
      state: "active",
      started_on: 14.days.ago.to_date,
      current_period_start: Time.current.beginning_of_month.to_date,
      current_period_end: Time.current.end_of_month.to_date,
      next_billing_on: Time.current.end_of_month.to_date,
      monthly_price_krw: plan.monthly_price_krw,
      monthly_price_vat_krw: plan.monthly_price_vat_krw,
      deposit_krw: 0,
      auto_renew: true
    )
    sub.save! unless sub.persisted?
    puts "[seed_full] sub: #{acct.slug} → #{plan.code}"
  end

  # ────────────────────────────────────────────────
  # 5) 기본 시드 재호출 (db/seeds.rb의 데모)
  # ────────────────────────────────────────────────
  load Rails.root.join("db/seeds.rb").to_s
end

puts "[seed_full] done."
puts "[seed_full] 사업장 #{Account.count}개, 채널 #{ChannelConnection.count}개, 구독 #{Subscription.count}개, 청구서 #{Invoice.count}개, 계약 #{ContractTerm.count}개."