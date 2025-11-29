# Minimal ELN MVP Specification (Self‑Contained, Project/Study Access-Controlled)

> Status: historical sketch (pre-unified artefact/ELN schema). Refer to `docs/doc-index.md` and `jupyterlite-eln-plan.md` for the current ELN approach.

## 1. Overview
This specification describes a **minimal Electronic Lab Notebook (ELN)** built on PostgreSQL, JupyterLite, and schema-driven APIs (PostgREST or PostGraphile). The MVP persists the **entire Jupyter notebook as JSON** (a blob), implements **append-only versioning**, supports a **lightweight submission/lock** flow, and enforces **project/study-based access control** via PostgreSQL **Row-Level Security (RLS)**—reusing the same ACL semantics as artefacts.

---

## 2. Design Principles
- **Notebook-as-blob**: store the full `.ipynb` as `jsonb` in an immutable version table.
- **Minimal feature set**: _no tags_, _no sample links_, _no external assets_ in MVP.
- **Versioning**: each save writes a new immutable version (append-only).
- **Submission**: submissions lock further edits unless explicitly unlocked.
- **Access control**: project/study scoping via RLS; same membership/ACL logic as artefacts.
- **API-first**: expose tables through PostgREST/PostGraphile; JWT→DB role mapping.
- **Extensible**: future-safe path to assets, samples/tags, and PDF snapshots.

---

## 3. Database Schema

### 3.1 Core Entities
```sql
-- Minimal user registry (or map to your IdP subject)
create table app_user (
  id uuid primary key default gen_random_uuid(),
  email text unique not null
);

-- Projects and studies assumed to exist:
--   project(id uuid primary key, ...)
--   study(id uuid primary key, project_id uuid references project(id), ...)

create table eln_entry (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  owner_id uuid not null references app_user(id),
  project_id uuid not null references project(id),
  study_id uuid references study(id),
  status text not null check (status in ('draft','submitted','locked')) default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint study_in_project check (
    study_id is null or
    exists (select 1 from study s where s.id = study_id and s.project_id = project_id)
  )
);

-- Immutable versions. Store the WHOLE notebook as JSON.
create table eln_entry_version (
  id bigserial primary key,
  entry_id uuid not null references eln_entry(id) on delete cascade,
  version int not null,
  nb_json jsonb not null,          -- full .ipynb as JSON
  nb_sha256 text not null,         -- integrity checksum of nb_json
  note text,                       -- optional commit message
  created_by uuid not null references app_user(id),
  created_at timestamptz not null default now(),
  unique(entry_id, version)
);

-- Lightweight submission/witness (no Part 11 yet)
create table eln_submission (
  entry_id uuid primary key references eln_entry(id) on delete cascade,
  submitted_by uuid not null references app_user(id),
  submitted_at timestamptz not null default now(),
  witness_id uuid,
  witnessed_at timestamptz
);

-- Append-only audit log
create table audit_event (
  id bigserial primary key,
  actor_id uuid not null references app_user(id),
  action text not null,            -- e.g., 'create_entry','save_version','submit'
  entity text not null,            -- e.g., 'eln_entry','eln_entry_version'
  entity_id text not null,         -- store as text for flexibility
  at timestamptz not null default now(),
  details jsonb                    -- optional arbitrary metadata
);
```

### 3.2 Indexes
```sql
create index on eln_entry(project_id);
create index on eln_entry(study_id);
create index on eln_entry(status);
create index on eln_entry_version(entry_id, version);
```

### 3.3 Optional Full-Text Search (over notebook JSON)
```sql
alter table eln_entry_version
  add column nb_text tsvector
    generated always as (to_tsvector('simple', coalesce(nb_json::text,''))) stored;

create index eln_entry_version_nb_text_gin
  on eln_entry_version using gin (nb_text);
```

---

