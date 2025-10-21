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

## 3) Data Model Touchpoints (Reuse First)

Phase 2 Redux already delivered the tables we need. Security Redux focuses on **selective augmentation** rather than introducing parallel schemas.

### 3.1 Scope Fabric (no structural change)
- Continue using `app_security.scopes`, `scope_memberships`, and `scope_role_inheritance`, along with helper functions such as `actor_scope_roles`, `actor_has_scope`, and `current_actor_id`.  
- Standardise naming only: projects keep `project:*`; ops runs and automation scopes become child scopes (e.g. `ops:normalisation:2024-07-15`) seeded through existing upsert jobs.  
- Service accounts and instruments remain regular `scope_memberships` rows. Any additional persona roles are inserted via seed data, not DDL.

### 3.2 Artefact & Lineage Representation
- `app_provenance.artefact_scopes` remains the canonical mapping between artefacts and scopes. Ops duplicates and returned deliverables gain extra rows here; transfer state is captured in `artefact_traits` (new trait key `transfer_state`) so we retain history without altering the base table.  
- Duplication links are expressed with `app_provenance.artefact_relationships` by introducing a new `relationship_type = 'handover_duplicate'`. Relationship metadata holds the propagated field whitelist and timestamps, keeping everything in one provenance graph.  
- Existing recursive views (`app_core.v_sample_lineage`, `app_provenance.v_lineage_summary`) just need minor filters to surface downstream ops artefacts; no new tables. Add a covering index on `(relationship_type, parent_artefact_id)` if performance testing proves it useful.
- The only new schema artefacts are helper functions/procedures plus the `transfer_state` trait and the `app_core.v_handover_overview` view. Both reuse the existing trait infrastructure and provenance tables—no additional base tables or columns are introduced.

### 3.3 Pools, Multiplexing & Data Products
- Pools, normalisation runs, and demultiplexed outputs continue to live in `app_provenance.process_instances` with `process_io.direction IN ('pooled_input','pooled_output')` and `multiplex_group` populated. Where needed we add seed data for new `process_type` definitions—no schema change.  
- Data products remain artefacts (`artefact_types.kind = 'data_product'`). Attribution to contributing research scopes is handled via additional `artefact_scopes` rows or lightweight reference artefacts typed `data_product_reference`. This reuses existing RLS on artefacts and scopes.  
- Optional enhancements: add a partial index on `process_io(process_instance_id, direction)` for pooled workloads, and create a view (`app_provenance.v_data_product_attribution`) joining artefact scopes to process IO for fast per-project slices.

### 3.4 Correction Propagation
- Propagation rules ride on the `handover_duplicate` relationship metadata (`metadata -> 'propagation_whitelist'`). That avoids a separate table while still supporting per-field control.  
- A helper function (see §6) reads the whitelist and reapplies updated values by writing to traits or metadata on the duplicate artefact. Because the whitelist is stored in metadata, ops teams can adjust whitelisted fields via regular updates without a migration.

---

## 4) Authorization Model (Reuse + Targeted Deltas)

### 4.1 Session Context
- Lean on the existing transaction-context plumbing (`app_security.start_transaction_context`, `finish_transaction_context`) to stamp `app.actor_id`, `app.roles`, and JWT claims.  
- Ensure migrations and fixtures keep the seed users/scopes used by `ops/db/tests/security.sql` so tests can continue to `SET ROLE app_researcher` et al without additional scaffolding.  
- No new GUCs are required; instead we document the expectation that UI/API layers set `app.impersonated_roles` when acting on behalf of another user.

### 4.2 Helper Functions
- Extend the shipped `app_provenance.can_access_artefact` function so that, in addition to direct scope membership, it grants read access if the user holds membership in any ancestor artefact via `artefact_relationships` (e.g. follows `handover_duplicate`, `derived_from`, or `pooled_from` edges up the provenance graph). This keeps the lineage-aware visibility requirement self-contained.  
- Reuse `app_provenance.can_access_process` and `app_security.actor_has_scope` unchanged; they already honour scope inheritance.  
- Add a tiny wrapper `app_provenance.can_update_handover_metadata(artefact_id)` that checks both scope write privileges and that the artefact still sits in an ops scope (prevents research users from mutating ops-only traits). This is a thin SQL function referencing existing helpers.

