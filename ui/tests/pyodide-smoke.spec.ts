import { expect, test } from "@playwright/test";

test.describe("Pyodide smoke page", () => {
  test("loads the standalone Pyodide runner", async ({ page }) => {
    test.setTimeout(120000);

    await page.goto("/pyodide-smoke.html");

    await expect(page.getByRole("heading", { name: "Pyodide Smoke Test" })).toBeVisible();

    const status = page.getByTestId("pyodide-status");
    await expect(status).toHaveText(/Running Python expression|Pyodide ready/, {
      timeout: 60000
    });

    const result = page.getByTestId("pyodide-result");
    await expect(result).toHaveText(/Computed value: 140/, { timeout: 60000 });

    await expect(status).toHaveText(/Pyodide ready/, { timeout: 60000 });
  });
});