## 4. Access Control with RLS (Project/Study Scope)
Assumes you already have artefact ACL tables such as:
- `project_member(project_id, user_id, role)`
- `study_member(study_id, user_id, role)`
- Optional explicit ACL: `artefact_acl(resource_type, resource_id, user_id, permission)`

JWT claims should include `user_id` and be available in the DB via `current_setting('request.jwt.claims', true)`.

```sql
-- Enable RLS
alter table eln_entry enable row level security;
alter table eln_entry_version enable row level security;

-- Reader check
create or replace function can_read_eln_entry(e eln_entry)
returns boolean language sql stable as $$
  with me as (select current_setting('request.jwt.claims', true)::json ->> 'user_id' as user_id)
  select exists (
           select 1 from project_member pm, me
            where pm.project_id = e.project_id
              and pm.user_id::text = me.user_id
         )
      or (
           e.study_id is not null and
           exists (
             select 1 from study_member sm, me
              where sm.study_id = e.study_id
                and sm.user_id::text = me.user_id
           )
         )
      or (
           exists (
             select 1 from artefact_acl a, me
              where a.resource_type = 'eln_entry'
                and a.resource_id::uuid = e.id
                and a.user_id::text = me.user_id
                and a.permission in ('read','write','owner')
           )
         );
$$;

-- Writer check
create or replace function can_write_eln_entry(e eln_entry)
returns boolean language sql stable as $$
  with me as (select current_setting('request.jwt.claims', true)::json ->> 'user_id' as user_id)
  select exists (
           select 1 from project_member pm, me
            where pm.project_id = e.project_id
              and pm.user_id::text = me.user_id
              and pm.role in ('owner','editor')
         )
      or (
           e.study_id is not null and
           exists (
             select 1 from study_member sm, me
              where sm.study_id = e.study_id
                and sm.user_id::text = me.user_id
                and sm.role in ('owner','editor')
           )
         )
      or (
           exists (
             select 1 from artefact_acl a, me
              where a.resource_type = 'eln_entry'
                and a.resource_id::uuid = e.id
                and a.user_id::text = me.user_id
                and a.permission in ('write','owner')
           )
         );
$$;

-- Policies on eln_entry
create policy eln_entry_read
  on eln_entry for select
  using (can_read_eln_entry(eln_entry));

create policy eln_entry_insert
  on eln_entry for insert
  with check (can_write_eln_entry(eln_entry));

create policy eln_entry_update
  on eln_entry for update
  using (can_write_eln_entry(eln_entry))
  with check (can_write_eln_entry(eln_entry));

-- Policies on eln_entry_version (inherits parent access)
create policy eln_entry_version_read
  on eln_entry_version for select
  using (exists (
           select 1 from eln_entry e
           where e.id = eln_entry_version.entry_id
             and can_read_eln_entry(e)
        ));

create policy eln_entry_version_insert
  on eln_entry_version for insert
  with check (exists (
           select 1 from eln_entry e
           where e.id = eln_entry_version.entry_id
             and can_write_eln_entry(e)
        ));
```

**Lock guard (server-side):** reject new versions if `eln_entry.status in ('submitted','locked')` unless an explicit unlock flag is present (implement in API layer or via trigger).

---

## 5. API Surface (REST examples)
| Method | Path | Description |
|---|---|---|
| `POST` | `/entries` | Create entry. Body: `{title, project_id, study_id?}` |
| `GET` | `/entries` | List entries visible under RLS (filters: `project_id`, `study_id`, `status`) |
| `GET` | `/entries/:id` | Entry metadata (and optionally latest version number) |
| `POST` | `/entries/:id/versions` | Append new version. Body: `{nb_json, note}`; returns `{version, nb_sha256}` |
| `GET` | `/entries/:id/versions/:ver` | Get exact notebook JSON blob |
| `POST` | `/entries/:id/submit` | Mark entry submitted; create `eln_submission` row |
| `GET` | `/search?q=...` | (Optional) Search by `title` or `nb_text` |

