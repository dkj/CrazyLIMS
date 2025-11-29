# JupyterLite Embedding Attempts for the ELN Workbench

The notes below recap every approach we explored while trying to power the ELN with a "standard" JupyterLite notebook experience. Each entry explains what we tried, how far it went, and what ultimately blocked us, so a future developer can pick up the thread without repeating the same dead ends.

## Attempt 1 – Static notebook rendering (baseline)
- **What we tried:** Convert saved `.ipynb` documents into HTML in React using `notebookjs` + `dompurify`. This produced a Markdown/code preview rather than a live kernel.
- **Outcome:** Successful as a read-only view, but completely missed the requirement for an interactive Pyodide kernel. It served as a temporary baseline, but we immediately pivoted to embedding a real JupyterLite runtime.

## Attempt 2 – CDN embed.js snippet
- **What we tried:** Follow the JupyterLite quickstart (`window.JUPYTERLITE_EMBED` + `require(['…/embed.js'])`) and inject the snippet into an iframe `srcDoc` seeded with the notebook JSON.
- **What blocked us:** The npm package `jupyterlite@0.6.4` (and later tags) has been unpublished, so the CDN URL `https://cdn.jsdelivr.net/npm/jupyterlite@0.6.4/dist/embed.js` now returns `404` or `text/plain`. Browsers refuse to execute it, producing `Uncaught Error: Script error for “.../embed.js”`. Without the script, the iframe stays blank.

## Attempt 3 – Remote lab iframe (jupyterlite.github.io)
- **What we tried:** Iframe the public demo (`https://jupyterlite.github.io/demo/lab/index.html`) and talk to it via `postMessage`. We wrote `eln-iframe-bridge.js`, “Send Sample Notebook” buttons, and attempted to push notebooks through the `/api/contents` REST endpoints hosted inside the iframe.
- **What blocked us:**
  - The demo app expects its own service worker and origin. Loaded inside Vite it logged dozens of `Manifest: property 'url' ignored` and `JupyterLite ServiceWorker already registered`, then rendered only navigation chrome.
  - When we attempted to PUT notebooks via `http://localhost:5173/eln/api/contents/...`, the request actually hit Vite (which returned `<!doctype html>`). The iframe’s drive code warned `SyntaxError: Unexpected token '<' ... if there had been a file at .../all.json you might see some more files.`
  - Even when a notebook opened, the kernel stayed “Unknown” and code never executed. The bridge introspected `sessionContext.session?.kernel?.info`, which is undefined in the Lite console we embedded.

## Attempt 4 – Vendored Lite bundle + bridge (first pass)
- **What we tried:** Downloaded JupyterLite assets into `ui/public/eln/notebooks`, wired an iframe at `/eln/notebooks/index.html`, and revived the bridge script so the host UI could push notebooks directly into Lite’s filesystem.
- **What blocked us:**
  - Service worker scope clashes: each refresh required manually unregistering the SW or the iframe stayed blank.
  - The bridge called private APIs (`sessionContext.session?.kernel?.info`, `notebook.model?.cells?.forEach`) that changed between Lite builds, causing runtime errors like `TypeError: sessionContext.session?.kernel?.info is not a function`.
  - Kernels still stalled in “Unknown” because we were trying to poke the kernel before Lite finished booting. There was no reliable signal that the app was ready.

## Attempt 5 – Plain HTML diagnostic pages
- **What we tried:** Serve `plain-local-jupyterlite.html` outside React to remove routing interference. Add buttons that `postMessage` notebooks into the embedded app.
- **What blocked us:**
  - Vite’s dev server handled every `/eln/notebooks/...` request, redirecting to the SPA (“Select a persona to begin”). Static HTML under `ui/public/` only worked when dev tooling wasn’t running, defeating the purpose of the diagnostic page.
  - Even when the page loaded, `postMessage` responses showed `kernel initialization failed` because the iframe never set `window.jupyterapp`, so our bridge could not drive the Contents service.

## Attempt 6 – Local vendoring + viewer host (current solution)
- **What we tried:** Reintroduce a vendoring step (`make jupyterlite/vendor`) that builds the Lite apps locally (Lab/Notebook/REPL) with Pyodide, copies them to `ui/public/eln/lite/`, and flips `exposeAppInBrowser` so the iframe can access `window.jupyterapp`. A lightweight host page (`/eln/viewer.html`) embeds the Lab build, waits for the app to finish booting, saves notebooks via `serviceManager.contents`, and notifies the parent once the kernel is running.
- **Outcome:** Works end-to-end. The React workbench now streams each selected version into the Lite runtime via `postMessage`. The iframe lives entirely on our origin, so SW scope, CORS, and CDN drift are no longer issues. Pyodide kernels progress from “unknown” to “idle” and execute code cells normally.

## Lessons / Pointers for future work
1. **Do not rely on the npm `jupyterlite` dist URLs.** The package is unpublished; use a GitHub release tarball or install via pip and run `jupyter lite build` yourself.
2. **Pin a local build and expose `window.jupyterapp`.** Without `exposeAppInBrowser`, the iframe cannot be remote-controlled. The schema flag must be set post-build (the helper script patches `jupyter-lite.json`).
3. **Keep a single origin.** All “blank iframe” episodes traced back to service workers or Vite intercepting `/eln/...`. Serving Lite assets from React’s `public/` folder keeps everything same-origin and SW-friendly.
4. **Wait for the Lite app to start.** Poll `liteWindow.jupyterapp.started` before touching `serviceManager`. Sending notebooks too early leads to `kernel unknown` and silent failures.
5. **Prefer postMessage over custom REST proxies.** Talking to `/eln/api/contents` through Vite was brittle. Pushing content via the exposed JupyterLite APIs avoids extra HTTP plumbing.

With this history, the current architecture can be hardened (e.g., populate `ui/jupyterlite-contents/` with starter notebooks, add smoke tests that load `/eln/viewer.html`, etc.) without revisiting the broken patterns above.

**Open question:** we have not yet explored the `jupyter-iframe-commands` extension. If a future iteration needs richer two-way control from the parent window, investigating that plugin might unlock safer APIs than our current custom postMessage bridge.
