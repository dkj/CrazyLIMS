# Samples Domain Overview

A **sample** represents a coherent unit of material – usually biological – whose identity persists regardless of how many containers currently hold portions of it. A single sample may therefore appear in one or many pieces of labware:

- Whole organisms or unique artifacts may reside in exactly one container.
- Extracted material (DNA, RNA, lysate, etc.) often spans multiple containers such as arrival plates, aliquot tubes, and reserve stock plates.

Any process that changes the nature of the material results in a **derivative sample**. Derivations may:

- Split one sample into multiple children (e.g., size-selection yielding "large" and "small" fractions).
- Combine multiple parent samples into a new child (e.g., pooling indexed libraries into a sequencing run).

The schema captures these concepts through:

- `lims.samples` – canonical sample records with project ownership.
- `lims.sample_derivations` – parent/child edges; multiple parents per child and multiple children per parent are supported.
- `lims.sample_labware_assignments` – point-in-time placement of samples in labware wells or slots.

## Project Visibility

Sample visibility is governed by project membership, not the user who created the record. `lims.projects` catalogs projects, and `lims.project_members` associates users with the projects they are allowed to view. RLS policies ensure:

- Administrators/operators can access all projects and samples.
- Researchers see only the projects (and thus samples) they are explicitly assigned to.

This model allows teams to collaborate on shared material while keeping unrelated projects isolated.

## Labware Relationships

Samples link to labware through assignments, allowing multiple simultaneous placements. When a new labware record is created for a sample, an assignment is inserted, and the sample tracks its current labware for quick lookups. Historical movements remain available in `lims.labware_location_history`.

## Derivation Workflows

When recording a derivation event:

1. Create the new sample (if not already present) under the appropriate project.
2. Insert one or more rows into `lims.sample_derivations` to capture the parent-child relationships and method metadata.
3. Update labware assignments to show where the derivative material resides.

Future enhancements will add workflow-aware helpers, but the current schema already supports complex provenance chains.

## Seeded Provenance Examples

The demo database now seeds several provenance graphs to mirror the pre-redux examples while also covering the new redux prompt scenarios:

- **Organoid expansion** – `Organoid Expansion Batch RDX-01` demonstrates linear growth, parallel derivative extractions (RNA + protein), and a cryopreserved backup branch, all owned by project `PRJ-002`.
- **LCMS spike-in analysis** – `LCMS Run 042 Analyte Panel` joins provenance from a participant plasma prep and a newly created quality-control mixture to illustrate converging parents.
- **PBMC multi-omics workflow** – New enrichment, RNA, protein, and library samples extend the `PBMC Batch 001` lineage to show diamonds and re-converging descendants inside `PRJ-001`.

Two additional researcher personas (`carol@example.org`, `diego@example.org`) are added to cover collaboration flows and ensure the provenance explorer has multiple contributor viewpoints.
