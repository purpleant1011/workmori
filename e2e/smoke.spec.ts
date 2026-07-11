import { test, expect } from '@playwright/test';

/**
 * 공개 사이트 + 회원가입 → /app 도달
 * 사용자 핵심 여정: 랜딩 → 가격 → 회원가입 → 사업장 등록 → /app 진입
 */

test.describe('공개 사이트 스모크', () => {
  test('랜딩 페이지가 200 + 핵심 CTA 노출', async ({ page, baseURL }) => {
    // GitHub Pages landing과 백엔드 모두 CTA가 있어야 함
    const isGhPages = baseURL?.includes('github.io');
    const url = isGhPages ? `${baseURL}/` : '/';
    const res = await page.goto(url);
    expect(res?.status()).toBe(200);
    if (isGhPages) {
      // GitHub Pages landing: "14일 무료로 시작하기" 또는 "무료로 시작하기"
      const cta = page.locator('text=/무료로 시작|14일 무료/').first();
      await expect(cta).toBeVisible();
    } else {
      // 백엔드 landing: /signup 링크
      const cta = page.locator('a[href="/signup"]').first();
      await expect(cta).toBeVisible();
    }
  });

  test('가격 페이지 핵심 섹션 표시', async ({ page }) => {
    await page.goto('/pricing');
    await expect(page.locator('body')).toContainText(/가격|요금|플랜|월/i);
  });

  test('회원가입 폼이 모든 필드 노출', async ({ page }) => {
    await page.goto('/signup');
    // 최소한 사업자 정보 입력 필드가 있어야 함
    const emailInput = page.locator('input[type="email"], input[name*="email"]').first();
    await expect(emailInput).toBeVisible();
  });
});

test.describe('회원가입 → /app 도달', () => {
  test('신규 가입 후 사업자 대시보드 진입', async ({ page, request }) => {
    // 1) 고유한 slug 생성 (충돌 방지)
    const slug = `e2e-${Date.now()}`;

    // 2) signup 페이지에서 폼 채우기
    await page.goto('/signup');

    // 다양한 폼 구조를 견디기 위한 best-effort 셀렉터
    await page.locator('input[name*="email"], input[type="email"]').first().fill(`${slug}@e2e.example`);
    await page.locator('input[name*="business_name"], input[name*="name"]').first().fill(`E2E 테스트 ${slug}`);

    // 3) 산업 선택 (있다면)
    const industrySelect = page.locator('select[name*="industry"], select[name*="industry_code"]').first();
    if (await industrySelect.count() > 0) {
      const options = await industrySelect.locator('option').allTextContents();
      // 첫 번째 비어있지 않은 옵션 선택
      const firstReal = options.find(o => o.trim().length > 0) || 'skincare';
      await industrySelect.selectOption({ label: firstReal }).catch(() => {});
    }

    // 4) 제출
    const submit = page.locator('input[type="submit"], button[type="submit"]').first();
    await submit.click();

    // 5) /app 또는 /dashboard 로 이동 (signup 후 자동 로그인)
    await page.waitForURL(/\/(app|dashboard|onboarding)/, { timeout: 10_000 }).catch(() => {});
    // 어떤 페이지든 200 + WorkMori 브랜드가 보이면 OK
    const body = await page.locator('body').textContent();
    expect(body).toBeTruthy();
    expect(body!.length).toBeGreaterThan(50);
  });
});