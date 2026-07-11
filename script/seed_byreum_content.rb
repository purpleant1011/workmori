#!/usr/bin/env ruby
# 바이름 청라점 — 콘텐츠/문의/리포트 시드 (별도 실행)
# 실행: bin/rails runner script/seed_byreum_content.rb

puts "[byreum-content] starting..."

acct = Account.find_by(slug: "byreum-cheongna")
raise "Account not found" unless acct

emp = acct.ai_employees.first
ch_instagram = acct.channel_connections.find_by(kind: "instagram")
ch_blog = acct.channel_connections.find_by(kind: "blog")

# 1. 바이름 콘텐츠 시드 — title로 unique, find_or_initialize_by
content_seeds = [
  { title: "[바이름] 청라 자연 눈썹 디자인 — 얼굴형 맞춤", kind: "feed", state: "scheduled", days: 0, hour: 14, channel: ch_instagram,
    body: "[바이름 청라점] 25년 경력 이아름 원장이 직접 시술하는 자연스러운 눈썹 디자인.\n\n얼굴형과 모발 상태에 맞춘 퍼스널 디자인으로, 청라 지역 고객분들의 단골 신뢰를 받고 있습니다.\n\n#청라눈썹 #자연스러운눈썹 #바이름청라점 #25년경력",
    tags: "청라눈썹, 자연스러운눈썹, 바이름, 25년경력" },
  { title: "[바이름] 시술 전 자주 묻는 질문 6가지", kind: "blog", state: "approved", days: 1, hour: 10, channel: ch_blog,
    body: "바이름 청라점의 이아름 원장이 25년 경력에서 정리한 시술 전 자주 묻는 질문 6가지.\n\n1) 얼굴형에 맞게 디자인해 주시나요?\n2) 시술 시간은?\n3) 잔흔이 있어도 가능한가요?\n4) 통증은?\n5) 회복기간은?\n6) 예약은 어떻게?\n\n자세한 답변은 바이름 청라점 블로그를 참고해주세요.",
    tags: "FAQ, 시술 전, 청라, 바이름" },
  { title: "[바이름] 잔흔 보정 — 가능한 경우와 주의점", kind: "feed", state: "draft", days: 2, hour: 14, channel: ch_instagram,
    body: "[바이름 청라점] 기존 눈썹 시술의 잔흔이 남아 계신 분들을 위한 보정 시술 안내.\n\n25년 경력 이아름 원장이 잔흔 상태를 정확히 진단한 뒤 가능한 범위에서 자연스럽게 보정해드립니다. 사진 상담을 통해 먼저 확인하시는 것을 권합니다.",
    tags: "잔흔, 보정, 바이름, 청라" },
  { title: "[바이름] 자연스러운 눈썹을 위한 3가지 원칙", kind: "reel_script", state: "draft", days: 3, hour: 18, channel: ch_instagram,
    body: "[바이름 청라점 · 이아름 원장]\n\n자연스러운 눈썹의 3가지 원칙:\n1) 얼굴형보다 모발 방향을 따른다\n2) 양 끝을 절대 대칭으로 맞추지 않는다\n3) 색상은 모발과 1~2톤 차이로\n\n자세한 내용은 댓글로 질문 주세요.",
    tags: "자연스러운눈썹, 원칙, 바이름" },
  { title: "[바이름] 시술 후기 모음 (네이버 블로그)", kind: "blog", state: "published", days: -3, hour: 10, channel: ch_blog,
    body: "바이름 청라점 이아름 원장님 시술 후기를 네이버 블로그에서 만나보세요.\n\nhttps://blog.naver.com/larlds",
    tags: "후기, 네이버블로그, 바이름" },
  { title: "[바이름] 청라 주차/오시는 길 안내", kind: "place_post", state: "published", days: -7, hour: 11, channel: acct.channel_connections.find_by(kind: "naver_place"),
    body: "바이름 청라점 오시는 길 안내.\n\n위치: 인천광역시 서구 청라동\n주차: 매장 앞 2대 가능 + 공용주차장\n\n대중교통: 청라역 도보 5분",
    tags: "위치, 주차, 청라, 바이름" },
  { title: "[바이름] 퍼스널 디자인 눈썹이란?", kind: "blog", state: "published", days: -14, hour: 10, channel: ch_blog,
    body: "25년 경력 이아름 원장이 만든 '퍼스널 디자인 눈썹'은 고객의 얼굴형, 모발 방향, 피부 상태, 라이프스타일을 종합적으로 분석해 디자인합니다.",
    tags: "퍼스널디자인, 바이름, 자연스러운눈썹" }
]

