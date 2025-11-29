import { expect, type Frame, type Page, type Route } from "@playwright/test";

export const JSON_HEADERS = {
  "content-type": "application/json"
};

export type NotebookDocument = {
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

export function createInitialNotebookDocument(): NotebookDocument {
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

export async function stubEmptyApi(page: Page) {
  await page.route("**/api/**", async (route) => {
    await route.fulfill({
      status: 200,
      body: "[]",
      headers: JSON_HEADERS
    });
  });
}

export async function setupNotebookWorkbenchApi(page: Page) {
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

export async function resolveFrame(context: Page | Frame, selector: string): Promise<Frame> {
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

export async function getLiteFrame(page: Page, selectors: string[]): Promise<Frame> {
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

export async function waitForLiteApp(frame: Frame) {
  await frame.waitForFunction(
    () => Boolean((globalThis as unknown as { jupyterapp?: unknown }).jupyterapp),
    undefined,
    { timeout: 60000 }
  );
}

export async function waitForLiteKernelIdle(frame: Frame) {
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

export async function waitForLiteAuthContext(frame: Frame) {
  await expect
    .poll(
      async () =>
        frame.evaluate(() => {
          try {
            const token = sessionStorage.getItem("elnAuthToken");
            const base = sessionStorage.getItem("elnApiBase");
            return token && base ? "ready" : "";
          } catch {
            return "";
          }
        }),
      { timeout: 60000, message: "Timed out waiting for ELN auth context in JupyterLite" }
    )
    .toBe("ready");
}

export async function launchPyodideNotebook(frame: Frame) {
  const notebookLauncherButton = frame
    .getByRole("button", { name: /Python \(Pyodide\)/ })
    .first();
  await expect(notebookLauncherButton).toBeVisible({ timeout: 60000 });
  await notebookLauncherButton.click();
}

export async function runNotebookMath(
  frame: Frame,
  expression: string,
  expectedOutput: RegExp
) {
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

export async function runNotebookCode(
  frame: Frame,
  code: string,
  expectedOutput: RegExp,
  timeout = 60000
) {
  const codeCell = frame.locator(".jp-CodeCell .cm-content").first();
  await expect(codeCell).toBeVisible({ timeout: 60000 });
  await codeCell.scrollIntoViewIfNeeded();
  await codeCell.focus();
  await codeCell.fill(code);
  await codeCell.press("Shift+Enter");

  await expect
    .poll(
      async () => {
        const texts = await frame.locator(".jp-OutputArea-output").allTextContents();
        return texts.join("\n");
      },
      {
        timeout,
        message: `Notebook output did not match ${expectedOutput}`
      }
    )
    .toMatch(expectedOutput);
}
