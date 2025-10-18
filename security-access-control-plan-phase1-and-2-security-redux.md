# Security & Access Control Plan (Phase 1 and 2 Security Redux) — CrazyLIMS

> **Audience:** senior backend developers & DBAs  
> **Scope:** PostgreSQL-only enforcement (RLS + policies + SQL functions)  
> **Goal:** Implement lineage-aware, scope/project-aware access with explicit handover between research labs and an operations lab, including multiplexed pooling and safe return of outputs. The plan is **self-contained** and does **not** rely on this conversation for missing details.

---

## 1) Concise Summary of Clarified Security Requirements

1. **DB-level enforcement only:** All access decisions are enforced in PostgreSQL using RLS policies, grants, SECURITY DEFINER helper functions, triggers, and stored procedures. The API/UI must not broaden access.
2. **Study/Project partitioning:** Every artefact, process, pool, and data product belongs to one or more **scopes** (e.g., research project scope or an ops sub-scope). Visibility is primarily determined by membership in the relevant scope(s).
3. **Role within scope matters:** Users hold roles per scope (e.g., `researcher`, `lab_tech`, `instrument`, `viewer`, `admin`). Permissions differ by role and by data type (virtual vs. physical artefacts, process records, data products).
4. **Lineage-aware visibility:** Research teams see:
   - all data within their own study scope,
   - all **downstream** artefacts/processes/data products derived (directly or transitively) from their study’s artefacts, including those processed in the ops lab,
   - but **never** data from other studies contributing to the same pooled runs.
5. **Operations lab isolation:** Ops users see:
   - only artefacts **duplicated** into ops scopes (minimal metadata) and processes in ops scopes,
   - **not** upstream research virtual entities or sensitive research metadata, nor downstream research activity after outputs are returned.
6. **Explicit handover protocol:** Handover occurs via **controlled duplication** of selected artefacts into an ops scope with:
   - minimal metadata (plate layout, indexes, expected fragment size, etc.),
   - immutable **provenance links** to the source artefacts,
   - a **transfer state** on the source, and an ops **receipt** on the duplicate.
   - Return handover duplicates outputs back into research scope(s) with lineage preserved.
7. **Multiplexing (pooled runs):** Pools and data products carry **per-contributor attribution** that links each product to each contributing source artefact/scope via lineage. RLS ensures each user only sees the subset attributable to their scopes.
8. **Corrections propagation:** Corrections to specific fields in research artefacts can be **propagated forward** to scope-duplicates via whitelisted, versioned “propagation rules”. Propagation is **pull-based** (ops does *not* see upstream fields unless whitelisted).
9. **Instrument/service accounts:** Narrow, scope-bound permissions to read inputs and write outputs only within their ops sub-scopes (least privilege).
10. **Auditing & observability:** All mutations are audited with actor, scope, role, and lineage context; lineage traversals are explainable via views.

---

## 2) User Stories (Serve as Acceptance Tests)

### Research — Project Alpha
1. **Alpha-1:** Roberto (researcher, non-lab) registers **virtual entities** with study `alpha` (donor id/age/region/gender).
2. **Alpha-2:** Phillipa (researcher) registers plate `P202` linking wells to Roberto’s virtual entities.
3. **Alpha-3:** Phillipa processes `P202` to fragmented DNA plate `D203`.
4. **Alpha-4:** Ross (lab assistant, research lab) creates indexed libraries `L204` (i5/i7 tags).
5. **Alpha-5:** Ross hands over `L204` to Ops: duplicates created in `ops/alpha-lib` scope with minimal metadata; research copy marked `transferred`.

### Research — Project Beta
6. **Beta-1:** Eric (researcher, non-lab) registers virtual entities for study `beta` (tubes with barcodes, donor metadata).

### Ops Lab
7. **Ops-1:** Lucy (ops lab tech) receives 270 tubes for `alpha`; loads automation producing plates `L401-403` (ops scope duplicates).
8. **Ops-2:** Fred (ops lab tech) quantifies `L204`, `L401-403`, producing normalized plates `N203`, `N401-403`.
9. **Ops-3:** Fred pools `N203 + N401-403` into pool tube `LT5`.
10. **Ops-4:** Sequencer (instrument account) runs `LT5` → 366 data products; each product **attributed** back to contributing wells via lineage.
11. **Ops-5:** Data products are **returned** to research scopes: per-contributor references and deliverables copied/duplicated back to `alpha` (and only the alpha-attributed subset).