**Expected errors**
- `401/403` when RLS denies access.
- `409` on save when the entry is submitted/locked.

---

## 6. Client Behavior (JupyterLite)
- **Open**: navigate to `/eln/:entryId` (your app route) that embeds a JupyterLite iframe.
- **Load**: fetch the notebook JSON (desired version) and write it into the in-browser FS.
- **Edit**: user works entirely client-side.
- **Save**: POST the current notebook JSON to create a new version.
- **Submit**: call submit endpoint; backend locks further version writes.

---

## 7. Audit Trail
```sql
insert into audit_event (actor_id, action, entity, entity_id, details)
values (
  current_user_id(),  -- implement via helper that reads JWT
  'save_version',
  'eln_entry',
  :entry_id::text,
  jsonb_build_object('version', :new_version, 'sha256', :sha256)
);
```

---

## 8. JupyterLite Integration for ELN UI

### 8.1 Simple Embed
```html
<iframe
  id="elnFrame"
  src="/eln/lab/index.html?path=/workspace/entries/E123.ipynb"
  style="width:100%; height:80vh; border:0"
  referrerpolicy="no-referrer"
></iframe>
```

### 8.2 Integrated “ELN Drive” Plugin (Recommended)
- Read `entryId`/`version` from URL.
- Request short-lived token from parent via `postMessage`.
- **Load** → `GET /entries/:id/versions/:ver` → write file → open.
- **Save** → intercept save → `POST /entries/:id/versions`.

Parent app (token flow):
```js
const frame = document.getElementById('elnFrame');
window.addEventListener('message', (e) => {
  if (e.data?.type === 'eln-token-request') {
    frame.contentWindow.postMessage({ type: 'eln-token-response', token: myShortLivedJwt }, e.origin);
  }
});
```

### 8.3 “Blob Import” (No Plugin Yet)
```js
const nb = await fetch(`/api/entries/${entryId}/versions/latest`, { headers: { Authorization: `Bearer ${jwt}` }}).then(r=>r.json());
frame.src = '/eln/lab/index.html#eln-boot';
window.addEventListener('message', (e) => {
  if (e.data?.type === 'eln-ready') {
    frame.contentWindow.postMessage({ type: 'eln-open-notebook', path:`/workspace/entries/${entryId}.ipynb`, content: nb }, e.origin);
  }
});
```

### 8.4 Auth & Security Notes
- Prefer cookies or short-lived JWT via `postMessage`; avoid tokens in URLs.
- Validate `event.origin` in messaging.
- Enforce server-side locks with `409 Conflict` when saving a locked/submitted entry.

### 8.5 Implementation Checklist
1. Host JupyterLite at `/eln/` with branding and a service worker scope.
2. Add app route `/eln/:entryId` that embeds the iframe.
3. Implement token exchange via `postMessage`.
4. Start with “Blob Import”; upgrade to the plugin for native save UX.
5. Enforce submission lock and RLS in the API.

---

## 9. Migration Path
| Future Feature | Additions |
|---|---|
| Attachments / Assets | Add `asset` table + pre-signed uploads; notebooks reference URLs |
| Samples & Tags | Add link tables `eln_entry_sample`, `eln_entry_tag` with GIN indexes |
| PDF Snapshots | Add serverless render; store `pdf_url` on `eln_entry_version` |
| Real-time Editing | Add Yjs + WebSocket service |
| Part 11 Signatures | Strengthen identity + signature records; policy controls |

---

## 10. Non-Goals for MVP
- No inventory, scheduling, or instrument integrations.
- No real-time multi-user editing.
- No external binary asset storage (all content lives in the notebook JSON).

---

## 11. Summary
A **zero-install, browser-native ELN** using JupyterLite, with **notebook-as-blob versioning**, **project/study RLS**, and a minimal API. It’s small enough to ship quickly and strong enough to evolve into a full ELN/LIMS.
