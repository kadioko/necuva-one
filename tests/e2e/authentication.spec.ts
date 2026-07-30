import { expect, test } from "@playwright/test";

test("redirects anonymous users away from protected workspace routes", async ({ page }) => {
  await page.goto("/erp");
  await expect(page).toHaveURL(/\/auth\/login$/);
  await expect(page.getByRole("heading", { name: "Login" })).toBeVisible();
});

test("shows password confirmation errors before account creation", async ({ page }) => {
  await page.goto("/auth/sign-up");
  await page.getByLabel("Email").fill(`mismatch-${Date.now()}@example.test`);
  await page.getByLabel("Password", { exact: true }).fill("StrongPassword2026!");
  await page.getByLabel("Repeat Password").fill("DifferentPassword2026!");
  await page.getByRole("button", { name: "Create an account" }).click();
  await expect(page.getByText("Passwords do not match")).toBeVisible();
});

test("creates a local user and grants access to protected pages", async ({ page }) => {
  const email = `e2e-${Date.now()}-${Math.round(Math.random() * 10_000)}@example.test`;
  const password = "StrongPassword2026!";

  await page.goto("/auth/sign-up");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password", { exact: true }).fill(password);
  await page.getByLabel("Repeat Password").fill(password);
  await page.getByRole("button", { name: "Create an account" }).click();
  await expect(page).toHaveURL(/\/auth\/sign-up-success$/);

  await page.goto("/protected");
  await expect(page.getByText("This is a protected page that you can only see as an authenticated user")).toBeVisible();
});