### Visibility/Confidentiality
12. **Vis-1:** Ops users cannot see upstream research virtual entities or donor PHI.
13. **Vis-2:** Alpha researchers see all Alpha artefacts and downstream ops outputs derived from Alpha (but **not** Beta’s contributions in pooled runs).
14. **Vis-3:** Beta researchers see only Beta artefacts/outputs.
15. **Vis-4:** Instrument account can only read required inputs and write outputs/QC within its ops scope.

These stories are covered by the tests in §11.

---

## 3) Data Model Extensions (DDL)

> Schema names are illustrative (`app_security`, `app_provenance`, `app_ops`). Adapt to repository conventions if different.

### 3.1 Scopes & Memberships
```sql
create table if not exists app_security.scopes (
  scope_id        uuid primary key default gen_random_uuid(),
  scope_type      text not null check (scope_type in ('project','ops','instrument','subproject','pool')),
  name            text not null unique,
  parent_scope_id uuid references app_security.scopes(scope_id) on delete cascade,
  created_at      timestamptz not null default now()
);

create table if not exists app_security.scope_memberships (
  user_id         uuid not null references app_core.users(user_id),
  scope_id        uuid not null references app_security.scopes(scope_id),
  role            text not null check (role in ('researcher','lab_tech','instrument','viewer','admin')),
  primary key (user_id, scope_id)
);

create index if not exists idx_scope_memberships_user on app_security.scope_memberships(user_id);
create index if not exists idx_scope_memberships_scope on app_security.scope_memberships(scope_id);
```

### 3.2 Artefacts, Processes, Data Products
```sql
-- Artefacts (virtual & physical)
alter table app_provenance.artefacts
  add column if not exists scope_id uuid not null references app_security.scopes(scope_id);

alter table app_provenance.artefacts
  add column if not exists is_virtual boolean not null default false;

alter table app_provenance.artefacts
  add column if not exists transfer_state text
    check (transfer_state in ('none','transferred','returned')) default 'none';

-- Explicit duplication map
create table if not exists app_provenance.artefact_duplicates (
  duplicate_id     uuid primary key default gen_random_uuid(),
  src_artefact_id  uuid not null references app_provenance.artefacts(artefact_id) on delete restrict,
  dst_artefact_id  uuid not null references app_provenance.artefacts(artefact_id) on delete cascade,
  propagated_fields jsonb not null default '{}'::jsonb,
  created_at       timestamptz not null default now(),
  unique (src_artefact_id, dst_artefact_id)
);

-- Lineage (DAG edges)
create table if not exists app_provenance.lineage (
  parent_artefact_id uuid not null references app_provenance.artefacts(artefact_id),
  child_artefact_id  uuid not null references app_provenance.artefacts(artefact_id),
  process_id         uuid references app_provenance.processes(process_id),
  primary key (parent_artefact_id, child_artefact_id)
);

create index if not exists idx_lineage_parent on app_provenance.lineage(parent_artefact_id);
create index if not exists idx_lineage_child  on app_provenance.lineage(child_artefact_id);

-- Pools & members
create table if not exists app_ops.pools (
  pool_id        uuid primary key default gen_random_uuid(),
  scope_id       uuid not null references app_security.scopes(scope_id),
  name           text not null
);

create table if not exists app_ops.pool_members (
  pool_id        uuid not null references app_ops.pools(pool_id) on delete cascade,
  artefact_id    uuid not null references app_provenance.artefacts(artefact_id) on delete cascade,
  contribution_fraction numeric not null check (contribution_fraction > 0 and contribution_fraction <= 1),
  primary key (pool_id, artefact_id)
);

-- Data products & attribution
create table if not exists app_ops.data_products (
  data_product_id uuid primary key default gen_random_uuid(),
  pool_id         uuid not null references app_ops.pools(pool_id),
  scope_id        uuid not null references app_security.scopes(scope_id), -- ops scope of creation
  manifest        jsonb not null,
  created_at      timestamptz not null default now()
);

create table if not exists app_ops.data_product_attribution (
  data_product_id   uuid not null references app_ops.data_products(data_product_id) on delete cascade,
  source_artefact_id uuid not null references app_provenance.artefacts(artefact_id) on delete cascade,
  source_scope_id    uuid not null references app_security.scopes(scope_id),
  readset_uri        text,
  primary key (data_product_id, source_artefact_id)
);

create index if not exists idx_dpa_scope on app_ops.data_product_attribution(source_scope_id);
create index if not exists idx_art_scope on app_provenance.artefacts(scope_id);
```

