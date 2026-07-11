# frozen_string_literal: true
#
# Time-series aggregator for business analytics. Builds day-bucketed series
# for content publication, response rate, automation runs, and CSAT trend.
#
# Designed for the dashboard and the "분석/CSAT" route.
class Analytics::Aggregator
  Result = Struct.new(
    :series_published,        # [{date: "2026-07-01", count: 3}, ...]
    :series_response_rate,    # [{date: "2026-07-01", rate: 75.0}, ...]
    :series_automation_runs,  # [{date: ..., total: 5, succeeded: 4, failed: 1}, ...]
    :series_csat,             # [{date: ..., avg_score: 4.2, responses: 3}, ...]
    :totals,
    :from, :to,
    keyword_init: true
  )

  def self.call(account:, days: 30)
    days = days.to_i
    days = 7 if days <= 0
    days = 365 if days > 365
    from_date = (Date.current - (days - 1))
    to_date   = Date.current

    new(account, from_date, to_date).call
  end

  def initialize(account, from_date, to_date)
    @account   = account
    @from_date = from_date
    @to_date   = to_date
    @bucket_dates = (from_date..to_date).to_a
  end

  def call
    Result.new(
      series_published:       series_published,
      series_response_rate:   series_response_rate,
      series_automation_runs: series_automation_runs,
      series_csat:            series_csat,
      totals:                 totals,
      from: @from_date.to_s,
      to: @to_date.to_s
    )
  end

  # ───────────────────────── helpers ─────────────────────────
  def fill_zeros(rows)
    map = rows.each_with_object({}) { |r, h| h[r[:date]] = r }
    @bucket_dates.map do |d|
      key = d.to_s
      map[key] || { date: key, count: 0 }
    end
  end

  # ───────────────────────── series ─────────────────────────
  def series_published
    rel = @account.content_items.where("published_at >= ?", @from_date)
                  .where.not(published_at: nil)
    rows = rel.group("date(published_at)").count.map { |d, n| { date: d.to_s, count: n } }
    fill_zeros(rows)
  end

  def series_response_rate
    convs = @account.conversations.where("created_at >= ?", @from_date)
    grouped = convs.group("date(created_at)").pluck(
      Arel.sql("date(created_at)"),
      Arel.sql("COUNT(*)"),
      Arel.sql("SUM(CASE WHEN state != 'open' THEN 1 ELSE 0 END)")
    )
    by_date = grouped.each_with_object({}) do |(d, total, responded), h|
      rate = total.to_i.zero? ? 0.0 : ((responded.to_f / total) * 100).round(1)
      h[d.to_s] = { date: d.to_s, rate: rate, total: total.to_i, responded: responded.to_i }
    end
    @bucket_dates.map { |d| by_date[d.to_s] || { date: d.to_s, rate: 0.0, total: 0, responded: 0 } }
  end

  def series_automation_runs
    runs = @account.automation_executions.where("started_at >= ?", @from_date)
    grouped = runs.group("date(started_at)").pluck(
      Arel.sql("date(started_at)"),
      Arel.sql("COUNT(*)"),
      Arel.sql("SUM(CASE WHEN state = 'succeeded' THEN 1 ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN state = 'failed' THEN 1 ELSE 0 END)")
    )
    by_date = grouped.each_with_object({}) do |(d, total, succ, fail), h|
      h[d.to_s] = { date: d.to_s, total: total.to_i, succeeded: succ.to_i, failed: fail.to_i }
    end
    @bucket_dates.map { |d| by_date[d.to_s] || { date: d.to_s, total: 0, succeeded: 0, failed: 0 } }
  end

  def series_csat
    rows = @account.csat_responses.where("created_at >= ?", @from_date)
                .group("date(created_at)").pluck(
                  Arel.sql("date(created_at)"),
                  Arel.sql("AVG(score)"),
                  Arel.sql("COUNT(*)")
                )
    by_date = rows.each_with_object({}) do |(d, avg, cnt), h|
      h[d.to_s] = { date: d.to_s, avg_score: avg.nil? ? 0.0 : avg.to_f.round(2), responses: cnt.to_i }
    end
    @bucket_dates.map { |d| by_date[d.to_s] || { date: d.to_s, avg_score: 0.0, responses: 0 } }
  end

  def totals
    {
      content_published:    @account.content_items.where.not(published_at: nil).where("published_at >= ?", @from_date).count,
      automation_total:     @account.automation_executions.where("started_at >= ?", @from_date).count,
      automation_succeeded: @account.automation_executions.where("started_at >= ?", @from_date).where(state: "succeeded").count,
      csat_responses:       @account.csat_responses.where("created_at >= ?", @from_date).count,
      csat_average:         (@account.csat_responses.where("created_at >= ?", @from_date).average(:score) || 0).to_f.round(2),
      conversations_total:  @account.conversations.where("created_at >= ?", @from_date).count,
      handoffs_open:        @account.handoffs.where(state: "open").count
    }
  end
end