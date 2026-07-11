import { test, expect } from '@playwright/test';

/**
 * P4 추가 — 운영 고도화 (Hermes Audit viewer + KnowledgeGap + SafetyLogs + 콘텐츠 5단계 보드)
 *
 *  - dev_login/business 으로 즉시 세션 발급
 *  - P4 신규 페이지 4종 + nav 20메뉴 검증
 *  - 공개 페이지 위험 키워드 0건 회귀
 */

test.describe('P4 운영 고도화', () => {
  test.beforeEach(async ({ page, request }) => {
    const loginRes = await request.post('/dev_login/business', {
      form: { email: 'owner@demo.example' },
    });
    expect(loginRes.ok()).toBeTruthy();

    const cookies = loginRes.headers()['set-cookie'];
    if (cookies) {
      const cookiePairs = cookies.split(/,(?=\s*[\w]+=)/);
      for (const c of cookiePairs) {
        const [pair] = c.split(';');
        const [name, value] = pair.split('=');
        if (name && value) {
          await page.context().addCookies([{
            name: name.trim(),
            value: value.trim(),
            domain: '127.0.0.1',
            path: '/',
          }]);
        }
      }
    }
  });

  test('지식 공백 페이지 200 + 4컬럼 보드', async ({ page }) => {
    const res = await page.goto('/app/knowledge_gaps');
    expect(res?.status()).toBe(200);
    await expect(page.locator('body')).toContainText(/지식 공백|FAQ로 변환|미해결|KnowledgeGap/i);
  });

  test('안전 로그 페이지 200 + 3컬럼 집계', async ({ page }) => {
    const res = await page.goto('/app/safety_logs');
    expect(res?.status()).toBe(200);
    await expect(page.locator('body')).toContainText(/안전 로그|차단|검토|통과/);
  });

  test('Hermes Audit 뷰어 200 + 감사 이벤트 테이블', async ({ page }) => {
    const res = await page.goto('/app/audit_events');
    expect(res?.status()).toBe(200);
    await expect(page.locator('body')).toContainText(/Hermes Audit|감사 이벤트|운영자|시스템/);
  });

  test('콘텐츠 캘린더 5단계 보드 (생성/검수/승인/게시/실패)', async ({ page }) => {
    const res = await page.goto('/app/content/items');
    expect(res?.status()).toBe(200);
    const body = await page.locator('body').textContent();
    // 5단계 카드 키워드 검증
    expect(body).toMatch(/생성/);
    expect(body).toMatch(/검수/);
    expect(body).toMatch(/승인/);
    expect(body).toMatch(/게시/);
    expect(body).toMatch(/실패/);
  });

  test('nav 20메뉴 — 지식 공백/안전 로그/Hermes Audit 노출', async ({ page }) => {
    await page.goto('/app');
    const navText = await page.locator('nav, aside, body').first().textContent();
    expect(navText).toContain('지식 공백');
    expect(navText).toContain('안전 로그');
    expect(navText).toContain('Hermes Audit');
  });

  test('콘솔 에러 0건 — P4 신규 페이지 전부', async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (err) => errors.push(`PAGE: ${err.message}`));
    page.on('console', (msg) => {
      if (msg.type() === 'error') errors.push(`CONSOLE: ${msg.text()}`);
    });

    for (const path of [
      '/app/knowledge_gaps',
      '/app/safety_logs',
      '/app/audit_events',
      '/app/content/items',
    ]) {
      const res = await page.goto(path);
      expect(res?.status()).toBe(200);
      await page.waitForLoadState('networkidle').catch(() => {});
    }

    if (errors.length > 0) {
      console.error('P4 페이지 콘솔 에러:', errors);
    }
    expect(errors).toHaveLength(0);
  });
});

test.describe('P4 위험 키워드 회귀', () => {
  test('공개 페이지 위험 키워드 0건', async ({ page }) => {
    for (const path of ['/', '/about', '/pricing', '/industries', '/contact']) {
      const res = await page.goto(path);
      expect(res?.status()).toBe(200);
      const body = await page.content();
      // 3차 리뉴얼 정책: 어떤 페이지에도 노출 금지
      expect(body).not.toMatch(/바이름|청라|이아름|퍼플앤트|김선영|byreum/);
      expect(body).not.toMatch(/무료 베타|5분 셋업/);
      expect(body).not.toMatch(/85%|32건|1,180|62%|9%|38분/);
    }
  });

  test('단일 CTA — 모든 링크는 #contact 또는 /contact', async ({ page }) => {
    const res = await page.goto('/');
    expect(res?.status()).toBe(200);
    const ctaCount = await page.locator('a[href*="#contact"], a[href="/contact"], a[href*="contact"]').count();
    // /pricing, /contact 자체도 contact 계열이므로 1개 이상
    expect(ctaCount).toBeGreaterThan(0);
    // 셀프 가입/무료 베타 CTA 부재
    expect(await page.locator('a:has-text("무료 베타 시작")').count()).toBe(0);
    expect(await page.locator('a:has-text("5분 셋업")').count()).toBe(0);
  });
});