### 4.3 Policy Adjustments
- Artefact policies remain defined on `app_provenance.artefacts`; once `can_access_artefact` understands lineage, downstream visibility (including returned data-product references) works automatically. Column-guard triggers stay focused on trait-level updates; we only extend their allowlists to include ops-specific QC fields and the new `transfer_state` trait.  
- `app_provenance.artefact_relationships` already enforces access through `can_access_artefact`. We add regression tests ensuring `handover_duplicate` links are readable when either side is visible.  
- `app_provenance.process_instances` and `process_io` policies continue to call `can_access_process`. Additional acceptance tests cover pooled workloads so we do not relax those policies by mistake.  
- No standalone `app_ops` tables exist; data products share the artefact policies. Ensuring they receive correct `artefact_scopes` rows is sufficient for RLS.  
- Audit triggers remain untouched; they continue to capture mutations for artefacts, traits, relationships, and processes.

---

## 5) Handover Protocol (Research ⇄ Ops)

### 5.1 To Ops (Research → Ops)
1. **Select** research artefacts to transfer (plates, wells, library tubes).  
2. **Ensure** an ops child scope exists beneath the originating project (`scope_memberships` grants for ops staff + instruments).  
3. **Insert** new artefacts in the ops scope using the existing artefact type definitions. Populate only the minimal metadata needed by ops (indexes, expected fragment sizes, QC placeholders).  
4. **Record** provenance by inserting an `artefact_relationships` row with `relationship_type = 'handover_duplicate'` from research artefact → ops artefact. Store the propagated-field whitelist in `metadata -> 'propagation_whitelist'`.  
5. **Update** the source artefact’s `transfer_state` trait (via `artefact_trait_values`) to `'transferred'`.  
6. **Log** the handover process via `process_instances`/`process_io` so we can audit who performed the transfer and what was duplicated.

### 5.2 Within Ops
- Ops users and instruments work exclusively on artefacts scoped to the ops child scope. They create further artefacts and process instances as normal; RLS already isolates them.  
- Pools and data products are recorded as standard artefacts emitted by ops processes. `process_io` entries capture pooled inputs/outputs with `multiplex_group` identifiers.  
- Each data-product artefact receives `artefact_scopes` rows for every contributing research scope (derived from lineage back through `handover_duplicate` edges), enabling downstream researchers to see only their fraction.

### 5.3 Return to Research (Ops → Research)
1. For each data-product artefact, **fan out** lightweight reference artefacts (type `data_product_reference`) in the relevant research scopes, or simply add additional `artefact_scopes` rows if the canonical artefact can remain shared.  
2. Create reciprocal `artefact_relationships` (`relationship_type = 'returned_output'`) from the ops artefact to each research reference to preserve provenance.  
3. Update the ops artefact’s `transfer_state` trait to `'returned'` once confirmation arrives, and ensure the original research artefact receives lineage edges to any downstream physical artefacts produced from the returned data.

---

## 6) Correction Propagation

### Policy
- Upstream corrections (e.g. amending an index tag) propagate from a research artefact to its ops duplicate only when the corresponding `handover_duplicate` relationship lists the field in `metadata -> 'propagation_whitelist'`.  
- Propagation is blocked beyond ops once the duplicate’s `transfer_state` trait is `'returned'` or the associated process instance is marked `completed`.

### Mechanism
```sql
-- Skeleton – updates existing function rather than introducing a new table.
create or replace function app_provenance.propagate_handover_corrections(p_src_artefact_id uuid)
returns void
language plpgsql
security definer
set search_path to pg_catalog, public, app_provenance, app_security
as $$
declare
  rel record;
  whitelist text[];
begin
  for rel in
    select
      ar.child_artefact_id  as dst_artefact_id,
      coalesce((ar.metadata -> 'propagation_whitelist')::text[], '{}') as allowed_fields
    from app_provenance.artefact_relationships ar
    where ar.parent_artefact_id = p_src_artefact_id
      and ar.relationship_type = 'handover_duplicate'
  loop
    whitelist := rel.allowed_fields;
    if array_length(whitelist, 1) is null then
      continue;
    end if;

    -- domain-specific projection: update traits/metadata on the duplicate.
    perform app_provenance.apply_whitelisted_updates(
      p_src_artefact_id    => p_src_artefact_id,
      p_dst_artefact_id    => rel.dst_artefact_id,
      p_fields             => whitelist
    );
  end loop;
end;
$$;
```