### 3.3 Correction Propagation Rules
```sql
create table if not exists app_provenance.propagation_rules (
  rule_id         uuid primary key default gen_random_uuid(),
  src_table       text not null check (src_table in ('artefacts')),
  src_field       text not null,
  dst_table       text not null check (dst_table in ('artefacts')),
  dst_field       text not null,
  is_allowed      boolean not null default true,
  last_changed_at timestamptz not null default now(),
  unique (src_table, src_field, dst_table, dst_field)
);
```

---

## 4) Authorization Model (Functions, Context, RLS)

### 4.1 Session Context
- On connection/JWT:
  - `app.current_user_id()` returns current user id.
  - `app.current_scope_roles` exposed via a view to map `{scope_id, role}` for the user.

### 4.2 Helper Functions (set `search_path` safely; mark as `stable`; use `SECURITY DEFINER` if needed)
```sql
create or replace function app_security.current_user_id()
returns uuid language sql stable as $$
  select current_setting('app.current_user_id', true)::uuid
$$;

create or replace function app_security.has_scope_membership(p_scope_id uuid, p_roles text[] default null)
returns boolean language sql stable as $$
  select exists (
    select 1 from app_security.scope_memberships m
    where m.scope_id = p_scope_id
      and m.user_id = app_security.current_user_id()
      and (p_roles is null or m.role = any(p_roles))
  );
$$;

create or replace function app_provenance.can_read_artefact(p_artefact_id uuid)
returns boolean language plpgsql stable as $$
declare v_scope uuid;
begin
  select scope_id into v_scope from app_provenance.artefacts where artefact_id = p_artefact_id;
  if v_scope is null then return false; end if;

  if app_security.has_scope_membership(v_scope, array['researcher','lab_tech','viewer','admin']) then
    return true;
  end if;

  -- lineage-based visibility: user may read if any ancestor is in a scope the user belongs to
  return exists (
    with recursive anc(artefact_id) as (
      select p_artefact_id
      union all
      select l.parent_artefact_id
      from app_provenance.lineage l
      join anc on anc.artefact_id = l.child_artefact_id
    )
    select 1
    from anc
    join app_provenance.artefacts a on a.artefact_id = anc.artefact_id
    join app_security.scope_memberships m on m.scope_id = a.scope_id
    where m.user_id = app_security.current_user_id()
  );
end;
$$;

create or replace function app_provenance.can_write_artefact(p_artefact_id uuid)
returns boolean language sql stable as $$
  select app_security.has_scope_membership(a.scope_id, array['researcher','lab_tech','admin'])
  from app_provenance.artefacts a
  where a.artefact_id = p_artefact_id;
$$;

create or replace function app_ops.can_read_data_product(p_dp_id uuid)
returns boolean language sql stable as $$
  select exists (
    select 1
    from app_ops.data_product_attribution dpa
    join app_security.scope_memberships m
      on m.scope_id = dpa.source_scope_id
     and m.user_id = app_security.current_user_id()
    where dpa.data_product_id = p_dp_id
  );
$$;
```

### 4.3 RLS Policies (deny-all default; enable RLS everywhere)

