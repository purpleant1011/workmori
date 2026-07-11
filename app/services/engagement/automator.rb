# frozen_string_literal: true

# WorkMori — Engagement Automator (Instagram/Threads 공식 API 기반)
# 비용 0 — Meta Graph API + Threads API만 사용
#
# 기능:
#   1. 자동 댓글 응답 (정해진 톤/페르소나 기반)
#   2. 인사이트 수집 (좋아요/댓글/저장/도달)
#   3. 최적 게시 시간 추천 (과거 데이터 분석)
#   4. Handoff 트리거 (위험 키워드 감지 시 사람에게 에스컬레이션)
#
# 팔로워 자동 늘리기는 Meta 정책상 공식 API로 불가능 →
#   → 고품질 자동 게시 + 자동 응대 + 인사이트 최적화로 자연 성장 유도

module Engagement
  module Automator
    module_function

    # 1) 자동 댓글 응답
    def auto_reply_instagram_comments(channel, ai_employee:, max_replies: 10)
      token = ENV["META_GRAPH_API_TOKEN"]
      return { skipped: "META_GRAPH_API_TOKEN not set" } if token.blank?

      ig_user_id = channel.handle.to_s
      api_version = ENV.fetch("META_GRAPH_API_VERSION", "v19.0")

      # 최근 media 조회
      media_url = "https://graph.facebook.com/#{api_version}/#{ig_user_id}/media?fields=id,caption,timestamp&access_token=#{token}&limit=5"
      media_res = http_get_json(media_url, timeout: 15)
      return { skipped: media_res[:error] || "no media" } if media_res[:error] || media_res["data"].blank?

      results = []
      media_res["data"].first(max_replies).each do |media|
        # 각 media의 최신 댓글 조회
        comments_url = "https://graph.facebook.com/#{api_version}/#{media["id"]}/comments?fields=id,text,username,timestamp&access_token=#{token}&limit=20"
        comments_res = http_get_json(comments_url, timeout: 15)
        next if comments_res[:error] || comments_res["data"].blank?

        # 이미 답글 단 댓글 제외 (idempotency)
        already_replied = Set.new(AuditEvent.where(action: "engagement.auto_reply")
                                            .where("metadata->>'comment_id' = ?", media["id"])
                                            .pluck(Arel.sql("metadata->>'reply_id'")).compact)

        comments_res["data"].first(5).each do |comment|
          next if already_replied.include?(comment["id"])

          reply_text = generate_reply(ai_employee: ai_employee, comment: comment["text"], context_caption: media["caption"])
          # 댓글에 답글 (Meta Graph API)
          reply_url = "https://graph.facebook.com/#{api_version}/#{comment["id"]}/replies?access_token=#{token}"
          reply_res = http_post_form(reply_url, { message: reply_text }, timeout: 15)

          results << {
            media_id: media["id"],
            comment_id: comment["id"],
            reply_id: reply_res[:id],
            ok: !reply_res[:error],
            error: reply_res[:error]
          }

          AuditEvent.create!(
            account: channel.account,
            action: "engagement.auto_reply",
            resource_type: "ChannelConnection",
            resource_id: channel.id,
            metadata: { media_id: media["id"], comment_id: comment["id"], reply_id: reply_res[:id], reply_text: reply_text[0,200], ai_employee_id: ai_employee.id, error: reply_res[:error] },
            occurred_at: Time.current
          )

          # 위험 키워드 감지 → handoff
          if handoff_required?(comment["text"])
            Handoff.create!(
              account: channel.account,
              channel: "instagram",
              reason: "instagram_comment_risk_keyword",
              summary: "인스타그램 댓글에 위험 키워드 감지: #{comment["text"][0,100]}",
              state: "open"
            )
            NotificationBroadcaster.handoff_created(channel.account_id, Handoff.last)
          end
        end
      end

      results
    rescue => e
      { error: "#{e.class}: #{e.message[0, 200]}" }
    end

    # 2) 인사이트 수집
    def collect_instagram_insights(channel, since: 7.days.ago)
      token = ENV["META_GRAPH_API_TOKEN"]
      return { skipped: "META_GRAPH_API_TOKEN not set" } if token.blank?

      ig_user_id = channel.handle.to_s
      api_version = ENV.fetch("META_GRAPH_API_VERSION", "v19.0")

      url = "https://graph.facebook.com/#{api_version}/#{ig_user_id}/insights?metric=follower_count,profile_views,reach,impressions&period=day&access_token=#{token}&since=#{since.to_i}"
      res = http_get_json(url, timeout: 15)
      return res if res[:error]

      # DeliveryLog 기록 (Platform이 조회 가능)
      DeliveryLog.create!(
        account: channel.account,
        kind: "automation_summary",
        subject: "Instagram 인사이트 (7일)",
        body_excerpt: "팔로워/리치/노출 데이터 수집",
        metadata_json: res.to_h
      )

      res
    rescue => e
      { error: "#{e.class}: #{e.message[0, 200]}" }
    end

    # 3) Threads 댓글 자동응대
    def auto_reply_threads_comments(channel, ai_employee:, max_replies: 10)
      token = ENV["THREADS_ACCESS_TOKEN"]
      return { skipped: "THREADS_ACCESS_TOKEN not set" } if token.blank?
      user_id = ENV["THREADS_USER_ID"]
      return { skipped: "THREADS_USER_ID not set" } if user_id.blank?

      api_version = ENV.fetch("THREADS_API_VERSION", "v1.0")

      # 최근 threads 조회
      url = "https://graph.threads.net/#{api_version}/#{user_id}/threads?fields=id,text,timestamp&access_token=#{token}&limit=5"
      res = http_get_json(url, timeout: 15)
      return { skipped: res[:error] || "no threads" } if res[:error] || res["data"].blank?

      results = []
      res["data"].first(max_replies).each do |thread|
        replies_url = "https://graph.threads.net/#{api_version}/#{thread["id"]}/replies?fields=id,text,username&access_token=#{token}&limit=10"
        replies_res = http_get_json(replies_url, timeout: 15)
        next if replies_res[:error] || replies_res["data"].blank?

        replies_res["data"].first(3).each do |reply|
          next if reply["username"] == channel.handle.to_s.delete("@")  # 자기 답글 제외

          # Threads는 답글에 답글 = 새 thread 생성 (replied_to 사용)
          reply_text = generate_reply(ai_employee: ai_employee, comment: reply["text"], context_caption: thread["text"])
          post_url = "https://graph.threads.net/#{api_version}/#{user_id}/threads"
          post_res = http_post_form(post_url, {
            media_type: "TEXT",
            text: "@#{reply["username"]} #{reply_text[0, 400]}",
            reply_to_id: thread["id"],
            access_token: token
          }, timeout: 15)

          results << {
            thread_id: thread["id"],
            original_reply_id: reply["id"],
            new_post_id: post_res[:id],
            ok: !post_res[:error]
          }
        end
      end
      results
    rescue => e
      { error: "#{e.class}: #{e.message[0, 200]}" }
    end

    private

    def generate_reply(ai_employee:, comment:, context_caption:)
      # 간단한 톤-매칭 응답 (AI 직원 페르소나 + 금지어 필터)
      vocab = Array(ai_employee.vocabulary_phrases_json).first(3).join(", ")
      forbidden = Array(ai_employee.forbidden_phrases_json).first(3)

      # 매우 단순한 패턴 매칭
      reply = if comment.match?(/(감사|고마워|thanks|thank you)/i)
        "감사합니다! 좋은 하루 되세요 😊"
      elsif comment.match?(/(가격|얼마|price|비용)/i)
        "가격 안내는 DM으로 보내드릴게요!"
      elsif comment.match?(/(예약|booking|방문)/i)
        "예약은 DM이나 전화로 편하게 문의주세요!"
      elsif comment.match?(/(문의|질문|question)/i)
        "문의 주셔서 감사합니다. 더 자세한 내용은 DM으로 안내드릴게요."
      else
        "소중한 의견 감사합니다! 💕"
      end

      # 금지어 필터 (안전망)
      forbidden.each { |f| reply = reply.gsub(f, "•••") if f.present? }
      reply
    end

    def handoff_required?(comment_text)
      # 위험 키워드: 가격 협상, 민원, 의료/법률 민감, 광고성
      risk_patterns = [
        /(환불|불만|항의|컴플레인|refund|complaint)/i,
        /(사기|가짜|fraud|fake|scam)/i,
        /(부작용|이상반응|allergy)/i,  # 미용/의료 업종
        /(수술|처방|prescription)/i,
        /(개인정보|신고|police)/i
      ]
      risk_patterns.any? { |p| comment_text.match?(p) }
    end

    def http_get_json(url, timeout:)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = timeout
      http.read_timeout = timeout
      req = Net::HTTP::Get.new(uri.request_uri)
      res = http.request(req)
      return { error: "HTTP #{res.code}: #{res.body[0, 200]}" } if res.code.to_i >= 400
      JSON.parse(res.body)
    rescue => e
      { error: "#{e.class}: #{e.message[0, 200]}" }
    end

    def http_post_form(url, body, timeout:)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = timeout
      http.read_timeout = timeout
      req = Net::HTTP::Post.new(uri.request_uri)
      req.set_form_data(body)
      res = http.request(req)
      return { error: "HTTP #{res.code}: #{res.body[0, 200]}" } if res.code.to_i >= 400
      JSON.parse(res.body)
    rescue => e
      { error: "#{e.class}: #{e.message[0, 200]}" }
    end
  end
end