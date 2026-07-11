# frozen_string_literal: true
require "csv"

module App
  class AnalyticsController < App::BaseController
    def show
      @days = params[:days].to_i
      @days = 30 if @days <= 0
      @days = 365 if @days > 365
      @data = Analytics::Aggregator.call(account: @current_account, days: @days)
      @csat = CsatSummary.call(account: @current_account, since: @days.days.ago)
    end

    def export
      @days = params[:days].to_i
      @days = 30 if @days <= 0
      @days = 365 if @days > 365
      data = Analytics::Aggregator.call(account: @current_account, days: @days)
      csv = build_csv(data)
      send_data csv, filename: "analytics-#{Date.current}.csv", type: "text/csv"
    end

    private

    def build_csv(data)
      require "csv"
      rows = []
      rows << %w[date content_published response_rate conversations_total conversations_responded automation_total automation_succeeded csat_avg csat_responses]

      # Build a quick lookup by date
      rr = data.series_response_rate.each_with_object({}) { |r, h| h[r[:date]] = r }
      ar = data.series_automation_runs.each_with_object({}) { |r, h| h[r[:date]] = r }
      cs = data.series_csat.each_with_object({}) { |r, h| h[r[:date]] = r }

      data.series_published.each do |p|
        d = p[:date]
        rr_d = rr[d] || {}
        ar_d = ar[d] || {}
        cs_d = cs[d] || {}
        rows << [
          d,
          p[:count].to_i,
          rr_d[:rate].to_f,
          rr_d[:total].to_i,
          rr_d[:responded].to_i,
          ar_d[:total].to_i,
          ar_d[:succeeded].to_i,
          cs_d[:avg_score].to_f,
          cs_d[:responses].to_i
        ]
      end
      CSV.generate do |csv|
        rows.each { |r| csv << r }
      end
    end
  end
end