# JupyterLite-Based ELN Implementation Plan

## 1. Scope & Guiding Fit

- **Why JupyterLite for ELN**: zero-install, offline-tolerant capture, Python-native data handling inside the notebook UI, and a simple extension surface for ELN controls (metadata, links, “submit/sign”, export).
- **Alignment with requirements**: ELN entries with rich content, files, templates, tagging/search, versioning & authorship; linkage to samples, reagents, and results; API-first, RBAC/RLS, auditability, and object storage for files.
- **Backend choice to minimize code**: adopt a **schema-driven Postgres + PostgREST** slice for ELN metadata, links, and auth, leaving the heavy UI inside JupyterLite.

## 2. Two Initial User Stories (MVP)

### Story A — “Template to Signed ELN Entry”

**As a Researcher**, I open a notebook template, record text/data, attach files, link samples, and **submit for (optional) witness/e-signature**; a PDF snapshot is archived with immutable metadata.

**Acceptance criteria**:
- Launch **ELN template** from a gallery.
- **Metadata side panel** (Project, Tags, Sample links, Protocol ID) saved with the notebook.
- **Attachments** (images/CSV) uploaded to object storage; checksummed; links stored in ELN metadata.
- **Submit/Sign** button records authorship, timestamp, version; witness flow optional; audit event persisted.
- **Generate & store PDF** snapshot with stable identifier.

### Story B — “Data to Results”

**As an Analyst**, I drag-and-drop a CSV from an instrument into the notebook, run cells to parse/plot/QC, and **publish structured results** linked to Samples/Run, visible via the API and discoverable later.

**Acceptance criteria**:
- Drag-drop file widget in the notebook.
- Parser cell produces a tidy dataframe; **Publish Results** button posts JSON rows to `results` with lineage back to entry and samples.
- Entry shows “Results published” status with IDs/links.

## 3. Target Architecture

### Client (JupyterLite)
- **JupyterLite + Pyodide** served as static files.
- **Federated extension**: “ELN Panel”
  - Metadata Editor, Link Manager, Submit/Sign action, Publish Results, Export PDF.
- **Storage model**: working files in IndexedDB; on save/submit, notebook JSON + assets sync to backend.
- **Auth**: OIDC login → JWT mapped to DB roles; tokens attached to API calls.

### Backend (Schema-Driven)
- **PostgreSQL** tables: `eln_entry`, `eln_entry_tag`, `eln_entry_sample`, `asset`, `result`, `audit`.
- **APIs** via **PostgREST** or **PostGraphile**; RLS for scoping.
- **Object storage** (S3-compatible) with pre-signed uploads.
- **Functions**: `submit_entry`, `presign_asset_upload`, `render_pdf`.
- **Auditability**: append-only `audit` table.

## 4. Implementation Steps

1. Database & API slice (schemas, PostgREST, JWT→role mapping)
2. Auth & bootstrap (OIDC integration)
3. JupyterLite packaging (custom ELN Panel extension)
4. Link Manager (samples search & attach)
5. Attachments & large file handling (pre-signed URLs)
6. Submit/Sign & audit trail (version bump, audit log)
7. Results publishing (API linkage to entries/samples)
8. PDF snapshot rendering (nbconvert or headless browser)
9. Search/list view (filter by tag, project, date)

## 5. Security & Governance

- **RBAC/ABAC & RLS**: least privilege, project-level scoping.
- **Audit trail**: submit/sign/result actions logged with checksum & actor IDs.
- **Data contracts**: OpenAPI/GraphQL schemas versioned as API contracts.

## 6. Risks & Mitigations

| Risk | Mitigation |
|------|-------------|
| No real-time collaboration | Start single-author; add y-websocket later |
| PDF rendering quality | Use serverless renderer for consistency |
| Large binaries | Pre-signed uploads & checksums |
| Offline conflicts | Version on conflict & diff display |
| Regulatory e-signatures | Start lightweight; extend for 21 CFR Part 11 compliance |

## 7. Demo Scenarios

- **Story A**: Open “PCR run notebook” template → fill in → link samples → attach image → submit → witness → PDF snapshot appears.
- **Story B**: Drag CSV → parse & plot → publish results → linked results visible via API.

## 8. Future LIMS Integration

The **ELN remains notebook-first**, while the **system of record is the PostgreSQL database** with strong contracts, RBAC/RLS, and APIs—preparing for expansion into Samples, Inventory, Scheduling, and Instruments.

## 9. Validation & Testing

- `make test/ui` now runs the Playwright suite against mocked PostgREST responses to exercise the embedded JupyterLite launcher, notebook creation form, and viewer plumbing without needing a database.
- A new full-stack Playwright spec (`ui/tests/eln.fullstack.spec.ts`) targets the real PostgREST slice. Set `RUN_FULL_ELN_E2E=true` and point `FULL_ELN_POSTGREST_URL` at a running PostgREST instance (with JWTs in `public/tokens/`) to insert a live ELN entry, load it through the UI, and execute Pyodide code inside the embedded notebook—verifying DB ↔ REST ↔ UI ↔ JupyterLite end-to-end.
