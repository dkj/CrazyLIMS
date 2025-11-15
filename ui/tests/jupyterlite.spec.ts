import { expect, test, type Page, type Route, type Frame } from "@playwright/test";

const JSON_HEADERS = {
  "content-type": "application/json"
};

async function stubEmptyApi(page: Page) {
  await page.route("**/api/**", async (route) => {
    await route.fulfill({
      status: 200,
      body: "[]",
      headers: JSON_HEADERS
    });
  });
}

type NotebookDocument = {
  cells: Array<Record<string, unknown>>;
  metadata: Record<string, unknown>;
  nbformat: number;
  nbformat_minor: number;
};

type MockNotebookEntry = {
  entry_id: string;
  entry_key: string | null;
  title: string;
  description: string | null;
  status: "draft" | "submitted" | "locked";
  primary_scope_id: string;
  primary_scope_key: string | null;
  primary_scope_name: string | null;
  metadata: Record<string, unknown> | null;
  submitted_at: string | null;
  submitted_by: string | null;
  locked_at: string | null;
  locked_by: string | null;
  created_at: string;
  created_by: string | null;
  updated_at: string;
  updated_by: string | null;
  latest_version: number | null;
  latest_version_created_at: string | null;
  latest_version_created_by: string | null;
};

type MockNotebookVersion = {
  version_id: string;
  entry_id: string;
  version_number: number;
  notebook_json: NotebookDocument;
  checksum: string;
  note: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
  created_by: string | null;
};

type MockScopeRow = {
  scope_id: string;
  scope_key: string;
  scope_type: string;
  display_name: string;
  role_name: string;
  source_scope_id: string | null;
  source_role_name: string | null;
};

const respondJson = (route: Route, payload: unknown, status = 200) =>
  route.fulfill({
    status,
    body: JSON.stringify(payload),
    headers: JSON_HEADERS
  });

function createInitialNotebookDocument(): NotebookDocument {
  return {
    cells: [
      {
        cell_type: "markdown",
        metadata: {},
        source: ["# New ELN Entry\n", "\n", "Describe your experiment here.\n"]
      },
      {
        cell_type: "code",
        metadata: {},
        source: ['print("Hello from CrazyLIMS ELN")\n'],
        execution_count: null,
        outputs: []
      }
    ],
    metadata: {
      kernelspec: {
        display_name: "Python (Pyodide)",
        language: "python",
        name: "python"
      },
      language_info: {
        name: "python",
        version: "3.11"
      }
    },
    nbformat: 4,
    nbformat_minor: 5
  };
}

async function setupNotebookWorkbenchApi(page: Page) {
  const scopes: MockScopeRow[] = [
    {
      scope_id: "scope-dataset-1",
      scope_key: "DATASET-001",
      scope_type: "dataset",
      display_name: "Alpha Dataset",
      role_name: "researcher",
      source_scope_id: null,
      source_role_name: null
    }
  ];
  const entries: MockNotebookEntry[] = [];
  const versions = new Map<string, MockNotebookVersion[]>();
  let entryCounter = 1;
  let versionCounter = 1;

  await page.route("**/api/**", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const path = url.pathname;

    if (path.endsWith("/rpc/actor_accessible_scopes") && request.method() === "POST") {
      return respondJson(route, scopes);
    }

    if (path.endsWith("/v_notebook_entry_overview") && request.method() === "GET") {
      const ordered = [...entries].sort((a, b) =>
        a.updated_at < b.updated_at ? 1 : a.updated_at > b.updated_at ? -1 : 0
      );
      return respondJson(route, ordered);
    }

    if (path.endsWith("/notebook_entry_versions") && request.method() === "GET") {
      const entryFilter = url.searchParams.get("entry_id");
      const entryId =
        entryFilter && entryFilter.startsWith("eq.") ? entryFilter.slice(3) : null;
      const payload = entryId ? versions.get(entryId) ?? [] : [];
      return respondJson(route, payload);
    }

    if (path.endsWith("/notebook_entries") && request.method() === "POST") {
      const payload = request.postDataJSON() as {
        title?: string;
        description?: string | null;
        primary_scope_id: string;
      };
      const entryId = `mock-entry-${entryCounter++}`;
      const now = new Date().toISOString();
      const scope = scopes.find((candidate) => candidate.scope_id === payload.primary_scope_id);
      const entry: MockNotebookEntry = {
        entry_id: entryId,
        entry_key: null,
        title: payload.title ?? "Untitled Notebook",
        description: payload.description ?? null,
        status: "draft",
        primary_scope_id: payload.primary_scope_id,
        primary_scope_key: scope?.scope_key ?? null,
        primary_scope_name: scope?.display_name ?? null,
        metadata: {},
        submitted_at: null,
        submitted_by: null,
        locked_at: null,
        locked_by: null,
        created_at: now,
        created_by: "playwright",
        updated_at: now,
        updated_by: "playwright",
        latest_version: null,
        latest_version_created_at: null,
        latest_version_created_by: null
      };
      entries.unshift(entry);
      return respondJson(route, [{ entry_id: entryId }]);
    }

    if (path.endsWith("/notebook_entry_versions") && request.method() === "POST") {
      const payload = request.postDataJSON() as {
        entry_id: string;
        notebook_json?: NotebookDocument;
        note?: string | null;
      };
      const entryId = payload.entry_id;
      const versionNumber = (versions.get(entryId)?.[0]?.version_number ?? 0) + 1;
      const now = new Date().toISOString();
      const versionId = `mock-version-${versionCounter++}`;
      const version: MockNotebookVersion = {
        version_id: versionId,
        entry_id: entryId,
        version_number: versionNumber,
        notebook_json: payload.notebook_json ?? createInitialNotebookDocument(),
        checksum: versionId,
        note: payload.note ?? null,
        metadata: null,
        created_at: now,
        created_by: "playwright"
      };
      const entryVersions = versions.get(entryId) ?? [];
      versions.set(entryId, [version, ...entryVersions]);

      const entry = entries.find((candidate) => candidate.entry_id === entryId);
      if (entry) {
        entry.latest_version = versionNumber;
        entry.latest_version_created_at = now;
        entry.latest_version_created_by = "playwright";
        entry.updated_at = now;
        entry.updated_by = "playwright";
      }

      return respondJson(route, [version]);
    }

    return respondJson(route, []);
  });
}

