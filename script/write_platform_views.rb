#!/usr/bin/env ruby
# Platform view 일괄 작성 — new/edit 페이지 (form 포함, 동작 가능)
# 각 리소스마다 적절한 필드 채움

ROOT = "/Users/hochari/develop/workmori/app/views/platform"

def w(rel, body)
  full = File.join(ROOT, rel)
  FileUtils.mkdir_p File.dirname(full)
  File.write(full, body)
  puts "  ✓ #{rel} (#{body.bytesize} bytes)"
end

require 'fileutils'

# === accounts ===
w "accounts/new.html.erb", <<~ERB
  <% content_for(:title, "계정 신규 — WorkMori 플랫폼") %>
  <header class="mb-6">
    <h1 class="text-2xl font-bold text-slate-900">계정 신규</h1>
    <p class="mt-1 text-sm text-slate-500">새 계정을 생성합니다.</p>
  </header>
  <%= form_with model: @account, url: platform_accounts_path, method: :post, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <% if @account.errors.any? %>
      <div class="rounded-md border border-rose-300 bg-rose-50 p-3 text-sm text-rose-700">
        <%= @account.errors.full_messages.to_sentence %>
      </div>
    <% end %>
    <div>
      <%= f.label :name, "이름", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :name, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div>
      <%= f.label :slug, "슬러그", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :slug, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div>
      <%= f.label :status, "상태", class: "block text-sm font-medium text-slate-700" %>
      <%= f.select :status, %w[active suspended cancelled], { include_blank: true }, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div class="flex gap-2">
      <%= f.submit "생성", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_accounts_path, class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

w "accounts/edit.html.erb", <<~ERB
  <% content_for(:title, "계정 수정 — WorkMori 플랫폼") %>
  <header class="mb-6">
    <h1 class="text-2xl font-bold text-slate-900">계정 수정 <span class="text-sm text-slate-500">#<%= @account.id %></span></h1>
  </header>
  <%= form_with model: @account, url: platform_account_path(@account), method: :patch, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <% if @account.errors.any? %>
      <div class="rounded-md border border-rose-300 bg-rose-50 p-3 text-sm text-rose-700">
        <%= @account.errors.full_messages.to_sentence %>
      </div>
    <% end %>
    <div>
      <%= f.label :name, "이름", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :name, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div>
      <%= f.label :slug, "슬러그", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :slug, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div>
      <%= f.label :status, "상태", class: "block text-sm font-medium text-slate-700" %>
      <%= f.select :status, %w[active suspended cancelled], {}, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div class="flex gap-2">
      <%= f.submit "저장", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_account_path(@account), class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

