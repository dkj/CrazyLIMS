# UI testing quickstart

UI tests are written with Playwright and expect the browser runtime dependencies that ship with Chromium (e.g., `libatk-1.0.so.0`). To keep `npm run test:ui` self-sufficient, the UI package includes a helper script that installs those browser/system dependencies the first time tests are run.

## One-step invocation
From the `ui/` directory, run:

```sh
npm run test:ui
```

The `test:ui` script now calls `scripts/ensure_playwright_deps.sh`, which:

- Runs `npx playwright install --with-deps chromium` (or the value of `PLAYWRIGHT_INSTALL_CMD` if provided) to download the browser and install any missing system libraries.
- Records a `.playwright-installed` stamp so subsequent runs only reinstall when `package.json` or `package-lock.json` change.

## Skipping the full-stack ELN test
The ELN integration test requires PostgREST and JWT fixtures. If those services are not available locally, set the flag below to skip the full-stack scenario while still running the lighter checks:

```sh
RUN_FULL_ELN_E2E=false npm run test:ui
```