async function resolveFrame(context: Page | Frame, selector: string): Promise<Frame> {
  const iframe = context.locator(selector).first();
  await iframe.waitFor({ state: "visible" });
  const handle = await iframe.elementHandle();
  if (!handle) {
    throw new Error(`Unable to find iframe for selector: ${selector}`);
  }
  const frame = await handle.contentFrame();
  if (!frame) {
    throw new Error(`Failed to resolve frame for selector: ${selector}`);
  }
  return frame;
}

async function getLiteFrame(page: Page, selectors: string[]): Promise<Frame> {
  if (selectors.length === 0) {
    throw new Error("At least one iframe selector is required");
  }
  let context: Page | Frame = page;
  let resolved: Frame | null = null;
  for (const selector of selectors) {
    resolved = await resolveFrame(context, selector);
    context = resolved;
  }
  if (!resolved) {
    throw new Error("Unable to resolve JupyterLite frame");
  }
  return resolved;
}

async function waitForLiteApp(frame: Frame) {
  await frame.waitForFunction(
    () => Boolean((globalThis as unknown as { jupyterapp?: unknown }).jupyterapp),
    undefined,
    { timeout: 60000 }
  );
}

async function waitForLiteKernelIdle(frame: Frame) {
  await frame.waitForFunction(
    () => {
      const app = (globalThis as unknown as { jupyterapp?: any }).jupyterapp;
      const kernel =
        app?.shell?.currentWidget?.context?.sessionContext?.session?.kernel ?? null;
      return kernel?.status === "idle";
    },
    undefined,
    { timeout: 60000 }
  );
}

async function launchPyodideNotebook(frame: Frame) {
  const notebookLauncherButton = frame
    .getByRole("button", { name: /Python \(Pyodide\)/ })
    .first();
  await expect(notebookLauncherButton).toBeVisible({ timeout: 60000 });
  await notebookLauncherButton.click();
}

async function runNotebookMath(frame: Frame, expression: string, expectedOutput: RegExp) {
  const codeCell = frame.locator(".jp-CodeCell .cm-content").first();
  await expect(codeCell).toBeVisible({ timeout: 60000 });
  await codeCell.scrollIntoViewIfNeeded();
  await codeCell.focus();
  await codeCell.fill(expression);
  await codeCell.press("Shift+Enter");

  const output = frame.locator(".jp-OutputArea-output").filter({
    hasText: expectedOutput
  });
  await expect(output).toBeVisible({ timeout: 30000 });
}

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

    const notebookFrame = await getLiteFrame(page, ['iframe[title="Notebook Lite Demo"]']);
    await waitForLiteApp(notebookFrame);
    await launchPyodideNotebook(notebookFrame);
    await waitForLiteKernelIdle(notebookFrame);
    await runNotebookMath(notebookFrame, "4+5", /^\s*9\s*$/);
  });

  test("allows creating a new notebook entry through the ELN workbench", async ({ page }) => {
    test.setTimeout(120000);

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
    await runNotebookMath(liteFrame, "5*4", /^\s*20\s*$/);
  });
});
