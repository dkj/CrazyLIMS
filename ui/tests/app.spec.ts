import { test, expect } from "@playwright/test";

test.describe("Operations console smoke test", () => {
  test("allows persona selection and shows navigation", async ({ page }) => {
    await page.route("**/api/**", async (route) => {
      await route.fulfill({
        status: 200,
        body: "[]",
        headers: {
          "content-type": "application/json"
        }
      });
    });

    await page.goto("/");

    await expect(
      page.getByRole("heading", { level: 1, name: "CrazyLIMS – Operations Console" })
    ).toBeVisible();
    await expect(page.getByText("Select a persona to begin")).toBeVisible();

    await page.selectOption("#persona", "admin");

    await page.waitForURL("**/overview");

    await expect(page.getByText("Select a persona to begin")).toBeHidden();
    await expect(page.getByRole("navigation", { name: "Sections" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Overview" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Samples" })).toBeVisible();
    await expect(page.getByText("Active roles: app_admin, app_operator")).toBeVisible();
  });
});