# === feature_flags ===
w "feature_flags/new.html.erb", <<~ERB
  <% content_for(:title, "기능 플래그 신규 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">기능 플래그 신규</h1></header>
  <%= form_with model: @flag, url: platform_feature_flags_path, method: :post, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <% if @flag.errors.any? %>
      <div class="rounded-md border border-rose-300 bg-rose-50 p-3 text-sm text-rose-700">
        <%= @flag.errors.full_messages.to_sentence %>
      </div>
    <% end %>
    <div>
      <%= f.label :key, "키", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :key, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div>
      <%= f.label :enabled, "활성", class: "block text-sm font-medium text-slate-700" %>
      <%= f.check_box :enabled, class: "mt-1" %>
    </div>
    <div>
      <%= f.label :value, "값(JSON)", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_area :value, rows: 4, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm font-mono" %>
    </div>
    <div class="flex gap-2">
      <%= f.submit "생성", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_feature_flags_path, class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

w "feature_flags/edit.html.erb", <<~ERB
  <% content_for(:title, "기능 플래그 수정 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">기능 플래그 수정</h1></header>
  <%= form_with model: @flag, url: platform_feature_flag_path(@flag), method: :patch, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <div>
      <%= f.label :key, "키", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :key, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div>
      <%= f.label :enabled, "활성", class: "block text-sm font-medium text-slate-700" %>
      <%= f.check_box :enabled, class: "mt-1" %>
    </div>
    <div>
      <%= f.label :value, "값(JSON)", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_area :value, rows: 4, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm font-mono" %>
    </div>
    <div class="flex gap-2">
      <%= f.submit "저장", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_feature_flags_path, class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

# === incidents ===
w "incidents/new.html.erb", <<~ERB
  <% content_for(:title, "인시던트 등록 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">인시던트 등록</h1></header>
  <%= form_with model: @incident, url: platform_incidents_path, method: :post, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <% if @incident.errors.any? %>
      <div class="rounded-md border border-rose-300 bg-rose-50 p-3 text-sm text-rose-700">
        <%= @incident.errors.full_messages.to_sentence %>
      </div>
    <% end %>
    <div>
      <%= f.label :title, "제목", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :title, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div>
      <%= f.label :description, "설명", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_area :description, rows: 4, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div class="grid grid-cols-2 gap-3">
      <div>
        <%= f.label :severity, "심각도", class: "block text-sm font-medium text-slate-700" %>
        <%= f.select :severity, %w[sev1 sev2 sev3 sev4], {}, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :state, "상태", class: "block text-sm font-medium text-slate-700" %>
        <%= f.select :state, %w[open investigating resolved], {}, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
    </div>
    <div class="flex gap-2">
      <%= f.submit "등록", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_incidents_path, class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

w "incidents/edit.html.erb", <<~ERB
  <% content_for(:title, "인시던트 수정 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">인시던트 수정 #<%= @incident.id %></h1></header>
  <%= form_with model: @incident, url: platform_incident_path(@incident), method: :patch, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <div>
      <%= f.label :title, "제목", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :title, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div>
      <%= f.label :description, "설명", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_area :description, rows: 4, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div class="grid grid-cols-2 gap-3">
      <div>
        <%= f.label :severity, "심각도", class: "block text-sm font-medium text-slate-700" %>
        <%= f.select :severity, %w[sev1 sev2 sev3 sev4], {}, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :state, "상태", class: "block text-sm font-medium text-slate-700" %>
        <%= f.select :state, %w[open investigating resolved], {}, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
    </div>
    <div class="flex gap-2">
      <%= f.submit "저장", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_incident_path(@incident), class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

# === industries ===
w "industries/new.html.erb", <<~ERB
  <% content_for(:title, "산업 템플릿 신규 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">산업 템플릿 신규</h1></header>
  <%= form_with model: @industry, url: platform_industries_path, method: :post, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <% if @industry.errors.any? %>
      <div class="rounded-md border border-rose-300 bg-rose-50 p-3 text-sm text-rose-700">
        <%= @industry.errors.full_messages.to_sentence %>
      </div>
    <% end %>
    <div class="grid grid-cols-2 gap-3">
      <div>
        <%= f.label :industry_code, "산업 코드", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :industry_code, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :industry_kind, "산업 종류", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :industry_kind, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :slug, "슬러그", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :slug, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :version, "버전", class: "block text-sm font-medium text-slate-700" %>
        <%= f.number_field :version, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
    </div>
    <div>
      <%= f.label :display_name, "표시 이름", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :display_name, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div class="flex gap-2">
      <%= f.submit "생성", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_industries_path, class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

w "industries/edit.html.erb", <<~ERB
  <% content_for(:title, "산업 템플릿 수정 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">산업 템플릿 수정 #<%= @industry.id %></h1></header>
  <%= form_with model: @industry, url: platform_industry_path(@industry), method: :patch, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <div class="grid grid-cols-2 gap-3">
      <div>
        <%= f.label :industry_code, "산업 코드", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :industry_code, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :industry_kind, "산업 종류", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :industry_kind, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :slug, "슬러그", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :slug, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :version, "버전", class: "block text-sm font-medium text-slate-700" %>
        <%= f.number_field :version, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
    </div>
    <div>
      <%= f.label :display_name, "표시 이름", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :display_name, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div class="flex gap-2">
      <%= f.submit "저장", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_industry_path(@industry), class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

# === industry_templates (위와 동일하게 복제) ===
%w[new edit].each do |act|
  src = File.read(File.join(ROOT, "industries/#{act}.html.erb"))
  # action URL만 변경
  out = src
        .gsub("platform_industries_path", "platform_industry_templates_path")
        .gsub("platform_industry_path", "platform_industry_template_path")
        .gsub("산업 템플릿", "산업 템플릿 (industry_templates)")
  w "industry_templates/#{act}.html.erb", out
end
# show/index는 industries와 동일하게
%w[show index].each do |act|
  src = File.read(File.join(ROOT, "industries/#{act}.html.erb"))
  out = src
        .gsub("platform_industries_path", "platform_industry_templates_path")
        .gsub("platform_industry_path", "platform_industry_template_path")
        .gsub("산업 템플릿", "산업 템플릿 (industry_templates)")
  w "industry_templates/#{act}.html.erb", out
end

# === inquiries ===
w "inquiries/new.html.erb", <<~ERB
  <% content_for(:title, "문의 신규 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">문의 신규</h1></header>
  <%= form_with model: @inquiry, url: platform_inquiries_path, method: :post, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <div>
      <%= f.label :subject_kind, "주제 분류", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :subject_kind, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div class="grid grid-cols-2 gap-3">
      <div>
        <%= f.label :status, "상태", class: "block text-sm font-medium text-slate-700" %>
        <%= f.select :status, %w[new replied closed], {}, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :score, "점수", class: "block text-sm font-medium text-slate-700" %>
        <%= f.number_field :score, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
    </div>
    <div class="flex gap-2">
      <%= f.submit "생성", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_inquiries_path, class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

w "inquiries/edit.html.erb", <<~ERB
  <% content_for(:title, "문의 수정 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">문의 수정 #<%= @inquiry.id %></h1></header>
  <%= form_with model: @inquiry, url: platform_inquiry_path(@inquiry), method: :patch, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <div>
      <%= f.label :subject_kind, "주제 분류", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :subject_kind, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div class="grid grid-cols-2 gap-3">
      <div>
        <%= f.label :status, "상태", class: "block text-sm font-medium text-slate-700" %>
        <%= f.select :status, %w[new replied closed], {}, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :score, "점수", class: "block text-sm font-medium text-slate-700" %>
        <%= f.number_field :score, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
    </div>
    <div class="flex gap-2">
      <%= f.submit "저장", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_inquiry_path(@inquiry), class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

# === model_catalog_entries ===
w "model_catalog_entries/new.html.erb", <<~ERB
  <% content_for(:title, "모델 카탈로그 신규 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">모델 카탈로그 신규</h1></header>
  <%= form_with model: @entry, url: platform_model_catalog_entries_path, method: :post, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <div class="grid grid-cols-2 gap-3">
      <div>
        <%= f.label :code, "코드", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :code, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :provider, "공급자", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :provider, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :api_model_name, "API 모델명", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :api_model_name, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :context_window, "컨텍스트 윈도우", class: "block text-sm font-medium text-slate-700" %>
        <%= f.number_field :context_window, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :max_output_tokens, "최대 출력 토큰", class: "block text-sm font-medium text-slate-700" %>
        <%= f.number_field :max_output_tokens, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :active, "활성", class: "block text-sm font-medium text-slate-700" %>
        <%= f.check_box :active, class: "mt-2" %>
      </div>
    </div>
    <div class="flex gap-2">
      <%= f.submit "생성", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_model_catalog_entries_path, class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

w "model_catalog_entries/edit.html.erb", <<~ERB
  <% content_for(:title, "모델 카탈로그 수정 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">모델 카탈로그 수정 #<%= @entry.id %></h1></header>
  <%= form_with model: @entry, url: platform_model_catalog_entry_path(@entry), method: :patch, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <div class="grid grid-cols-2 gap-3">
      <div>
        <%= f.label :code, "코드", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :code, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :provider, "공급자", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :provider, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :api_model_name, "API 모델명", class: "block text-sm font-medium text-slate-700" %>
        <%= f.text_field :api_model_name, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :context_window, "컨텍스트 윈도우", class: "block text-sm font-medium text-slate-700" %>
        <%= f.number_field :context_window, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :max_output_tokens, "최대 출력 토큰", class: "block text-sm font-medium text-slate-700" %>
        <%= f.number_field :max_output_tokens, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
      </div>
      <div>
        <%= f.label :active, "활성", class: "block text-sm font-medium text-slate-700" %>
        <%= f.check_box :active, class: "mt-2" %>
      </div>
    </div>
    <div class="flex gap-2">
      <%= f.submit "저장", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_model_catalog_entry_path(@entry), class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

# === prompt_templates ===
w "prompt_templates/new.html.erb", <<~ERB
  <% content_for(:title, "프롬프트 템플릿 신규 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">프롬프트 템플릿 신규</h1></header>
  <%= form_with model: @template, url: platform_prompt_templates_path, method: :post, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <div>
      <%= f.label :code, "코드", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :code, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div>
      <%= f.label :system_prompt, "시스템 프롬프트", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_area :system_prompt, rows: 3, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm font-mono" %>
    </div>
    <div>
      <%= f.label :body, "본문", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_area :body, rows: 6, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm font-mono" %>
    </div>
    <div>
      <%= f.label :active, "활성", class: "block text-sm font-medium text-slate-700" %>
      <%= f.check_box :active, class: "mt-1" %>
    </div>
    <div class="flex gap-2">
      <%= f.submit "생성", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_prompt_templates_path, class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

w "prompt_templates/edit.html.erb", <<~ERB
  <% content_for(:title, "프롬프트 템플릿 수정 — WorkMori 플랫폼") %>
  <header class="mb-6"><h1 class="text-2xl font-bold text-slate-900">프롬프트 템플릿 수정 #<%= @template.id %></h1></header>
  <%= form_with model: @template, url: platform_prompt_template_path(@template), method: :patch, local: true, class: "space-y-4 max-w-2xl" do |f| %>
    <div>
      <%= f.label :code, "코드", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_field :code, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm" %>
    </div>
    <div>
      <%= f.label :system_prompt, "시스템 프롬프트", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_area :system_prompt, rows: 3, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm font-mono" %>
    </div>
    <div>
      <%= f.label :body, "본문", class: "block text-sm font-medium text-slate-700" %>
      <%= f.text_area :body, rows: 6, class: "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm font-mono" %>
    </div>
    <div>
      <%= f.label :active, "활성", class: "block text-sm font-medium text-slate-700" %>
      <%= f.check_box :active, class: "mt-1" %>
    </div>
    <div class="flex gap-2">
      <%= f.submit "저장", class: "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" %>
      <%= link_to "취소", platform_prompt_template_path(@template), class: "inline-flex items-center rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
    </div>
  <% end %>
ERB

puts "완료: 총 #{Dir.glob(File.join(ROOT, '**/*.html.erb')).size} view files"