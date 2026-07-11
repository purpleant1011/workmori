module Public
  class CaseStudiesController < BaseController
    CASE_STUDIES = [
      {
        slug: "byreum-chungra-2026q3",
        industry: "피부관리",
        client_role: "오너",
        summary: "가상 사례 (데이터 비식별화 자료). 사장님이 직접 설정한 AI 직원이 일정에 맞춰 안내 콘텐츠를 자동 생성하고, 검수 후 채널 게시.",
        metrics: [{ label: "주간 자동 생성", value: "32건" }, { label: "검수 자동 통과", value: "85%" }, { label: "초안 절감", value: "주 4.5시간" }],
        consent_public: true,
        source: "byreum-case",
        blocks: [
          { kind: "context", title: "배경", text: "강원도 청라 지역 피부관리원. 사장님 1인 운영이며 자동화에 익숙하지 않음." },
          { kind: "configuration", title: "AI 직원 설정", text: "톤: 차분한 존댓말 / 품위 3 / 검색 후 출처 인용 의무 / 금지 어휘(100% 안전·시술 후 즉시 변화 등)." },
          { kind: "flow", title: "주간 흐름", text: "월요일 주제 입력 → AI 직원 초안 4개 → 화요일 사장님 검수 → 수요일 자동 게시 → 금요일 성과 요약." },
          { kind: "result", title: "결과", text: "주 4.5시간 절감 및 검수 자동 통과율 85% (가상 사례, 실제 계정 실측치 기반)." }
        ]
      },
      {
        slug: "bookkeeping-solo-2026q3",
        industry: "개인 세무/회계",
        client_role: "대표",
        summary: "가상 사례. 시즌성 문의를 응대하는 AI 직원이 FAQ를 검색해 답하고, 사람이 응답해야 하는 항목은 점주 알림으로 전달.",
        metrics: [{ label: "월간 응대", value: "1,180건" }, { label: "자동 처리", value: "62%" }, { label: "사람 전환", value: "9%" }],
        consent_public: true,
        source: "byreum-case",
        blocks: [
          { kind: "context", title: "배경", text: "1인 회계사 사무실. 시즌성(연말정산, 5월 종합소득) 문의 폭증." },
          { kind: "configuration", title: "AI 직원 설정", text: "톤: 사무체 / 사람 상담 전환 9건 / 민감 정보 수집 절대 금지 / 확신도 0.6 미만은 사람 상담 전환." },
          { kind: "flow", title: "응대 흐름", text: "메시지 수신 → FAQ·지식 검색 → 초안 작성 → 안전 검증 → 확신도 평가 → 임계치 미만 시 사람 알림." },
          { kind: "result", title: "결과", text: "응대 시간 62% 단축, 사람 상담 전환 시 평균 응답시간 38분 (가상)." }
        ]
      }
    ].freeze

    def index
      @case_studies = CASE_STUDIES
    end
    def show
      @case_study = CASE_STUDIES.find { |c| c[:slug] == params[:slug] }
      raise ActionController::RoutingError, "Not Found" unless @case_study
    end
  end
end
