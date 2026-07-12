# frozen_string_literal: true

# Antigravity::SessionsController — Antigravity CLI OAuth 인증 상태 확인 + 재인증 안내 (P3, 2026-07-12)
# agy CLI 는 자체적으로 OAuth 처리 (브라우저 띄우고 ~/.gemini/oauth_creds.json 저장)
# 우리는 그 결과를 워커를 통해 확인만 함
module Antigravity
  class SessionsController < ApplicationController
    # GET /antigravity/status
    def status
      cli_version = run_command("agy --version 2>&1").strip
      auth_status = check_auth_status

      render json: {
        cli_installed: cli_version.present?,
        cli_version: cli_version,
        auth_status: auth_status,
        auth_url: "https://accounts.google.com/o/oauth2/v2/auth?client_id=...(agy CLI 가 자동 처리)",
        reauth_command: "agy -p '인증 상태 확인' (브라우저 자동 오픈)",
        feature_flag: {
          antigravity_cli_enabled: FeatureFlags.enabled?(:antigravity_cli_enabled),
          sohee_gemini_provider_active: FeatureFlags.enabled?(:sohee_gemini_provider_active)
        }
      }
    end

    # GET /antigravity/login
    def login
      # agy CLI 가 자체 OAuth flow 실행 (브라우저 자동 오픈 → 토큰 저장)
      # 사용자가 직접 터미널에서 실행하도록 안내
      output = run_command("agy -p '인증 테스트' 2>&1", timeout: 30)

      render json: {
        action: "antigravity_login",
        command: "agy -p '인증 테스트'",
        result: output[0, 1000],
        next_step: "브라우저에서 Google 계정 인증을 완료해 주세요."
      }
    end

    private

    def run_command(cmd, timeout: 10)
      require "open3"
      stdout, _stderr, _status = Open3.capture3(*cmd.split(/\s+/))
      stdout
    rescue StandardError => e
      "(error) #{e.message}"
    end

    def check_auth_status
      creds_path = File.expand_path("~/.gemini/oauth_creds.json")
      return { authenticated: false, reason: "credentials not found" } unless File.exist?(creds_path)

      creds = JSON.parse(File.read(creds_path))
      has_token = creds["access_token"].to_s.length > 50
      { authenticated: has_token, scopes: creds["scope"]&.split(" ")&.size }
    rescue StandardError => e
      { authenticated: false, reason: e.message }
    end
  end
end
