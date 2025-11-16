import { expect, test } from "@playwright/test";
import path from "node:path";
import fs from "node:fs/promises";
import {
  createInitialNotebookDocument,
  getLiteFrame,
  runNotebookMath,
  waitForLiteApp,
  waitForLiteKernelIdle
} from "./helpers/jupyterlite";

const RUN_FULL_STACK = process.env.RUN_FULL_ELN_E2E === "true";
const POSTGREST_URL =
  process.env.FULL_ELN_POSTGREST_URL ?? "http://localhost:7100";
const ADMIN_TOKEN_PATH =
  process.env.FULL_ELN_ADMIN_TOKEN_PATH ??
  path.resolve(process.cwd(), "public/tokens/admin.jwt");

type AccessibleScopeRow = {
  scope_id: string;
  scope_type: string;
  display_name: string;
};

async function readAdminToken(): Promise<string> {
  const token = await fs.readFile(ADMIN_TOKEN_PATH, "utf8");
  return token.trim();
}

async function postgrest(
  pathFragment: string,
  token: string,
  init: RequestInit = {}
) {
  const headers = new Headers(init.headers ?? {});
  headers.set("Authorization", `Bearer ${token}`);
  if (!headers.has("Accept")) {
    headers.set("Accept", "application/json");
  }
  if (init.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  const response = await fetch(`${POSTGREST_URL}${pathFragment}`, {
    ...init,
    headers
  });
  if (!response.ok) {
    const message = await response.text();
    throw new Error(
      `PostgREST ${response.status} ${response.statusText}: ${message}`
    );
  }
  return response;
}

async function fetchDatasetScope(token: string): Promise<AccessibleScopeRow> {
  const response = await postgrest("/rpc/actor_accessible_scopes", token, {
    method: "POST",
    body: JSON.stringify({ p_scope_types: ["dataset", "project"] })
  });
  const scopes = (await response.json()) as AccessibleScopeRow[];
  const dataset =
    scopes.find((scope) => scope.scope_type.toLowerCase() === "dataset") ??
    scopes[0];
  if (!dataset) {
    throw new Error("No accessible dataset scopes for admin persona");
  }
  return dataset;
}

async function createNotebookEntryRecord(
  token: string,
  scopeId: string,
  title: string,
  description: string
): Promise<string> {
  const response = await postgrest("/notebook_entries", token, {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({
      title,
      description,
      primary_scope_id: scopeId,
      metadata: {}
    })
  });
  const [record] = (await response.json()) as Array<{ entry_id: string }>;
  if (!record?.entry_id) {
    throw new Error("Notebook entry creation did not return an entry_id");
  }
  return record.entry_id;
}

async function createNotebookVersionRecord(
  token: string,
  entryId: string
) {
  const notebook = createInitialNotebookDocument();
  notebook.cells.push({
    cell_type: "code",
    metadata: {},
    source: ["print('Full-stack ELN ready')\n"],
    execution_count: null,
    outputs: []
  });

  await postgrest("/notebook_entry_versions", token, {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({
      entry_id: entryId,
      note: "Full-stack setup",
      notebook_json: notebook
    })
  });
}

async function cleanupNotebookEntry(token: string, entryId: string) {
  try {
    await postgrest(`/notebook_entry_versions?entry_id=eq.${entryId}`, token, {
      method: "DELETE"
    });
  } catch (error) {
    console.warn("Failed cleaning notebook_entry_versions", error);
  }
  try {
    await postgrest(`/notebook_entries?entry_id=eq.${entryId}`, token, {
      method: "DELETE"
    });
  } catch (error) {
    console.warn("Failed cleaning notebook_entries", error);
  }
}

test.describe("ELN full-stack integration", () => {
  test.skip(
    !RUN_FULL_STACK,
    "Set RUN_FULL_ELN_E2E=true to enable full-stack ELN validation."
  );

  test("streams database-backed notebooks into the embedded viewer", async ({ page }) => {
    test.setTimeout(180000);

    const adminToken = await readAdminToken();
    const scope = await fetchDatasetScope(adminToken);
    const title = `Full-stack ELN ${new Date().toISOString()}`;
    const description = "Full-stack integration test entry";

    let entryId: string | null = null;
    try {
      entryId = await createNotebookEntryRecord(adminToken, scope.scope_id, title, description);
      await createNotebookVersionRecord(adminToken, entryId);

      await page.goto("/");

      const personaSelect = page.locator("#persona");
      await personaSelect.waitFor({ timeout: 15000 });
      await personaSelect.selectOption("admin");
      await page.waitForURL("**/overview");

      await page.getByRole("link", { name: "ELN", exact: true }).click();
      await page.waitForURL("**/eln");

      const entryRow = page
        .locator(".notebook-entry-list__button")
        .filter({
          has: page
            .locator(".notebook-entry-list__title")
            .filter({ hasText: title })
        })
        .first();
      await entryRow.waitFor({ state: "visible", timeout: 30000 });
      await entryRow.click();

      await expect(
        page.getByRole("heading", { name: title })
      ).toBeVisible({ timeout: 30000 });

      const preparingMessage = page
        .locator(".notebook-workbench__placeholder")
        .filter({ hasText: "Preparing notebook in JupyterLite…" });
      await preparingMessage.waitFor({ state: "detached", timeout: 60000 }).catch(() => undefined);

      const viewerFrame = page.getByTestId("jupyterlite-frame");
      await expect(viewerFrame).toBeVisible();

      const liteFrame = await getLiteFrame(page, [
        'iframe[title="JupyterLite notebook"]',
        'iframe[title="Embedded JupyterLite"]'
      ]);
      await waitForLiteApp(liteFrame);
      await waitForLiteKernelIdle(liteFrame);
      await runNotebookMath(liteFrame, "6+8", /^\s*14\s*$/);
    } finally {
      if (entryId) {
        await cleanupNotebookEntry(adminToken, entryId);
      }
    }
  });
});
