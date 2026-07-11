import { test, expect } from "@playwright/test";

// /app/login 사업자 로그인 + 비밀번호 변경 사이클 검증
// 바이름 신규 사업자 계정 (byreum@soheeproject.example / pass1234!!)

test.describe("byreum 신규 사업자 — 로그인 + 비밀번호 변경", () => {
  const EMAIL = "byreum@soheeproject.example";
  const ORIGINAL_PW = "pass1234!!";
  const NEW_PW = "ByreumNew!2026";

  test("1) /app/login GET — 로그인 폼 노출", async ({ page, baseURL }) => {
    const res = await page.goto(`${baseURL}/app/login`);
    expect(res?.status()).toBeLessThan(400);
    await expect(page.getByRole("heading", { name: /사업자 로그인/ })).toBeVisible();
    await expect(page.locator('input[name="account_or_email"]')).toBeVisible();
    await expect(page.locator('input[name="password"]')).toBeVisible();
  });

  test("2) POST /app/login — byreum 계정 로그인 성공 → /app 리다이렉트", async ({ page, baseURL }) => {
    await page.goto(`${baseURL}/app/login`);
    await page.locator('input[name="account_or_email"]').fill(EMAIL);
    await page.locator('input[name="password"]').fill(ORIGINAL_PW);
    await page.getByRole("button", { name: "로그인" }).click();
    await page.waitForLoadState("networkidle", { timeout: 10000 });
    await expect.poll(() => page.url(), { timeout: 8000 }).toMatch(/\/app($|\?)/);
    expect(page.url()).not.toContain("/app/login");
  });

  test("3) 잘못된 비밀번호 거부", async ({ page, baseURL }) => {
    await page.goto(`${baseURL}/app/login`);
    await page.locator('input[name="account_or_email"]').fill(EMAIL);
    await page.locator('input[name="password"]').fill("wrong-password");
    await page.getByRole("button", { name: "로그인" }).click();
    await expect(page.locator("body")).toContainText(/올바르지 않습니다|로그인/i);
  });

  test("4) /app/settings 진입 → 비밀번호 변경 링크 노출", async ({ page, baseURL }) => {
    await page.goto(`${baseURL}/app/login`);
    await page.locator('input[name="account_or_email"]').fill(EMAIL);
    await page.locator('input[name="password"]').fill(ORIGINAL_PW);
    await page.getByRole("button", { name: "로그인" }).click();
    await page.waitForLoadState("networkidle", { timeout: 10000 });
    await expect.poll(() => page.url(), { timeout: 8000 }).toMatch(/\/app($|\?)/);

    await page.goto(`${baseURL}/app/settings`);
    await expect(page.getByRole("link", { name: /비밀번호 변경/ })).toBeVisible();
  });

  test("5) /app/settings/password — 비밀번호 변경 후 새 비번 로그인 가능 (원복 포함)", async ({ page, baseURL }) => {
      // 로그인
      await page.goto(`${baseURL}/app/login`);
      await page.locator('input[name="account_or_email"]').fill(EMAIL);
      await page.locator('input[name="password"]').fill(ORIGINAL_PW);
      await page.locator('input[type="submit"]').first().click();
      await page.waitForLoadState("networkidle", { timeout: 10000 });
      await expect.poll(() => page.url(), { timeout: 8000 }).toMatch(/\/app($|\?)/);

      // 비밀번호 변경 페이지
      await page.goto(`${baseURL}/app/settings/password`);
      await expect(page.locator('input[name="password_form[current_password]"]')).toBeVisible();

      // 비밀번호 1차 변경 (ORIGINAL_PW → NEW_PW)
      await page.locator('input[name="password_form[current_password]"]').fill(ORIGINAL_PW);
      await page.locator('input[name="password_form[new_password]"]').fill(NEW_PW);
      await page.locator('input[name="password_form[new_password_confirmation]"]').fill(NEW_PW);
      await page.locator('input[type="submit"][value="비밀번호 변경"]').click();
      await page.waitForLoadState("networkidle", { timeout: 10000 });
      await expect.poll(() => page.url(), { timeout: 8000 }).toMatch(/\/app\/settings\/password/);

      // 로그아웃 (쿠키 삭제)
      await page.context().clearCookies();

      // 옛 비번 로그인 → 실패
      await page.goto(`${baseURL}/app/login`);
      await page.locator('input[name="account_or_email"]').fill(EMAIL);
      await page.locator('input[name="password"]').fill(ORIGINAL_PW);
      await page.locator('input[type="submit"]').first().click();
      await page.waitForLoadState("networkidle", { timeout: 10000 });
      await expect(page.locator("body")).toContainText(/올바르지 않습니다/);

      // 새 비번 로그인 → 성공
      await page.locator('input[name="password"]').fill(NEW_PW);
      await page.locator('input[type="submit"]').first().click();
      await page.waitForLoadState("networkidle", { timeout: 10000 });
      await expect.poll(() => page.url(), { timeout: 8000 }).toMatch(/\/app($|\?)/);
      expect(page.url()).not.toContain("/app/login");

      // 원복 — 다른 비번 변경 (NEW_PW → ORIGINAL_PW)
      await page.goto(`${baseURL}/app/settings/password`);
      await page.locator('input[name="password_form[current_password]"]').fill(NEW_PW);
      await page.locator('input[name="password_form[new_password"]').fill(ORIGINAL_PW);
      await page.locator('input[name="password_form[new_password_confirmation"]').fill(ORIGINAL_PW);
      await page.locator('input[type="submit"][value="비밀번호 변경"]').click();
      await page.waitForLoadState("networkidle", { timeout: 10000 });
      await expect.poll(() => page.url(), { timeout: 8000 }).toMatch(/\/app\/settings\/password/);
    });
});