import { test, expect } from '@playwright/test';

/**
 * 공개 사이트 핵심 여정 (3차 리뉴얼 정책)
 * 핵심 CTA = "초기 도입 상담 신청하기" → /contact
 * 회원가입 셀프 흐름은 /signup 노출 + 14일 무료 체험 안내
 */

test.describe('공개 사이트 스모크', () => {
  test('랜딩 페이지가 200 + 핵심 CTA 노출', async ({ page, baseURL }) => {
    const isGhPages = baseURL?.includes('github.io');
    const url = isGhPages ? `${baseURL}/` : '/';
    const res = await page.goto(url);
    expect(res?.status()).toBe(200);
    if (isGhPages) {
      // GitHub Pages landing: "초기 도입 상담 신청하기"
      const cta = page.locator('text=/초기 도입 상담 신청/').first();
      await expect(cta).toBeVisible();
    } else {
      // 백엔드 landing: "초기 도입 상담 신청하기" 또는 contact 링크
      const cta = page.locator('a[href="/contact"], a[href*="contact"]').first();
      await expect(cta).toBeVisible();
    }
  });

  test('가격 페이지 핵심 섹션 표시 (정식 가격 정책 준비 중)', async ({ page }) => {
    await page.goto('/pricing');
    const body = await page.locator('body').textContent();
    expect(body).toMatch(/가격|요금|준비|협의/i);
    // 가격(원/월) 직접 표기 금지
    expect(body).not.toMatch(/월\s*\d{1,3}(,\d{3})*\s*원/);
  });

  test('셀프 회원가입 흐름 — /signup 정상 노출 + 14일 체험 안내', async ({ page, baseURL }) => {
    // 2026-07-12 변경: 셀프 가입 정책으로 전환 → /signup 정상 노출 확인
    const url = baseURL?.includes('github.io') ? `${baseURL}/signup` : '/signup';
    const res = await page.goto(url);
    expect(res?.status()).toBeGreaterThanOrEqual(200);
    await page.waitForLoadState('networkidle');
    const body = await page.locator('body').textContent();
    // /signup에 사업자/사업장/14일/trial 중 하나 이상 노출
    expect(body).toMatch(/사업자|사업장|14일|trial/i);
  });

  test('/app/login에 회원가입 CTA 노출', async ({ page, baseURL }) => {
    const url = baseURL?.includes('github.io') ? `${baseURL}/app/login` : '/app/login';
    await page.goto(url);
    // 회원가입 링크가 노출되고 /signup으로 연결
    const link = page.getByRole('link', { name: /셀프 회원가입|14일 무료 체험/i }).first();
    await expect(link).toBeVisible();
  });
});

test.describe('공개 사이트 위험 노출 방지', () => {
  test('운영사 이름/임시 도메인/데모계정이 공개 페이지에 노출되지 않음', async ({ page, request, baseURL }) => {
    const urls = ['/', '/pricing', '/case-studies', '/industries', '/contact', '/p/terms', '/p/privacy'];
    for (const path of urls) {
      const res = await page.goto(`${baseURL}${path}`);
      expect(res?.status()).toBe(200);
      const body = await page.locator('body').textContent();
      expect(body).not.toMatch(/바이름|청라|이아름|퍼플앤트|김선영|byreum|chungra/);
      expect(body).not.toMatch(/hello@soheeproject\.example|owner@demo\.example/);
      expect(body).not.toMatch(/trycloudflare|ngrok-free\.dev/);
    }
  });
});