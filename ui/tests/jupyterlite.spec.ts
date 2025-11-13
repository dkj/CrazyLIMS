import { expect, test } from "@playwright/test";

test.describe("JupyterLite embedding", () => {
  test("runs python code inside the embedded notebook", async ({ page }) => {
    test.setTimeout(120000);

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

    const personaSelect = page.locator("#persona");
    await personaSelect.waitFor({ timeout: 15000 });
    await personaSelect.selectOption("admin");
    await page.waitForURL("**/overview");

    await page.getByRole("link", { name: "ELN Demo" }).click();
    await page.waitForURL("**/eln/embed-test");

    const notebookIframe = page.locator('iframe[title="Notebook Lite Demo"]');
    await expect(notebookIframe).toBeVisible({ timeout: 20000 });

    const notebookFrameHandle = await notebookIframe.elementHandle();
    if (!notebookFrameHandle) {
      throw new Error("Notebook iframe never attached to the DOM");
    }

    const notebookFrame = await notebookFrameHandle.contentFrame();
    if (!notebookFrame) {
      throw new Error("Unable to resolve the embedded JupyterLite frame");
    }

    await notebookFrame.waitForFunction(
      () => Boolean((globalThis as unknown as { jupyterapp?: unknown }).jupyterapp),
      undefined,
      { timeout: 60000 }
    );

    const liteFrame = page.frameLocator('iframe[title="Notebook Lite Demo"]');
    const notebookLauncherButton = liteFrame
      .getByRole("button", { name: /Python \(Pyodide\)/ })
      .first();
    await expect(notebookLauncherButton).toBeVisible({ timeout: 60000 });
    await notebookLauncherButton.click();

    await notebookFrame.waitForFunction(
      () => {
        const app = (globalThis as unknown as { jupyterapp?: any }).jupyterapp;
        const kernel =
          app?.shell?.currentWidget?.context?.sessionContext?.session?.kernel ?? null;
        return kernel?.status === "idle";
      },
      undefined,
      { timeout: 60000 }
    );

    const codeCell = liteFrame.locator(".jp-Notebook .cm-content").first();
    await expect(codeCell).toBeVisible({ timeout: 60000 });
    await codeCell.click();
    await codeCell.fill("4+5");
    await codeCell.press("Shift+Enter");

    const output = liteFrame
      .locator(".jp-OutputArea-output")
      .filter({ hasText: /^\s*9\s*$/ });

    await expect(output).toBeVisible({ timeout: 30000 });
  });
});