#### Artefacts
```sql
alter table app_provenance.artefacts enable row level security;

create policy artefacts_select on app_provenance.artefacts
for select using (app_provenance.can_read_artefact(artefact_id));

create policy artefacts_insert on app_provenance.artefacts
for insert with check (
  app_security.has_scope_membership(scope_id, array['researcher','lab_tech','instrument','admin'])
  and (not is_virtual or app_security.has_scope_membership(scope_id, array['researcher','admin']))
);

create policy artefacts_update on app_provenance.artefacts
for update using (app_provenance.can_write_artefact(artefact_id))
with check (app_provenance.can_write_artefact(artefact_id));
```

> **Column-level guards:** Add a `BEFORE UPDATE` trigger to restrict which columns each role may change (e.g., researchers on virtual fields in research scopes; lab_tech on physical/QC fields in ops scopes; instrument on status/QC only).

#### Lineage
```sql
alter table app_provenance.lineage enable row level security;

create policy lineage_select on app_provenance.lineage
for select using (
  app_provenance.can_read_artefact(parent_artefact_id)
  or app_provenance.can_read_artefact(child_artefact_id)
);

create policy lineage_insert on app_provenance.lineage
for insert with check (app_provenance.can_write_artefact(child_artefact_id));
```

#### Pools & Data Products
```sql
alter table app_ops.pools enable row level security;

create policy pools_select on app_ops.pools
for select using (app_security.has_scope_membership(scope_id, array['lab_tech','admin','instrument','researcher']));

create policy pools_write on app_ops.pools
for all using (app_security.has_scope_membership(scope_id, array['lab_tech','admin','instrument']))
with check (app_security.has_scope_membership(scope_id, array['lab_tech','admin','instrument']));

alter table app_ops.data_products enable row level security;

create policy dp_select on app_ops.data_products
for select using (app_ops.can_read_data_product(data_product_id));

alter table app_ops.data_product_attribution enable row level security;

create policy dpa_select on app_ops.data_product_attribution
for select using (
  exists (
    select 1 from app_security.scope_memberships m
    where m.scope_id = app_ops.data_product_attribution.source_scope_id
      and m.user_id = app_security.current_user_id()
  )
);
```

#### Duplications
```sql
alter table app_provenance.artefact_duplicates enable row level security;

create policy ad_select on app_provenance.artefact_duplicates
for select using (
  app_provenance.can_read_artefact(src_artefact_id)
  or app_provenance.can_read_artefact(dst_artefact_id)
);
```

---

## 5) Handover Protocol (Research ⇄ Ops)

### 5.1 To Ops (Research → Ops)
1. **Select** research artefacts to transfer (plate/wells/tags).
2. **Create** ops scope if needed (e.g., `ops/<pipeline>/<run>`).
3. **Duplicate** minimal fields into new `artefacts(scope_id := ops_scope)`:
   - plate/well positions, library IDs, index tags, expected fragment size, QC breadcrumbs.
   - **Exclude** upstream research metadata (donor PHI, etc.).
4. **Record** `artefact_duplicates(src, dst, propagated_fields := whitelist)`.
5. **Mark** source `transfer_state := 'transferred'`.
6. **Create** lineage edges `lineage(src → dst)`.

### 5.2 Within Ops
- Ops users & instruments work only on ops-scope artefacts.
- Pools and data products created within ops scope.
- Attribution table `data_product_attribution` populated for **each contributing source artefact** (via lineage up to research artefacts).

### 5.3 Return to Research (Ops → Research)
1. For each data product, **fan-out references** (or duplicates) into each contributing research scope:
   - Create research-scope **product references** per contributor (optionally as lightweight rows pointing to canonical ops product).
   - Link via `data_product_attribution` to preserve provenance and enforce per-scope visibility.
2. Set ops artefacts `transfer_state := 'returned'` when complete.
3. Maintain lineage edges `ops data_product → research data_product_ref` or store explicit mapping.

---

## 6) Correction Propagation

### Policy
- Upstream corrections (e.g., fixing i7 index) may be **propagated** from research artefact → ops duplicate **if**:
  - field is whitelisted in `propagation_rules`,
  - destination field exists and is safe to update,
  - ops artefact not yet consumed by a closed process state (optional rule).