> `app_provenance.apply_whitelisted_updates` is a small internal helper that reads the requested fields from the source artefact’s metadata/traits and writes them to the destination artefact, recording audit metadata on the relationship. We keep it flexible so each repo can decide which columns/traits participate.

- A trigger on research artefacts (`AFTER UPDATE`) calls `propagate_handover_corrections` when any field listed in a whitelist changes. The trigger inspects `TG_ARGV` to limit the scope (e.g. only certain metadata keys).

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
- Keep the existing `app_security.audit_log` + `app_security.record_audit()` trigger stack that already covers artefacts, traits, processes, and relationships.  
- Extend the trigger arguments where necessary so audit rows carry `metadata -> 'scope_key'`, `metadata -> 'relationship_type'`, and any propagated-field updates performed by `apply_whitelisted_updates`.  
- Add a convenience view `app_security.v_audit_transfer_events` joining audit rows to `artefact_relationships` for quick inspection of handovers and returns.

### Views for Explainability
- `app_provenance.v_lineage_summary` gains columns highlighting whether an artefact is ops-scoped, returned, or pending return (driven from traits + relationship metadata).  
- A new view `app_provenance.v_data_products_per_scope` (likely materialised in production) joins artefact scopes, process IO, and handover metadata to surface exactly which deliverables a user may see.  
- Existing front-end views (`v_sample_overview`, `v_labware_contents`, etc.) should be regression-tested; any scope filters they contain stay unchanged because visibility continues to flow through `can_access_artefact`.

### UI Integration (DB-side Support)
- Use `app_core.v_handover_overview` for handover dashboards; it exposes both artefact names, scope memberships, transfer-state traits, whitelists, and audit timestamps in a single RLS-respecting view.  
- `docs/ui-handover-integration.md` outlines how to call the stored procedures and leverage the view from the web UI.  
- The view keeps `propagation_whitelist` as a text array for easy surfacing in multi-select widgets; the underlying metadata remains authoritative for propagation logic.

---

## 9) Migration & Rollout Plan

1. **Phase A — Metadata & Seeds:** Add the `handover_duplicate` and `returned_output` relationship types, seed the `transfer_state` trait definition, and create any optional indexes identified in §3.  
2. **Phase B — Helper Enhancements:** Extend `can_access_artefact`, add the lightweight `can_update_handover_metadata` wrapper, and document the lineage recursion contract.  
3. **Phase C — Stored Procedures:** Implement the `app_provenance.sp_handover_to_ops` and `app_provenance.sp_return_from_ops` helpers plus supporting utilities (`project_handover_metadata`, `set_transfer_state`, `apply_whitelisted_updates`).  
4. **Phase D — Propagation:** Wire the AFTER UPDATE trigger that calls `propagate_handover_corrections` and backfill whitelist metadata on existing handover relationships.  
5. **Phase E — Backfill:** Assign ops scopes to existing duplicates, populate relationship metadata, and ensure pooled data products carry the new scope tags.  
6. **Phase F — Cutover:** Flip API/UI to rely solely on the DB policies/tests and retire any legacy access paths.

---

## 10) Detailed Stored Procedure Sketches