created = 0
content_seeds.each do |attrs|
  ci = acct.content_items.find_or_initialize_by(title: attrs[:title])
  ci.assign_attributes(
    body: attrs[:body],
    content_kind: attrs[:kind],
    state: attrs[:state],
    safety_state: "passed",
    ai_employee: emp,
    target_channel_connection: attrs[:channel],
    target_channel_kind: attrs[:channel]&.kind,
    scheduled_at: Time.current + attrs[:days].days + attrs[:hour].hours,
    published_at: attrs[:state] == "published" ? Time.current + attrs[:days].days + attrs[:hour].hours : nil,
    hashtags_json: attrs[:tags].split(", ").map { |t| t.start_with?("#") ? t : "##{t}" },
    caption: attrs[:body].split("\n").first.to_s[0, 200]
  )
  if ci.save
    created += 1
  else
    puts "✗ #{attrs[:title]}: #{ci.errors.full_messages.join(', ')}"
  end
end
puts "✓ Content Items created: #{created}/#{content_seeds.size} (total: #{acct.content_items.count})"

# 2. 바이름 문의 시드 — Conversation (인계 + 기초응대)
require "securerandom"
conv_seeds = [
  { state: "open", channel_kind: "instagram", summary: "잔흔 보정 가능한지 사진 상담 요청", last_msg: "기존에 다른 곳에서 시술 받았는데 잔흔이 남아있어요. 보정 가능할까요?", risk: "high" },
  { state: "open", channel_kind: "instagram", summary: "가격 조정 가능한지 문의", last_msg: "예산이 좀 부족한데 학생 할인 같은게 있을까요?", risk: "high" },
  { state: "closed", channel_kind: "instagram", summary: "자연 눈썹 가격 범위 문의", last_msg: "자연 눈썹 가격이 얼마 정도인가요?", risk: "low" },
  { state: "closed", channel_kind: "threads", summary: "오늘 영업시간 문의", last_msg: "오늘 몇 시까지 영업하시나요?", risk: "low" },
  { state: "closed", channel_kind: "blog", summary: "이번 주 토요일 예약 문의", last_msg: "이번 주 토요일 오후 3시 예약 가능한가요?", risk: "low" }
]
created = 0
conv_seeds.each do |attrs|
  # Conversation 생성
  conv = acct.conversations.find_or_initialize_by(external_thread_id: "seed_#{attrs[:summary][0,20]}")
  conv.assign_attributes(
    state: attrs[:state],
    channel_kind: attrs[:channel_kind],
    risk_level: attrs[:risk],
    detected_locale: "ko",
    response_locale: "ko",
    ai_employee: emp,
    customer_display_name: attrs[:summary][0, 50],
    last_message_at: Time.current - rand(0..48).hours
  )
  if conv.save
    created += 1
  else
    puts "✗ Conv #{attrs[:summary]}: #{conv.errors.full_messages.join(', ')}"
  end
end
puts "✓ Conversations created: #{created}/#{conv_seeds.size}"

# 3. 바이름 원장님 확인 필요 항목 (Handoffs)
handoff_seeds = [
  { reason: "잔흔 판단 요청", summary: "고객가 기존 시술 잔흔 사진과 함께 보정 가능성 문의 — 원장님 판단 필요", conv_idx: 0 },
  { reason: "가격 조정 요청", summary: "학생 할인 가능 여부 — 원장님 결정 필요", conv_idx: 1 }
]
created = 0
handoff_seeds.each_with_index do |attrs, idx|
  conv = acct.conversations.where(risk_level: "high").offset(idx).first
  next unless conv
  h = acct.handoffs.find_or_initialize_by(summary: attrs[:summary])
  h.assign_attributes(
    channel: "instagram",
    state: "open",
    reason: attrs[:reason],
    conversation: conv
  )
  if h.save
    created += 1
  else
    puts "✗ Handoff: #{h.errors.full_messages.join(', ')}"
  end
end
puts "✓ Handoffs (원장님 확인 필요): #{created}/#{handoff_seeds.size}"

# 4. 바이름 일일 보고 (DeliveryLog)
log_seeds = [
  { kind: "daily_report", subject: "바이름 청라점 7월 11일 일일 보고", excerpt: "오늘 소희: 콘텐츠 2건 생성, 인스타 DM 4건 응대, 잔흔 상담 1건 원장님께 인계" }
]
log_seeds.each do |attrs|
  dl = acct.delivery_logs.find_or_initialize_by(kind: attrs[:kind], subject: attrs[:subject])
  dl.assign_attributes(
    body_excerpt: attrs[:excerpt],
    recipient_count: 1,
    result_payload: { report_date: Date.current, byreum: true, ai_employee_id: emp.id }
  )
  dl.save!
end
puts "✓ DeliveryLog: #{acct.delivery_logs.count}"

puts "\n[byreum-content] ✅ 바이름 콘텐츠/문의/리포트 시드 완료"
puts "  ContentItems: #{acct.content_items.count}"
puts "  Conversations: #{acct.conversations.count}"
puts "  Handoffs: #{acct.handoffs.count}"
puts "  DeliveryLogs: #{acct.delivery_logs.count}"