import { expect, test } from "@playwright/test";
import {
  getLiteFrame,
  JSON_HEADERS,
  launchPyodideNotebook,
  runNotebookMath,
  runNotebookCode,
  waitForLiteAuthContext,
  setupNotebookWorkbenchApi,
  stubEmptyApi,
  waitForLiteApp,
  waitForLiteKernelIdle
} from "./helpers/jupyterlite";

test.describe("JupyterLite embedding", () => {
  test("renders the standalone JupyterLite diagnostics page", async ({ page }) => {
    await page.goto("/plain-jupyterlite.html");

    await expect(
      page.getByRole("heading", { name: "Plain JupyterLite Embed" })
    ).toBeVisible();

    const liteFrame = page.locator('iframe[title="Local JupyterLite Demo"]');
    await expect(liteFrame).toBeVisible();

    const notebookFrame = await getLiteFrame(page, ['iframe[title="Local JupyterLite Demo"]']);
    await waitForLiteApp(notebookFrame);
    await launchPyodideNotebook(notebookFrame);
    await waitForLiteKernelIdle(notebookFrame);
    await runNotebookMath(notebookFrame, "7-2", /^\s*5\s*$/);
  });

  test("runs python code inside the embedded notebook", async ({ page }) => {
    test.setTimeout(120000);

    await stubEmptyApi(page);

    await page.goto("/");

    const personaSelect = page.locator("#persona");
    await personaSelect.waitFor({ timeout: 15000 });
    await personaSelect.selectOption("admin");
    await page.waitForURL("**/overview");

    await page.getByRole("link", { name: "ELN Demo" }).click();
    await page.waitForURL("**/eln/embed-test");

    const notebookIframe = page.locator('iframe[title="Notebook Lite Demo"]');
    await expect(notebookIframe).toBeVisible({ timeout: 20000 });

    const notebookFrame = await getLiteFrame(page, [
      'iframe[title="Notebook Lite Demo"]',
      'iframe[title="Embedded JupyterLite"]'
    ]);
    await waitForLiteApp(notebookFrame);
    await waitForLiteKernelIdle(notebookFrame);
    await waitForLiteAuthContext(notebookFrame);
    await runNotebookMath(notebookFrame, "4+5", /^\s*9\s*$/);
  });

  test("allows creating a new notebook entry through the ELN workbench", async ({ page }) => {
    test.setTimeout(240000);

    await setupNotebookWorkbenchApi(page);

    await page.goto("/");

    const personaSelect = page.locator("#persona");
    await personaSelect.waitFor({ timeout: 15000 });
    await personaSelect.selectOption("admin");
    await page.waitForURL("**/overview");

    await page.getByRole("link", { name: "ELN", exact: true }).click();
    await page.waitForURL("**/eln");

    const titleInput = page.getByLabel("Title");
    await titleInput.fill("Playwright ELN Entry");
    const descriptionInput = page.getByLabel("Description");
    await descriptionInput.fill("Automated notebook capture");

    const scopeSelect = page.getByLabel("Scope");
    await expect(scopeSelect).toHaveValue("scope-dataset-1");

    await page.getByRole("button", { name: "Create Notebook" }).click();

    await expect(page.getByText("Notebook entry created")).toBeVisible();
    await expect(
      page.locator(".notebook-entry-list__title", { hasText: "Playwright ELN Entry" })
    ).toBeVisible();

    const versionButton = page
      .locator(".notebook-version-list__button--active")
      .filter({ hasText: "v1" });
    await expect(versionButton).toBeVisible();

    await expect(
      page.getByRole("heading", { name: "Playwright ELN Entry" })
    ).toBeVisible();

    const viewerFrame = page.getByTestId("jupyterlite-frame");
    await expect(viewerFrame).toBeVisible();

    const liteFrame = await getLiteFrame(page, [
      'iframe[title="JupyterLite notebook"]',
      'iframe[title="Embedded JupyterLite"]'
    ]);
    await waitForLiteApp(liteFrame);
    await waitForLiteKernelIdle(liteFrame);
    await waitForLiteAuthContext(liteFrame);
    await runNotebookMath(liteFrame, "5*4", /^\s*20\s*$/);

    const authContext = await liteFrame.evaluate(() => {
      return {
        origin: window.location.origin,
        token: sessionStorage.getItem("elnAuthToken") || "",
        apiBase: sessionStorage.getItem("elnApiBase") || "/api"
      };
    });
    expect(authContext.token).not.toBe("");
    const clientSnippet = `
import json
from crazylims_postgrest_client.pyodide import build_authenticated_client
from crazylims_postgrest_client.api.rpc_actor_accessible_scopes import post_rpc_actor_accessible_scopes
from crazylims_postgrest_client.models.post_rpc_actor_accessible_scopes_json_body import PostRpcActorAccessibleScopesJsonBody
import pyodide_http

pyodide_http.patch_all()

client = build_authenticated_client()
payload = PostRpcActorAccessibleScopesJsonBody(p_scope_types=["dataset"])
response = await post_rpc_actor_accessible_scopes.asyncio_detailed(client=client, body=payload)
scopes = json.loads(response.content.decode("utf-8"))
print("client-status", int(response.status_code))
print("scopes-count", len(scopes))
`.trim();

    await runNotebookCode(liteFrame, clientSnippet, /scopes-count\s+[1-9]\d*/, 180000);
  });
});
