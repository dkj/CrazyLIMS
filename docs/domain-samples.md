# Material Artefact Domain Overview

In the Phase 2 redux model a "sample" is always tied to its physical location.
Rather than tracking abstract sample records plus separate labware
assignments, each **material artefact** is the combination of:

- The container it currently occupies (via `plate_id`, `tube_id`, etc.).
- The precise slot or coordinates inside that container (e.g.,
  `plate_slot='A1'`).
- The material traits that describe the contents (volume, concentration,
  fragment profile, QC decisions, and other assay-specific metadata).

When material moves to a different container, the LIMS creates a **new derived
artefact** that represents the destination location. Provenance edges record the
relationship between the old and new artefacts so lineage remains intact without
needing a separate "sample" entity floating between containers.

## Artefact Lineage

Material derivations remain central to the schema, but they now operate entirely
between artefacts:

- Splits and aliquots create multiple child artefacts, each anchored to its own
  container slot.
- Pools link several parent artefacts to a single child artefact that occupies a
  new container slot.
- Transformations that change material properties (e.g., PCR, size selection)
  emit new artefacts whose traits capture the post-process state.

These events are captured with `artefact_relationships` rows that identify the
parent(s), child(ren), and the `process_instance` responsible for the change.

## Container Context

Containers such as plates, tubes, cartridges, or reservoirs are themselves
artefacts of kind `container`. They define geometry via traits (plate layout,
capacity, temperature tolerances) and are referenced directly by material
artefacts. No intermediary table like `artefact_container_assignments` is
required—the material artefact's foreign keys and slot traits provide everything
needed to determine where the material physically resides.

This approach keeps containment queries straightforward:

- To list the contents of a plate, filter material artefacts by `plate_id` and
  order by their `plate_slot` trait.
- To discover what remains of an aliquot, inspect the traits on the artefact in
  its current container slot.

## Trait Updates & Measurements

Because each artefact embodies both the slot and the material, measurements and
QC results are written directly onto that artefact's traits. Repeat measurements
append new trait values that reference the measurement process in
`provenance_process_id`, giving auditors a history of assertions without
needing cross-container reconciliation logic.

If conflicting measurements arise (for example, after a transfer that should
have produced identical aliquots), the divergence naturally appears as different
trait histories on the distinct artefacts. Labs can decide whether to branch the
lineage further or flag a QC exception without overloading a shared sample
record.

## Visibility & Scoping

Project and facility scoping rules continue to operate on artefacts. A project
owns the material artefacts it produces; downstream derivatives inherit scope
via provenance edges, and RLS helpers such as `can_access_artefact` enforce the
appropriate permissions. Because there is no separate sample catalogue, access
checks always evaluate the artefact directly involved in a process or
measurement.

## Practical Usage

When implementing workflows:

1. Create or reserve the destination container artefact (plate, tube, etc.).
2. Instantiate new material artefacts for each occupied slot, setting the slot
   trait and initial properties (volume, expected concentration, etc.).
3. Link them back to source artefacts through `artefact_relationships` with the
   relevant `process_instance`.
4. Update traits as instruments or analysts record new measurements; provenance
   metadata on each trait keeps the historical context intact.

This streamlined model removes redundant containment tables, keeps physical
reality front and centre, and simplifies queries for both lab operators and
analysts.
