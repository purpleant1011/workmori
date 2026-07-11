class Inquiries::ClassifyJob < ApplicationJob
  queue_as :default

  INQUIRY_KIND_KEYWORDS = {
    "onboarding" => %w[가입 셋업 설정 비밀번호],
    "pricing"    => %w[요금 가격 결제 보증금],
    "security"   => %w[보안 해킹 유출 비밀번호],
    "legal"      => %w[약관 계약 환불 해지],
    "general"    => []
  }.freeze

  def perform(inquiry_id)
    inquiry = Inquiry.find_by(id: inquiry_id)
    return unless inquiry
    text = "#{inquiry.subject} #{inquiry.body}".downcase
    best = INQUIRY_KIND_KEYWORDS.max_by { |_k, words| words.any? { |w| text.include?(w) } ? words.size : -1 }
    kind = best.first
    score = (1.0 * (best.last.size)).clamp(0.0, 1.0)
    inquiry.classify!(kind: kind == "general" ? "general" : kind, score: score)
  end
end
