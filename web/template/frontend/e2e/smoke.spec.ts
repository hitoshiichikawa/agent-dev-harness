import { expect, test } from "@playwright/test";

test("top page renders", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Examples" })).toBeVisible();
  await page.screenshot({ path: "e2e/screenshots/top.png", fullPage: true });
});
