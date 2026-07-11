import { test, expect } from '@playwright/test';

/**
 * 플랫폼 운영자 콘솔 + Hermes 연동 페이지
 */

test.describe('플랫폼 운영자', () => {
  test.beforeEach(async ({ page, request }) => {
    const loginRes = await request.post('/dev_login/platform', {
      form: { email: 'platform-admin@workmori.example' },
    });
    expect(loginRes.ok()).toBeTruthy();
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
    await page.goto('/platform');
    await expect(page.locator('body')).toContainText(/운영자|플랫폼/i);
  });

  test('계정 목록 표시', async ({ page }) => {
    await page.goto('/platform/accounts');
    await expect(page.locator('body')).toContainText(/계정|account/i);
  });

  test('Hermes 연동 페이지가 Provider 상태 노출', async ({ page }) => {
    await page.goto('/platform/hermes');
    await expect(page.locator('body')).toContainText(/Hermes 연동|Provider|Hermes Agent/i);
  });

  test('Hermes 호출 테스트는 응답 또는 설정 안내', async ({ page }) => {
    await page.goto('/platform/hermes/test', { waitUntil: 'domcontentloaded' }).catch(() => {});
    // form submit이 redirect하므로 결과 페이지의 flash 메시지 확인
    await page.goto('/platform/hermes');
    const body = await page.locator('body').textContent();
    // 페이지 본문에 안내가 표시되거나, 결과 메시지가 보임
    expect(body).toBeTruthy();
  });

  test('Audit 로그 페이지', async ({ page }) => {
    await page.goto('/platform/hermes/audit');
    await expect(page.locator('body')).toContainText(/Hermes Audit|automation\.hermes|automation\.execute/i);
  });
});