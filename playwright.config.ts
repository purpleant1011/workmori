import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright E2E config — WorkMori
 *
 *   npx playwright test                 # 모든 시나리오 실행
 *   npx playwright test --grep "signup" # 특정 시나리오만
 *   npx playwright test --headed        # 브라우저 보면서
 *   npx playwright show-report          # HTML 리포트
 */
export default defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: false,        // 사업자/플랫폼 동시 로그인 시 충돌 방지
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never' }]],

  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:3001',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    locale: 'ko-KR',
    timezoneId: 'Asia/Seoul',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});