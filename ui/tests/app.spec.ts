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

  test("creates a notebook without PostgREST alias errors", async ({ page }) => {
    const datasetScopes = [
      {
        scope_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        scope_key: "dataset:first",
        scope_type: "dataset",
        display_name: "First Dataset",
        role_name: "app_researcher",
        source_scope_id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        source_role_name: "app_researcher"
      },
      {
        scope_id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
        scope_key: "dataset:second",
        scope_type: "dataset",
        display_name: "Second Dataset",
        role_name: "app_researcher",
        source_scope_id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        source_role_name: "app_researcher"
      }
    ];

    const newEntryId = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
    const newVersionId = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";
    let createPayload: Record<string, unknown> | null = null;

    await page.route("**/api/**", async (route) => {
      const request = route.request();
      const url = request.url();
      const method = request.method();
      if (url.includes("/api/rpc/actor_accessible_scopes") && method === "POST") {
        await route.fulfill({
          status: 200,
          body: JSON.stringify(datasetScopes),
          headers: { "content-type": "application/json" }
        });
        return;
      }

      if (url.includes("/api/v_notebook_entry_overview") && method === "GET") {
        const responseBody = createPayload
          ? JSON.stringify([
              {
                entry_id: newEntryId,
                entry_key: "eln:test",
                title: String(createPayload?.title ?? ""),
                description: createPayload?.description ?? null,
                status: "draft",
                primary_scope_id: datasetScopes[1].scope_id,
                primary_scope_key: datasetScopes[1].scope_key,
                primary_scope_name: datasetScopes[1].display_name,
                metadata: {},
                submitted_at: null,
                submitted_by: null,
                locked_at: null,
                locked_by: null,
                created_at: "2025-01-01T00:00:00Z",
                created_by: "ffffffff-ffff-4fff-8fff-ffffffffffff",
                updated_at: "2025-01-01T00:00:00Z",
                updated_by: "ffffffff-ffff-4fff-8fff-ffffffffffff",
                latest_version: 1,
                latest_version_created_at: "2025-01-01T00:00:00Z",
                latest_version_created_by: "ffffffff-ffff-4fff-8fff-ffffffffffff"
              }
            ])
          : "[]";

        await route.fulfill({
          status: 200,
          body: responseBody,
          headers: { "content-type": "application/json" }
        });
        return;
      }

      if (url.includes("/api/notebook_entry_versions")) {
        if (method === "POST") {
          await route.fulfill({
            status: 200,
            body: JSON.stringify([
              {
                version_id: newVersionId,
                entry_id: newEntryId,
                version_number: 1,
                notebook_json: JSON.parse(request.postData() ?? "{}")?.notebook_json ?? {
                  cells: [],
                  metadata: {},
                  nbformat: 4,
                  nbformat_minor: 5
                },
                checksum: "abc123",
                note: "Initial capture",
                metadata: {},
                created_at: "2025-01-01T00:00:00Z",
                created_by: "ffffffff-ffff-4fff-8fff-ffffffffffff"
              }
            ]),
            headers: { "content-type": "application/json" }
          });
          return;
        }

        const responseBody = createPayload
          ? JSON.stringify([
              {
                version_id: newVersionId,
                entry_id: newEntryId,
                version_number: 1,
                notebook_json: {
                  cells: [],
                  metadata: {},
                  nbformat: 4,
                  nbformat_minor: 5
                },
                checksum: "abc123",
                note: "Initial capture",
                metadata: {},
                created_at: "2025-01-01T00:00:00Z",
                created_by: "ffffffff-ffff-4fff-8fff-ffffffffffff"
              }
            ])
          : "[]";

        await route.fulfill({
          status: 200,
          body: responseBody,
          headers: { "content-type": "application/json" }
        });
        return;
      }

      if (url.includes("/api/notebook_entries") && method === "POST") {
        createPayload = JSON.parse(request.postData() ?? "{}");
        await route.fulfill({
          status: 200,
          body: JSON.stringify([{ entry_id: newEntryId }]),
          headers: { "content-type": "application/json" }
        });
        return;
      }

      await route.fulfill({
        status: 200,
        body: "[]",
        headers: { "content-type": "application/json" }
      });
    });

    await page.goto("/");
    await page.selectOption("#persona", "admin");
    await page.waitForURL("**/overview");

    await page.getByRole("link", { name: "ELN" }).click();
    await page.waitForURL("**/eln");

    await page.locator("select.notebook-workbench__select").selectOption(datasetScopes[1].scope_id);
    await page.getByLabel("Title").fill("Automation Notebook");
    await page.getByLabel("Description").fill("Created by UI automation");

    const createRequestPromise = page.waitForRequest(
      (req) => req.method() === "POST" && req.url().includes("/api/notebook_entries")
    );

    await page.getByRole("button", { name: "Create Notebook" }).click();

    await createRequestPromise;
    await expect(createPayload).not.toBeNull();
    await expect(page.locator(".notebook-workbench__banner")).toContainText(
      "Notebook entry created"
    );
    await expect(page.locator("text=PGRST")).toHaveCount(0);
  });

  test("renders ELN workbench with selectable scope and no PostgREST errors", async ({ page }) => {
    const datasetScopes = [
      {
        scope_id: "11111111-1111-4111-8111-111111111111",
        scope_key: "dataset:test_dataset",
        scope_type: "dataset",
        display_name: "Test Dataset",
        role_name: "app_researcher",
        source_scope_id: "21111111-1111-4111-8111-111111111111",
        source_role_name: "app_researcher"
      },
      {
        scope_id: "22222222-2222-4222-8222-222222222222",
        scope_key: "dataset:alternate_dataset",
        scope_type: "dataset",
        display_name: "Alternate Dataset",
        role_name: "app_researcher",
        source_scope_id: "21111111-1111-4111-8111-111111111111",
        source_role_name: "app_researcher"
      }
    ];

    await page.route("**/api/**", async (route) => {
      const request = route.request();
      const url = request.url();
      const method = request.method();

      if (url.includes("/api/rpc/actor_accessible_scopes") && method === "POST") {
        await route.fulfill({
          status: 200,
          body: JSON.stringify(datasetScopes),
          headers: { "content-type": "application/json" }
        });
        return;
      }

      if (url.includes("/api/v_notebook_entry_overview") && method === "GET") {
        await route.fulfill({
          status: 200,
          body: "[]",
          headers: { "content-type": "application/json" }
        });
        return;
      }

      if (url.includes("/api/notebook_entry_versions") && method === "GET") {
        await route.fulfill({
          status: 200,
          body: "[]",
          headers: { "content-type": "application/json" }
        });
        return;
      }

      await route.fulfill({
        status: 200,
        body: "[]",
        headers: { "content-type": "application/json" }
      });
    });

    await page.goto("/");

    await page.selectOption("#persona", "admin");
    await page.waitForURL("**/overview");

    await page.getByRole("link", { name: "ELN" }).click();
    await page.waitForURL("**/eln");

    await expect(page.getByRole("heading", { level: 3, name: "Create Notebook" })).toBeVisible();
    await expect(page.getByRole("heading", { level: 3, name: "Notebook Entries" })).toBeVisible();

    const scopeSelect = page.locator("select.notebook-workbench__select");
    await expect(scopeSelect).toBeEnabled();
    await expect(scopeSelect.locator("option")).toHaveCount(datasetScopes.length + 1);
    await expect(scopeSelect).toHaveValue(datasetScopes[0].scope_id);

    await scopeSelect.selectOption(datasetScopes[1].scope_id);
    await expect(scopeSelect).toHaveValue(datasetScopes[1].scope_id);

    await expect(page.getByRole("button", { name: "Create Notebook" })).toBeEnabled();
    await expect(page.locator(".notebook-workbench__error")).toHaveCount(0);
    await expect(page.locator("text=PGRST")).toHaveCount(0);
  });

  test("navigates to storage explorer without rendering errors", async ({ page }) => {
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

    await page.selectOption("#persona", "admin");
    await page.waitForURL("**/overview");

    await page.getByRole("link", { name: "Storage" }).click();
    await page.waitForURL("**/storage");

    await expect(
      page.getByRole("heading", { level: 2, name: "Labware & Storage Explorer" })
    ).toBeVisible();
    await expect(
      page.getByText("No storage hierarchy available for the current persona.")
    ).toBeVisible();
  });
});