### Mechanism
```sql
create or replace function app_provenance.propagate_corrections(p_src_artefact_id uuid)
returns void language plpgsql security definer as $$
declare r record;
begin
  for r in
    select d.dst_artefact_id, d.propagated_fields
    from app_provenance.artefact_duplicates d
    where d.src_artefact_id = p_src_artefact_id
  loop
    -- apply per-field propagation as per rules (pseudo-code):
    -- for each allowed (src_field -> dst_field) in propagation_rules:
    --   update dst artefact set dst_field = src_value
    --   record in propagated_fields audit json
    null; -- implement per-repo column set
  end loop;
end;
$$;

-- Trigger: on RESEARCH artefacts AFTER UPDATE
-- invokes propagate_corrections() only for whitelisted fields.
```

---

## 7) Instrument/Automation Accounts

- Dedicated users flagged `is_service_account`.
- Scope membership only in relevant ops sub-scopes with role `instrument`.
- RLS permits:
  - SELECT minimal inputs in ops scope,
  - INSERT/UPDATE process outputs and QC/metrics columns,
  - **No access** to research scopes or virtual entities.

---

## 8) Auditing & Observability

### Audit
- **Unified audit trigger** on all mutating tables capturing:
  - `actor_user_id`, effective `role`, `scope_id`,
  - `operation`, `old/new` diffs,
  - nearest **lineage research scope**,
  - correlation/run ids.
- Store in `app_audit.events` with GIN on jsonb for search.

### Views for Explainability
- `vw_user_visible_artefacts` — materialized/normal view after RLS to ease UI queries.
- `vw_lineage_paths(artefact_id)` — recursive CTE producing ancestor/descendant chains.
- `vw_data_product_slice(user_id)` — shows only attributed products for user’s scopes.

---

## 9) Migration & Rollout Plan

1. **Phase A — Schema:** Create scopes, memberships, lineage, duplication, pools, attribution, propagation tables & functions.
2. **Phase B — RLS:** Enable RLS & apply policies; remove direct table grants; ensure roles have EXECUTE on helper functions.
3. **Phase C — Handover Procedures:** Implement stored procedures:
   - `app_ops.sp_transfer_to_ops(research_scope_id, artefact_ids[], ops_scope_name, whitelist jsonb)`
   - `app_ops.sp_return_to_research(pool_or_dp_id)`
4. **Phase D — Propagation:** Implement rules & triggers for correction flows.
5. **Phase E — Backfill:** Assign scopes to existing artefacts; build lineage; populate memberships.
6. **Phase F — Cutover:** Flip API/UI to rely solely on DB policies; lock legacy paths.

---

## 10) Detailed Stored Procedure Sketches

### 10.1 Transfer to Ops
```sql
create or replace function app_ops.sp_transfer_to_ops(
  p_research_scope uuid,
  p_artefact_ids uuid[],
  p_ops_scope_name text,
  p_whitelist jsonb  -- {"fields":["plate","well","i5","i7","expected_fragment_bp"]}
) returns uuid
language plpgsql security definer as $$
declare v_ops_scope uuid; v_src uuid; v_dst uuid;
begin
  -- ensure or create ops scope
  select scope_id into v_ops_scope from app_security.scopes where name = p_ops_scope_name for update skip locked;
  if v_ops_scope is null then
    insert into app_security.scopes(scope_type,name,parent_scope_id)
    values ('ops', p_ops_scope_name, p_research_scope)
    returning scope_id into v_ops_scope;
  end if;

  foreach v_src in array p_artefact_ids loop
    if not app_provenance.can_read_artefact(v_src) then
      raise exception 'not authorized to transfer artefact %', v_src;
    end if;

    -- duplicate with minimal fields (projection from whitelist to columns is repo-specific)
    insert into app_provenance.artefacts(scope_id, is_virtual /*, whitelisted columns ... */)
    values (v_ops_scope, false /*, ... */)
    returning artefact_id into v_dst;

    insert into app_provenance.artefact_duplicates(src_artefact_id, dst_artefact_id, propagated_fields)
    values (v_src, v_dst, p_whitelist);

    update app_provenance.artefacts set transfer_state='transferred' where artefact_id = v_src;
    insert into app_provenance.lineage(parent_artefact_id, child_artefact_id) values (v_src, v_dst);
  end loop;

  return v_ops_scope;
end;
$$;
```

