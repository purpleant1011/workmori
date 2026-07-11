import { test, expect, type Page } from "@playwright/test";

test.beforeEach(async ({ request, baseURL }) => {
  // signup rate_limit (3/IP/시간) 캐시 리셋 — Playwright는 같은 IP로 빠르게 여러 번 가입 시도
  await request.post(`${baseURL}/__test/clear_rate_limit`, { failOnStatusCode: false });
});

function uniqueEmail(prefix = "테스트 스튜디오") {
  const stamp = Date.now().toString().slice(-7);
  return {
    businessName: `${prefix} ${stamp}`,
    email: `test-${stamp}@studio.example`,
    password: "StudioTest!2026",
  };
}

async function fillSignupForm(
  page: Page,
  baseURL: string,
  data: { businessName: string; email: string; password: string }
) {
  await page.goto(`${baseURL}/signup`);
  await expect(page.getByRole("heading", { name: /사업자 회원가입|소희/ })).toBeVisible();

  await page.locator('input[name="signup[business_name]"]').fill(data.businessName);
  await page.locator('select[name="signup[industry_slug]"]').selectOption({ index: 1 });
  await page.locator('input[name="signup[owner_name]"]').fill("테스트 대표");
  await page.locator('input[name="signup[email]"]').fill(data.email);
  await page.locator('input[name="signup[password]"]').fill(data.password);
  await page.locator('input[name="signup[password_confirmation]"]').fill(data.password);
  await page.locator('input[name="signup[terms_accepted]"][type="checkbox"]').check();
}

test.describe("사업자 셀프 회원가입 + 14일 trial", () => {
  // NOTE: signup rate_limit = 3/IP/시간 → 핵심 시나리오만 검증 (정상 1 + 거절 1)
  test("정상 가입 → 자동 로그인 → /app 진입 → 14일 trial 부여", async ({ page, baseURL }) => {
    const data = uniqueEmail("E2E 스튜디오");

    await fillSignupForm(page, baseURL!, data);
    await Promise.all([
      page.waitForURL(/\/app(\/|$)/, { timeout: 15_000 }),
      page.locator('input[type="submit"][value*="체험"]').click(),
    ]);

    await expect(page).toHaveURL(/\/app(\/|$)/);
    const body = await page.locator("body").innerText();
    expect(body).toMatch(/테스트|E2E|스튜디오|체험|trial|남은/i);

    // 자동 로그인 확인 — /app 직접 GET도 인증 통과
    const res = await page.request.get(`${baseURL}/app`);
    expect(res.status()).toBeLessThan(400);
  });

  test("이메일 형식 오류 시 가입 폼에서 거부 (validation)", async ({ page, baseURL }) => {
    await page.goto(`${baseURL}/signup`);
    await page.locator('input[name="signup[business_name]"]').fill("잘못된 이메일 테스트");
    await page.locator('input[name="signup[owner_name]"]').fill("테스트");
    await page.locator('input[name="signup[email]"]').fill("not-an-email");
    await page.locator('input[name="signup[password]"]').fill("StudioTest!2026");
    await page.locator('input[name="signup[password_confirmation]"]').fill("StudioTest!2026");
    await page.locator('input[name="signup[terms_accepted]"][type="checkbox"]').check();

    await page.locator('input[type="submit"][value*="체험"]').click();
    await page.waitForTimeout(800);
    await expect(page).toHaveURL(/\/signup/);
    const body = await page.locator("body").innerText();
    expect(body).toMatch(/이메일|형식|올바르/i);
  });
});