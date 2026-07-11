module Public
  class PagesController < BaseController
    LEGAL = {
      "terms"        => { title: "이용약관", body: "본 약관은 가칭 워크모리 서비스의 이용 조건을 정의합니다." },
      "privacy"      => { title: "개인정보처리방침", body: "수집 항목 / 보유 기간 / 제3자 제공 / 파기 절차를 명시합니다." },
      "marketing"    => { title: "마케팅 정보 수신 동의", body: "선택 동의 항목이며, 거부 시에도 서비스 이용에 제한이 없습니다." },
      "cookies"      => { title: "쿠키 정책", body: "필수/분석 쿠키 구분 및 거부 방법을 안내합니다." },
      "data-policy"  => { title: "데이터 보관 및 소유권", body: "고객이 최종 사용한 콘텐츠는 고객 귀속 / 시스템·자동화·프롬프트·소스코드는 퍼플앤트 귀속." }
    }.freeze

    def show
      slug = params[:slug]
      @page = LEGAL[slug]
      raise ActionController::RoutingError, "Not Found" unless @page
    end
  end
end
