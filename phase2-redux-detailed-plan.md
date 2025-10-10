# Detailed Implementation Plan – Phase 2 Redux: Unified Artefact & Provenance Platform

## Objectives
- Replace siloed sample/inventory tables with a unified artefact model that supports subjects, materials, reagents, containers, and data products under a shared provenance graph.
- Preserve and extend row-level security so access can be granted at project, facility, service, or dataset scope without duplicating policy logic.
- Stand up the unified model on the fresh database baseline, reintroducing only the synthetic data and interfaces required for current testing.
- Provide clear API and reporting surfaces for lab operations (storage, custody), scientific staff (lineage, processing), and downstream analytics (provenance-aware datasets).

## Guiding Principles
- **Provenance-first**: all transformations flow through explicit process instances with typed inputs/outputs, enabling full lineage for compliance and analytics.
- **Optional containment**: containers are first-class but orthogonal to provenance; artefacts may exist without a container, allowing atomic samples and donors to be tracked accurately.
- **Configurable semantics**: artefact types, traits, and workflow templates are admin-configurable to accommodate new assays without schema churn.
- **Intentional rollout**: there are no external consumers yet, but internal APIs and fixtures should evolve predictably so downstream clients can onboard without churn.

## Workstreams

### 1. Domain Model Convergence
- Design canonical tables (`artefacts`, `artefact_types`, `artefact_traits`, `process_instances`, `process_io`, `artefact_relationships`) and validate relationships with ERD diagrams.
- Define conventions for artefact kinds (subject, material, reagent, container, data_product, instrument_run, etc.) and trait libraries (divisibility, storage requirements, concentration).
- Document lineage patterns: pooling, splitting, composite assemblies, destructive vs non-destructive derivations.
- Capture multiplexing patterns explicitly: support processes that collapse many inputs into pooled artefacts and later expand them again, recording the matching metadata and evidence needed to reconcile downstream outputs with the upstream contributors.

### 2. Containment & Location
- Model containers as artefacts with associated slot/position metadata (`container_slots`) and assignment history (`artefact_container_assignments`).
- Capture storage hierarchies (facility → unit → sublocation) and allow logical storage (filesystem/S3 paths) using the same containment interfaces.
- Define APIs/views for “what’s in this freezer/plate” and “where is this artefact now,” ensuring history is queryable.

### 3. RBAC & Scope Generalization
- Introduce `scopes` (project, facility, dataset, workflow-run) with `scope_memberships` and `scope_role_inheritance`.
- Map artefacts and processes to scopes through linking tables; update security functions (`can_access_artefact`, `can_access_process`) to evaluate scope membership.
- Extend existing RLS policies to new tables; regression-test security via `scripts/test_rbac.sh` with refreshed fixtures representing multi-scope scenarios.

### 4. Data Seeding & Legacy Reference
- Curate new seed datasets that exercise artefact lineage, containment, and scope permutations representative of target workflows.
- Identify any high-value test records from the prior schema and script one-way imports into the new tables when they illuminate edge cases.
- Capture mapping notes that explain how old constructs (samples, labware, inventory) translate to artefact concepts for developer orientation.
- Remove unused compatibility stubs and document that legacy endpoints are deprecated alongside the schema reset.

### 5. API & Integration Updates
- Update PostgREST/PostGraphile schema exposure to surface unified artefact/process entities with filtered views for common personas (samples, reagents, data products).
- Provide reference GraphQL/REST endpoints demonstrating lineage traversal, scope-aware search, and containment reporting.
- Ensure automation/instrument ingestion workflows can register processes and outputs without manual intervention.
- Include provenance endpoints that materialize multiplexed lineage: expose pooled membership, downstream remapping logic, and any evidence/confidence used to relate outputs back to their contributing inputs alongside the core process graph.

### 6. Documentation & Enablement
- Produce developer guide covering the unified model, schema diagrams, and canonical query patterns (lineage, custody, storage).
- Update operational runbooks for lab staff to reflect new data entry/check-out flows.
- Draft ELN integration guidelines showing how notebook entries instantiate process instances and attach artefacts.

## Milestones & Deliverables
- **M1 – Model Blueprint (Week 1)**: ERD + glossary + RLS design doc, vetted with domain SMEs.
- **M2 – Schema & Seed Data (Week 3)**: DDL migrations committed, seed scripts populating core lookups and sample datasets.
- **M3 – RBAC Regression (Week 4)**: Updated policies passing automated RBAC/security tests; sign-off from security review.
- **M4 – API Readiness (Week 5)**: PostgREST/PostGraphile exposures built directly on the unified schema; smoke tests confirm coverage for planned personas.
- **M5 – Provenance & Containment Dashboards (Week 6)**: Example notebooks/reports showcasing lineage and storage tracking end-to-end.

## Dependencies & Coordination
- Align with ELN/workflow team to ensure process templates map cleanly to notebook entries and automation events.
- Coordinate with infrastructure for storage of large data products (object store credentials, lifecycle policies).
- Engage compliance/QA on audit log requirements for new tables and process events.

## Risks & Mitigations
- **Fixture gaps**: collaborate with domain SMEs to ensure synthetic data represents critical workflows; expand seeds before API consumers rely on them.
- **Performance of RLS checks**: benchmark scope-resolution functions; add indexes/materialized grants views per scope.
- **User adoption**: provide training materials and phased rollout (read-only previews before write enablement).
- **Schema entropy**: enforce governance for new artefact types/traits through admin workflows and documentation updates.

## Exit Criteria
- Unified artefact/provenance schema deployed on the reset baseline with curated synthetic data covering priority workflows.
- RBAC policies validated for multi-scope scenarios; audit logs capturing all artefact/process/containment changes.
- Operational playbooks and developer docs reference only the new schema; feedback loop established for Phase 3 planning.