### 10.1 Transfer to Ops
```sql
create or replace function app_provenance.sp_handover_to_ops(
  p_research_scope_id uuid,
  p_ops_scope_key text,
  p_artefact_ids uuid[],
  p_field_whitelist text[] DEFAULT '{}'
) returns uuid
language plpgsql
security definer
set search_path to pg_catalog, public, app_provenance, app_security, app_core
as $$
declare
  v_ops_scope_id uuid;
  v_src uuid;
  v_dst uuid;
  v_metadata jsonb := jsonb_build_object('propagation_whitelist', p_field_whitelist);
begin
  select scope_id
    into v_ops_scope_id
    from app_security.scopes
   where scope_key = p_ops_scope_key
   for update;

  if v_ops_scope_id is null then
    insert into app_security.scopes(scope_key, scope_type, display_name, parent_scope_id, metadata)
    values (
      p_ops_scope_key,
      'ops',
      replace(p_ops_scope_key, ':', ' / '),
      p_research_scope_id,
      jsonb_build_object('seed', 'handover')
    )
    returning scope_id into v_ops_scope_id;
  end if;

  foreach v_src in array p_artefact_ids loop
    if not app_provenance.can_access_artefact(v_src) then
      raise exception 'not authorized to transfer artefact %', v_src;
    end if;

    insert into app_provenance.artefacts (
      artefact_type_id,
      name,
      metadata,
      container_artefact_id,
      container_slot_id,
      origin_process_instance_id,
      is_virtual
    )
    select
      a.artefact_type_id,
      a.name,
      app_provenance.project_handover_metadata(a.metadata, p_field_whitelist),
      a.container_artefact_id,
      a.container_slot_id,
      a.origin_process_instance_id,
      false
    from app_provenance.artefacts a
    where a.artefact_id = v_src
    returning artefact_id into v_dst;

    insert into app_provenance.artefact_scopes(artefact_id, scope_id, relationship)
    values (v_dst, v_ops_scope_id, 'primary');

    insert into app_provenance.artefact_relationships(
      parent_artefact_id,
      child_artefact_id,
      relationship_type,
      metadata
    )
    values (
      v_src,
      v_dst,
      'handover_duplicate',
      v_metadata
    );

    perform app_provenance.set_transfer_state(v_src, 'transferred');
  end loop;

  return v_ops_scope_id;
end;
$$;
```

### 10.2 Return to Research
```sql
create or replace function app_provenance.sp_return_from_ops(
  p_ops_artifact_id uuid,
  p_research_scope_ids uuid[]
) returns void
language plpgsql
security definer
set search_path to pg_catalog, public, app_provenance, app_security, app_core
as $$
declare
  v_scope uuid;
  v_ref uuid;
begin
  foreach v_scope in array p_research_scope_ids loop
    -- Either attach the canonical artefact to the research scope...
    insert into app_provenance.artefact_scopes (artefact_id, scope_id, relationship)
    values (p_ops_artifact_id, v_scope, 'derived_from')
    on conflict (artefact_id, scope_id) do nothing;

    -- ...and/or create a lightweight reference artefact per scope.
    insert into app_provenance.artefacts (artefact_type_id, name, metadata, is_virtual)
    select
      ref_type.artefact_type_id,
      a.name || ' (returned)',
      jsonb_build_object('source_ops_artifact', p_ops_artifact_id),
      true
    from app_provenance.artefacts a
    join app_provenance.artefact_types ref_type
      on ref_type.type_key = 'data_product_reference'
    where a.artefact_id = p_ops_artifact_id
    returning artefact_id into v_ref;

    insert into app_provenance.artefact_scopes (artefact_id, scope_id, relationship)
    values (v_ref, v_scope, 'primary');

    insert into app_provenance.artefact_relationships (
      parent_artefact_id,
      child_artefact_id,
      relationship_type
    ) values (
      p_ops_artifact_id,
      v_ref,
      'returned_output'
    );
  end loop;

  perform app_provenance.set_transfer_state(p_ops_artifact_id, 'returned');
end;
$$;
```

### 10.3 Prototype Walkthrough
1. Use `db.session.sql` (or an ad-hoc psql script) to call `app_provenance.sp_handover_to_ops` for a seeded research artefact; capture the returned ops scope id.  
2. Run existing ops processes (normalisation + sequencing) by inserting `process_instances`/`process_io` rows, ensuring pooled outputs carry both ops and research scope tags.  
3. Trigger `app_provenance.sp_return_from_ops`, then query `app_provenance.v_lineage_summary` to confirm the returned references and scope visibility were created.  
4. Verify RLS expectations by running the corresponding `SET ROLE` blocks from `ops/db/tests/security.sql`, mirroring the automated tests before codifying them.

---

## 11) Test Plan (Directly Maps to Stories)

