# frozen_string_literal: true
#
# CSAT summary: average score, distribution (promoter / neutral / detractor),
# trend over the requested window.
#
# Categorisation (1–5 scale):
#   detractor: 1–2
#   neutral:   3
#   promoter:  4–5
class CsatSummary
  Result = Struct.new(
    :average_score, :total_responses,
    :promoters, :neutrals, :detractors,
    :promoter_pct, :detractor_pct,
    :nps_score, # %promoter − %detractor, range −100..100
    :recent_comments,
    keyword_init: true
  )

  def self.call(account:, since: 30.days.ago, limit_comments: 5)
    responses = account.csat_responses.where("created_at >= ?", since).order(created_at: :desc)
    total     = responses.count
    avg       = total.zero? ? 0.0 : (responses.average(:score) || 0).to_f.round(2)

    promoters  = responses.where(score: 4..5).count
    neutrals   = responses.where(score: 3).count
    detractors = responses.where(score: 1..2).count

    promoter_pct = total.zero? ? 0.0 : ((promoters.to_f / total) * 100).round(1)
    detractor_pct = total.zero? ? 0.0 : ((detractors.to_f / total) * 100).round(1)
    nps = (promoter_pct - detractor_pct).round(1)

    Result.new(
      average_score: avg, total_responses: total,
      promoters: promoters, neutrals: neutrals, detractors: detractors,
      promoter_pct: promoter_pct, detractor_pct: detractor_pct,
      nps_score: nps,
      recent_comments: responses.where.not(comment: [nil, ""]).limit(limit_comments).pluck(:score, :comment, :created_at)
    )
  end
end