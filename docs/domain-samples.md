# Unified Artefact & Provenance Overview

Phase 2 Redux consolidates donors, samples, reagents, labware, instrument runs, and data products under the `app_provenance` schema. Every entity the lab needs to track becomes an **artefact**, with provenance edges describing how material moves and transforms over time. This document summarises the core concepts so developers and scientists can reason about the new model without having to page through migrations.

## What Makes an Artefact a “Sample”?

The previous schema elevated “samples” as a dedicated table. In the unified model, a **sample** is an artefact whose type has `kind = 'material'`. The same principles still hold:

- Samples represent coherent material whose identity persists even when subdivided. Divisible material (e.g. lysate, DNA libraries) can occupy multiple containers simultaneously, while atomic material (e.g. whole insects) usually sits in a single container.
- Transforming material—splitting, pooling, amplifying—creates new sample artefacts linked back to their parents. The new artefact may inherit traits (such as donor, collection protocol) and adds context about the process that produced it.
- Aliquots are not separate “sample vs. aliquot” tables; instead, each placement is tracked through container assignments while the underlying sample artefact retains continuity.

Views such as `app_core.v_sample_overview` filter material artefacts to deliver the familiar sample-centric perspective for researchers, preserving the mental model while benefiting from the broader artefact framework.

## Artefact Basics

- `app_provenance.artefacts` holds the canonical records for physical material, digital deliverables, containers, instruments, and workflow placeholders. Each row references an `artefact_type` that defines its semantics (e.g. `material`, `reagent`, `container`, `data_product`, `subject`).
- Artefacts carry lifecycle metadata (`status`, `created_at`, `origin_process_instance_id`), optional identifiers (`external_identifier`, `barcode` in `metadata`), and flags indicating whether they are divisible or consumable. This replaces the old `lims.samples` table.
- Flexible attributes live in `artefact_traits` and `artefact_trait_values`, allowing traits such as concentration, storage temperature, or barcode chemistry to be attached without schema churn. Trait history is versioned with `effective_at` timestamps.

The schema treats donors, aliquots, kits, sequencing libraries, instrument runs, and derived data sets the same way. Downstream interfaces can still present “sample views” or “inventory views” by filtering on `artefact_types.kind` and traits.

## Provenance & Lineage

- `process_instances` capture each lab or informatics activity (extraction, pooling, sequencing, demultiplexing). A process references a `process_type`, tracks timing and operator metadata, and may be scoped to projects/facilities.
- `process_io` ties artefacts to processes as inputs or outputs. Roles and optional `multiplex_group` values model pooled or latent connections—e.g. multiple indexed libraries contributing to a pooled sample and later demultiplexed into per-sample data products.
- `artefact_relationships` store direct parent/child edges (split, merge, derived_from, etc.) and link back to the originating `process_instance_id`. This accommodates both simple derivations and many-to-many graphs.

Together these structures provide a first-class provenance graph: artefacts connect to processes, which connect back to artefacts. Lineage queries in `v_sample_lineage`, `v_process_activity`, and related views traverse the graph while respecting row-level security.

## Containment & Storage

- Containers are artefacts whose type `kind` is `container`. Slot layouts reside in `container_slots`; actual placements are recorded in `artefact_container_assignments` with quantity metadata and timestamps.
- Physical and logical storage locations are modelled via `storage_nodes`, and movements are recorded in `artefact_storage_events`. Helper views (`v_artefact_current_location`, `v_storage_tree`) provide current placements and hierarchical storage paths.
- Because containers and locations participate as artefacts, the model handles “sample in tube in rack in freezer” or “data product stored in S3 prefix” uniformly.

## Access Control & Scoping

- Artefacts and processes are tagged to scopes using `artefact_scopes` and `process_scopes`. Scopes cascade permissions via the scope inheritance fabric defined in Phase 1 Redux (`app_security.scopes`, `scope_memberships`, `scope_role_inheritance`).
- RLS functions such as `app_provenance.can_access_artefact` and `app_security.actor_has_scope` ensure that researchers only observe artefacts tied to their projects or facilities. Operators and admins retain broad visibility.

PostgREST/PostGraphile expose curated views (`app_core.v_sample_overview`, `app_core.v_labware_contents`, `app_provenance.v_lineage_summary`, etc.) so front-end workflows can present persona-friendly perspectives without breaking the unified model.

## Seeded Scenarios

Migration `20251010013000_phase2_redux_seed.sql` and its follow-ups populate representative datasets used in demos and regression tests:

- **Organoid expansion** lineage covering cryopreservation, RNA/protein derivatives, and storage moves.
- **LCMS spike-in analysis** mixing participant plasma with QA reagents to illustrate converging parents and facility scopes.
- **PBMC multi-omics workflow** showing diamonds, splits, merges, and eventual sequencing data products with multiplexed provenance.

Each scenario includes scopes, labware placements, and audit trails. Running `make db/reset` followed by `make test/security` or `make contracts/export` rebuilds the database and regenerates API contracts so the documentation stays aligned with the deployed schema.