- **T1 (Alpha-1,2):** Researcher in Alpha sees Alpha artefacts; cannot see Beta rows (RLS filters).  
- **T2 (Alpha-4):** Research lab_tech cannot read virtual entities if role disallowed; can edit physical fields only (trigger enforces).  
- **T3 (Alpha-5):** Transfer to ops produces `handover_duplicate` relationships, creates ops-scope artefacts with minimal metadata, and stamps the research artefact’s `transfer_state = 'transferred'`.  
- **T4 (Ops-1):** Ops lab tech sees only ops-scope artefacts; ancestor research metadata remains hidden (RLS on artefacts/traits).  
- **T5 (Ops-2,3):** Normalisation & pooling flows record `process_io` entries with `multiplex_group`, and pooled outputs inherit per-project scope tags.  
- **T6 (Ops-4 + Vis-2):** Data product artefacts tagged for both ops and research scopes enforce per-contributor visibility in mixed pools.  
- **T7 (Ops-5):** Return handover attaches research scope references (`returned_output` relationships) and flips ops artefact `transfer_state` to `'returned'`; ops users cannot see the research-only references.  
- **T8:** Correction propagation applies only to whitelisted fields in `artefact_relationships.metadata`, leaving other fields untouched.  
- **T9 (Vis-4):** Instrument account can read inputs and write outputs/QC inside its ops scope but remains denied access outside.  
- **T10:** Audit log rows capture handover, propagation, and return events with correct actor + scope context.  
- **T11:** Attempted cross-scope reads (e.g. Alpha user on Beta artefacts) still return zero rows after lineage enhancements.  
- **T12:** Column-level guard rejects unauthorized field edits (trigger error).

### 11.1 Implementation Backlog (TDD)
- **security.sql::handover_visibility** — add fixtures that call `sp_handover_to_ops`, assert `app_provenance.can_access_artefact` grants lineage-based reads, and confirm Alpha cannot see Beta artefacts.  
- **security.sql::ops_personas** — extend instrument/ops user sections to exercise pooled processes, validating `process_io` visibility and QC write restrictions.  
- **security.sql::data_product_return** — script a pooled sequencing run, call `sp_return_from_ops`, ensure returned references are visible only to contributing scopes, and verify audit rows.  
- **security.sql::propagation_controls** — cover whitelist updates by toggling trait values and confirming propagation fires (and non-whitelisted fields remain unchanged).  
- **security.sql::negative_cases** — add regression tests for cross-scope read attempts and mutation attempts once `transfer_state = 'returned'`.

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

- **Indexes:** consider `(relationship_type, parent_artefact_id)` on `artefact_relationships`, `(process_instance_id, direction, artefact_id)` on `process_io`, and GIN on `artefact_relationships.metadata` for whitelist lookups.  
- **Lineage depth:** For very deep DAGs, materialised ancestor tables (or cached closure tables) remain optional but should reuse the existing provenance graph.  
- **Function safety:** Keep helpers `stable`, `SECURITY DEFINER` only where necessary, and always fix `search_path`.  
- **Grants:** Revoke direct table access from application roles; expose only the stored procedures/views documented here.  
- **Backfills:** Tag legacy ops artefacts with `artefact_scopes`, seed `transfer_state` traits, and populate relationship metadata before enabling the enhanced RLS.

### Migration Footprint & Rollback
- `20251010015000_security_redux_handover.sql` introduces helper functions, the `transfer_state` trait, and the propagation trigger. Rollback simply drops the helpers and trait rows; for production rollbacks ensure no workflows rely on the new procedures.  
- `20251010015100_security_redux_handover_views.sql` is read-only: it backfills missing propagation metadata and creates `app_core.v_handover_overview`. Rollback removes the view; the metadata backfill is idempotent and safe to rerun.  
- Backfill plan: run the migrations, execute the provided backfill script (or rerun the metadata update) in a maintenance window, then re-run `make db/test` to verify RLS behaviour before releasing to UI clients.
- `20251010015300_security_redux_story_data.sql` seeds an end-to-end demo dataset covering **Project Alpha**, **Project Beta**, and the **Ops Lab** facility. It creates the study scopes, enrols realistic personas (researchers, ops techs, instrument account), and populates the entire provenance workflow (virtual donors → P202/D203/L204 → ops plates → pooling → returned readsets). The migration tags every artefact, relationship, and trait with `seed=security-redux-story` so `migrate:down` removes the dataset cleanly.

---

## 14) Glossary

- **Scope:** Security boundary (e.g., study/project, ops run).  
- **Duplicate:** A new artefact in a different scope, with minimal metadata, linked by duplication + lineage.  
- **Lineage:** Directed acyclic graph linking parent→child artefacts/processes.  
- **Attribution:** Mapping from a pooled data product back to each contributing source artefact/scope.  

---

This plan centers all enforcement in PostgreSQL and provides explicit mechanics for **handover**, **multiplexing**, **lineage-aware visibility**, and **correction propagation**, aligned with the clarified requirements.
