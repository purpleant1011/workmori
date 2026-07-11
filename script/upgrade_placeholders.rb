#!/usr/bin/env ruby
# placeholder view들을 실제 데이터 렌더링 view로 일괄 변환
# 컨트롤러가 제공하는 @instance variables를 추론해서 기본 view 생성

require "fileutils"
require "active_support/all"

WORKMORI_ROOT = "/Users/hochari/develop/workmori"
APP_VIEWS = File.join(WORKMORI_ROOT, "app/views/app")

# 컨트롤러별 @instance vars 매핑 (수동)
CONTROLLER_VARS = {
  "app/controllers/app/settings_controller.rb" => { show: { primary: nil, instance_vars: { flash_notice: nil } } },
  "app/controllers/app/business_profiles_controller.rb" => { show: { primary: "@profile" }, edit: { primary: "@profile" }, update: { primary: "@profile" } },
  "app/controllers/app/products_controller.rb" => { show: { primary: "@product" } },
  "app/controllers/app/deletion_requests_controller.rb" => { index: { primary: "@requests" }, show: { primary: "@req" }, new: { primary: "@req" } },
  "app/controllers/app/plans_controller.rb" => { index: { primary: nil } },
  "app/controllers/app/referrals_controller.rb" => { index: { primary: nil } },
  "app/controllers/app/terminations_controller.rb" => { new: { primary: nil } },
  "app/controllers/app/ai_employees_controller.rb" => { index: { primary: "@ai_employees" }, edit: { primary: "@ai_employee" }, show: { primary: "@ai_employee" } },
  "app/controllers/app/knowledge_sources_controller.rb" => { index: { primary: "@ks" }, show: { primary: "@ks" } },
  "app/controllers/app/data_exports_controller.rb" => { new: { primary: nil } },
  "app/controllers/app/conversations_controller.rb" => { index: { primary: "@conversations" }, show: { primary: "@conv" } },
  "app/controllers/app/automation_rules_controller.rb" => { dashboard: { primary: "@rules" } },
  "app/controllers/app/automation_executions_controller.rb" => { index: { primary: "@execs" }, show: { primary: "@exec" } },
  "app/controllers/app/services_controller.rb" => { index: { primary: "@services" }, show: { primary: "@service" } },
  "app/controllers/app/reports_controller.rb" => { show: { primary: nil } },
  "app/controllers/app/handoffs_controller.rb" => { index: { primary: "@handoffs" }, show: { primary: "@handoff" } },
}

placeholder_files = Dir.glob(File.join(APP_VIEWS, "**/*.erb")).select do |f|
  File.read(f).include?("자동 placeholder")
end

puts "Found #{placeholder_files.size} placeholder files"

placeholder_files.each do |f|
  rel = f.sub("#{APP_VIEWS}/", "")
  view_name = File.basename(f, ".html.erb")
  sub = File.dirname(f).sub(APP_VIEWS, "")
  controller = "app/controllers#{sub}_controller.rb"
  vars = CONTROLLER_VARS.dig(controller, view_name.to_sym) || {}

  # 한국어 title 자동 생성
  title = rel.gsub("/", " · ").gsub("_", " ").gsub(/show|index|edit|new|update|dashboard/, "").strip
  title = title.empty? ? "WorkMori" : title

  content = "<% content_for(:title, \"#{title} — WorkMori\") %>\n\n"
  content += "<header class=\"mb-6\">\n"
  content += "  <h1 class=\"text-2xl font-bold text-slate-900\">#{title}</h1>\n"
  content += "  <p class=\"mt-1 text-sm text-slate-500\">이 화면은 곧 실제 데이터로 채워집니다. 페이지를 확인한 뒤 개선 사항을 알려주세요.</p>\n"
  content += "</header>\n\n"

  primary = vars[:primary]
  if primary
    content += "<% if #{primary}.nil? || (defined?(#{primary}.empty?) && #{primary}.empty?) %>\n"
    content += "  <div class=\"rounded-md border border-dashed border-slate-300 bg-slate-50 px-6 py-12 text-center\">\n"
    content += "    <p class=\"text-sm text-slate-500\">아직 표시할 데이터가 없습니다.</p>\n"
    content += "  </div>\n"
    content += "<% else %>\n"
    content += "  <pre class=\"rounded-md bg-slate-50 border border-slate-200 p-4 text-xs text-slate-700 overflow-auto\"><%= JSON.pretty_generate(#{primary}.respond_to?(:attributes) ? #{primary}.attributes : #{primary}.map { |x| x.attributes }) %></pre>\n"
    content += "<% end %>\n"
  else
    content += "<div class=\"rounded-md border border-dashed border-slate-300 bg-slate-50 px-6 py-12 text-center\">\n"
    content += "  <p class=\"text-sm text-slate-500\">이 화면은 준비 중입니다.</p>\n"
    content += "</div>\n"
  end

  File.write(f, content)
  puts "  ✓ #{rel}"
end

puts "Done."