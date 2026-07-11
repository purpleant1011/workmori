import { test, expect } from '@playwright/test';

/**
 * 사업자 로그인 + 핵심 워크플로
 *
 *  - dev_login/business 으로 즉시 로그인 (가장 안정적)
 *  - 핵심 페이지: 대시보드, 상품, FAQ, 자동화 규칙, 보고서
 */

test.describe('사업자 대시보드', () => {
  test.beforeEach(async ({ page, request }) => {
    // dev_login 으로 즉시 세션 쿠키 발급 (CSRF 우회)
    const loginRes = await request.post('/dev_login/business', {
      form: { email: 'owner@demo.example' },
    });
    expect(loginRes.ok()).toBeTruthy();

    // 응답에서 받은 쿠키를 브라우저 컨텍스트에 복사
    const cookies = loginRes.headers()['set-cookie'];
    if (cookies) {
      const cookiePairs = cookies.split(/,(?=\s*[\w]+=)/);
      for (const c of cookiePairs) {
        const [pair] = c.split(';');
        const [name, value] = pair.split('=');
        await page.context().addCookies([{
          name: name.trim(),
          value: value.trim(),
          domain: '127.0.0.1',
          path: '/',
        }]);
      }
    }
  });

  test('대시보드 진입', async ({ page }) => {
    const res = await page.goto('/app');
    expect(res?.status()).toBe(200);
    await expect(page.locator('body')).toContainText(/워크모리|WorkMori|대시보드/i);
  });

  test('상품 목록 페이지', async ({ page }) => {
    await page.goto('/app/products');
    await expect(page.locator('body')).toContainText(/상품|Products|Product/i);
  });

  test('자동화 규칙 페이지', async ({ page }) => {
    await page.goto('/app/automations/rules');
    await expect(page.locator('body')).toContainText(/자동화|규칙/i);
  });

  test('주간 리포트 페이지', async ({ page }) => {
    await page.goto('/app/reports/weekly/1');
    expect(page.url()).toContain('/app/reports/weekly/');
  });

  test('콘솔 에러 0건 검증', async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (err) => errors.push(err.message));
    page.on('console', (msg) => {
      if (msg.type() === 'error') errors.push(msg.text());
    });

    // 주요 페이지 전부 방문
    for (const path of ['/app', '/app/products', '/app/services', '/app/faqs', '/app/channels', '/app/automations/rules']) {
      await page.goto(path);
      await page.waitForLoadState('networkidle').catch(() => {});
    }

    // JS 에러는 허용, 외부 리소스 4xx/5xx는 점검
    const fatalErrors = errors.filter(e => !e.includes('favicon') && !e.includes('cdn.tailwindcss'));
    expect(fatalErrors).toEqual([]);
  });
});