### 10.2 Return to Research
```sql
create or replace function app_ops.sp_return_to_research(p_dp_id uuid)
returns void language plpgsql security definer as $$
declare r record; v_ref uuid;
begin
  for r in
    select dpa.data_product_id, dpa.source_scope_id
    from app_ops.data_product_attribution dpa
    where dpa.data_product_id = p_dp_id
  loop
    -- per-scope references/duplicates
    insert into app_ops.data_products(scope_id, manifest)
    select r.source_scope_id, dp.manifest
    from app_ops.data_products dp
    where dp.data_product_id = r.data_product_id
    returning data_product_id into v_ref;

    -- optionally: record mapping dp -> ref, and lineage link
  end loop;
end;
$$;
```

---

## 11) Test Plan (Directly Maps to Stories)

- **T1 (Alpha-1,2):** Researcher in Alpha sees Alpha artefacts; cannot see Beta rows (RLS filters).  
- **T2 (Alpha-4):** Research lab_tech cannot read virtual entities if role disallowed; can edit physical fields only (trigger enforces).  
- **T3 (Alpha-5):** Transfer to ops creates duplicates with minimal fields; research source marked `transferred`; lineage recorded.  
- **T4 (Ops-1):** Ops lab tech sees only ops duplicates; cannot see donor PHI (no such fields in ops duplicates; RLS denies research scope).  
- **T5 (Ops-2,3):** Normalization & pooling in ops succeeds; pool membership recorded with fractions.  
- **T6 (Ops-4 + Vis-2):** Data product visibility — Alpha researcher sees only products attributed to Alpha contributions in mixed pool; Beta sees none if not contributor.  
- **T7 (Ops-5):** Return handover creates research-scope product refs; Alpha can see them; ops cannot see research refs.  
- **T8:** Correction propagation (whitelisted field) updates ops duplicate; non-whitelisted field does not propagate.  
- **T9 (Vis-4):** Instrument account can read inputs and write outputs/QC only within its ops scope.  
- **T10:** Audit rows present for each mutation with correct actor/scope/lineage.  
- **T11:** Attempted cross-scope query returns zero rows due to RLS (negative test).  
- **T12:** Column-level guard rejects unauthorized field edits (trigger error).  

---

## 12) Acceptance Criteria

- Enabling RLS does **not** break authorized workflows; unauthorized reads/writes are blocked with clear errors.  
- No cross-study leakage in pooled runs (verified by **T6**).  
- Ops cannot access upstream research metadata; research cannot alter ops process records unless explicitly returned and in-scope.  
- Corrections propagate **only** per whitelist, with audit evidence.  
- Instrument/service accounts operate within least-privilege boundaries.  
- Audit and lineage views support explainability for any user-visible record.

---

## 13) Operational & Performance Notes

- **Indexes:** `artefacts(scope_id)`, `lineage(child_artefact_id)`, `lineage(parent_artefact_id)`, `data_product_attribution(source_scope_id)`, `scope_memberships(user_id,scope_id)`.  
- **Lineage depth:** For very deep DAGs, consider materialized ancestor tables updated on commit for faster queries.  
- **Function safety:** `stable` functions; `SECURITY DEFINER` only where necessary; fixed `search_path`.  
- **Grants:** Revoke direct table access from app role; allow `EXECUTE` on helper functions and procedures only.  
- **Backfills:** Assign scopes and build lineage for existing records before enabling RLS in production.

---

## 14) Glossary

- **Scope:** Security boundary (e.g., study/project, ops run).  
- **Duplicate:** A new artefact in a different scope, with minimal metadata, linked by duplication + lineage.  
- **Lineage:** Directed acyclic graph linking parent→child artefacts/processes.  
- **Attribution:** Mapping from a pooled data product back to each contributing source artefact/scope.  

---

This plan centers all enforcement in PostgreSQL and provides explicit mechanics for **handover**, **multiplexing**, **lineage-aware visibility**, and **correction propagation**, aligned with the clarified requirements.
