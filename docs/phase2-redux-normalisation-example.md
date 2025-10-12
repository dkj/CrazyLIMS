# Phase 2 Redux Example: Plate Quantification & Normalisation Workflow

This worked example exercises the new artefact/provenance schema for a common
size-selection workflow. It walks through the data structures that the LIMS
maintains when a 96-well plate of size-fragmented DNA is quantified and then
normalised by a liquid-handling robot.

## Scenario Overview

| Item | Count | Artefact Kind | Notes |
| --- | --- | --- | --- |
| Size-selected DNA wells | 94 | `material` | Scientific samples whose concentration and fragment distribution are initially unknown |
| Positive control | 1 | `reagent` | Commercial DNA ladder with known concentration/size profile |
| Negative control | 1 | `reagent` | Nuclease-free water |
| Source plate | 1 | `container` | 96 positions, traits include `plate-format=96`, `well-volume=uL` |
| Normalised plate | 1 | `container` | Created after the robot run |
| Buffer reservoir | 1 | `reagent` | Supplied to robot for dilution |
| Quantification instrument run | 1 | `instrument_run` | Parent for the measurement data product |
| Measurement data file | 1 | `data_product` | Structured CSV/JSON emitted by the quantifier |
| Normalisation robot run | 1 | `instrument_run` | Provides activity log for transfers |
| Robot manifest | 1 | `data_product` | Input manifest authored by LIMS |
| Robot activity report | 1 | `data_product` | Output detailing dispenses/aspirations |

## Initial State: Artefacts & Containment

1. **Samples vs controls**
   - The 94 scientific wells share a parent sample lineage (e.g.,
     `sample_group=Fragmented DNA`). Each child artefact *is* the specific
     physical well location plus its contents. The artefact stores the slot code
     (`plate_slot='A1'`) as a trait and inherits lineage from the parent sample
     via `artefact_relationships(kind='derived-from')`. There is no separate
     "sample-only" artefact sitting outside of labware; if material moves to a
     new plate, that transfer creates a new derived artefact tied to the
     destination well.
   - The positive and negative controls are catalogued as `reagent` artefacts
     with immutable properties such as `expected_concentration_ng_per_uL` and
     `expected_fragment_distribution`.

2. **Container representation**
   - The source plate is a `container` artefact with traits describing its
     geometry (e.g., `plate-format=96`). Wells no longer require a separate
     `artefact_container_assignments` row; the physical relationship is implied
     by the well artefact's `plate_id` foreign key and `plate_slot` trait.
   - Because the well artefact represents "contents + coordinates" it is the
     canonical home for properties such as volume, concentration, fragment
     distribution, and QC status. This keeps sample traits scoped to the specific
     physical instance, so two plates holding aliquots derived from one another
     are represented by separate artefacts rather than a shared sample record.

3. **Traits**
   - Scientific material artefacts hold mutable traits such as
     `observed_volume_uL`, `measured_concentration_ng_per_uL`, and
     `fragment_size_distribution_json`, each stamped with the process that last
     asserted the value.
   - Controls expose the same trait names but are populated with vendor-provided
     values and flagged as `confidence='expected'` (as opposed to
     `confidence='measured'`).

## Measurement Process: "Super DNA Quantifier"

1. **Process instance**
   - Create a `process_instances` row for `process_type=DNA_QUANT_MEASURE`.
   - Link the source plate (`process_io.role='instrument-input'`) and each
     well artefact (`process_io.role='material-input'`).
   - Register the instrument run artefact with
     `artefact_traits.instrument_identifier` set to the serial number.

2. **Data product**
   - When the quantifier completes, ingest the emitted CSV/JSON as a
     `data_product` artefact. Link it to the process with
     `process_io.role='primary-output'`.
   - Store a parsed representation (e.g., JSONB) inside
     `artefact_traits.parsed_payload` for downstream automation.

3. **Property updates**
   - Parse each record in the file. For well `A1`, update the corresponding well
     artefact's traits directly, e.g., set `observed_volume_uL=38.2` and
     `observed_volume_confidence='measured'` on the artefact.
   - Update the scientific/reagent artefacts with new traits:
     ```sql
     UPDATE artefact_traits SET value_json = '{"ng_per_uL": 12.4, "cv": 0.03}'
     WHERE artefact_id = :well_artefact AND trait = 'measured_concentration_ng_per_uL';
     ```
   - For fragment size distributions, store either summary stats or a histogram
     inside `fragment_size_distribution_json`. Each trait row references the
     measurement process (`provenance_process_id`) so analysts can see when each
     value was asserted.

4. **Quality control**
   - Insert QC evaluations as separate process instances
     (`process_type=DNA_QUANT_QC`). The output is a `data_product` summarising
     pass/fail calls and a `artefact_trait` such as
     `qc_status={'status': 'pass', 'process_id': ...}`. Keeping QC as a process
     records which analyst/instrument rendered the decision.

## Handling Repeat Measurements

Because a material artefact always represents the physical material *within a
specific well*, the schema no longer faces conflicts about a single sample being
in two places. A repeat measurement simply writes a new trait value onto the
same well artefact, with the `provenance_process_id` pointing to the latest
measurement process. Historical values remain available via earlier trait rows
if the lab chooses to retain them for auditing.

## Normalisation Manifest Preparation

Before the robot acts, the LIMS prepares inputs:

1. **Robot manifest data product**
   - Generate a JSON/CSV file describing desired post-normalisation targets
     (e.g., 10 ng/µL, 20 µL per well). Register it as a `data_product`
     artefact (`manifest_version=1`).
   - Associate the manifest with a planning process instance
     (`process_type=DNA_NORMALISATION_PLAN`) that consumes the measurement data
     product and emits the manifest.

2. **Resource reservation**
   - Link the buffer reagent artefact and an empty destination plate to the
     planning process with roles `buffer-input` and `destination-reservation`.
   - The destination plate is a `container` artefact with empty slots; no sample
     artefacts exist yet.

## Normalisation Execution by Liquid Handler

1. **Process instance**
   - Instantiate `process_instances` row for
     `process_type=DNA_NORMALISATION_EXECUTE`.
   - Inputs: source plate (`instrument-input`), each source well artefact
     (`material-input`), buffer reagent (`reagent-input`), destination plate
     (`destination-container`), and the manifest (`instruction-input`).
   - Outputs: robot activity report data product (`primary-output`), updated
     source well assignments (`consumed-volume`), and new destination well
     artefacts (`material-output`).

2. **Volume bookkeeping**
   - Parse the robot activity report. For each source well, decrement the
     `observed_volume_uL` trait on the well artefact by the aspirated volume.
     Record the post-run residual volume and mark the measurement confidence as
     `instrument-reported`.
   - Insert audit trail rows in `artefact_relationships` with
     `kind='consumed-in-process'` so downstream analyses know how much material
     was used.

3. **New normalised artefacts**
   - For every destination well, create a new `material` artefact derived from
     the corresponding source artefact (`kind='aliquot-normalised'`).
   - Record the destination plate relationship by setting the artefact's
     `plate_id`, `plate_slot`, and associated traits (`observed_volume_uL`,
     `measured_concentration_ng_per_uL`) sourced from the robot output or
     manifest.
   - If the negative control is simply transferred water, model it as a derived
     artefact from the original negative control reagent so provenance remains
     intact.

4. **Data product linkage**
   - Store the robot activity file as a `data_product` with raw payload and a
     parsed JSONB summary (per-well volume and concentration outcomes).
   - Attach secondary evidence such as liquid class logs or sensor alerts using
     additional `data_product` artefacts connected to the same process instance.

## Post-run QC and Reporting

1. **QC flags** – Optionally add a `process_type=DNA_NORMALISATION_QC` that
   inspects the robot output and sets `qc_status` traits on both source and
   destination artefacts (e.g., flagging wells with insufficient volume left for
   retries).
2. **Inventory reporting** – The unified schema now answers:
   - *"What volume remains in the source plate?"* → query current
     well artefacts filtered by `plate_id`.
   - *"Which destination wells passed QC?"* → filter destination artefacts on
     their `qc_status` trait.
   - *"Which process run generated this normalised aliquot?"* → traverse
     `artefact_relationships` back to the execution process and associated data
     products.

## Schema Reflection: Sample vs. Physical Artefacts

Running the end-to-end example highlighted that treating "sample" and
"container location" as separate artefacts introduced more joins than value.
By collapsing the concept so that a well artefact represents both the physical
slot and its contents we gain several benefits:

- **Authoritative measurements in one place** – volume, concentration, fragment
  distribution, and QC calls all reside on the well artefact, each annotated
  with provenance metadata. No secondary table is required to find the latest
  numbers.
- **Simpler schema** – removing `artefact_container_assignments` eliminates a
  join from nearly every operational query (inventory, QC dashboards, robot
  manifests). The foreign key from the well artefact to its plate plus the slot
  trait is sufficient.
- **Flexible data sources** – when information comes from different
  instruments, the provenance-stamped traits allow the LIMS to record repeated
  measurements side-by-side on the same well artefact. If a transfer creates a
  genuinely new physical aliquot, we can still fork artefacts using
  `artefact_relationships(kind='aliquot-split')` without reintroducing extra
  containment layers.

This simplification keeps the model faithful to physical reality while reducing
schema surface area, making it easier to evolve as additional measurement types
arrive.

## Summary Diagram (Conceptual)

```
[Sample Parent]
      │ (derived-from)
      ▼
[Source Well Artefact] --(assigned to)--> [Plate Slot A1]
      │                       │
      │         measurement updates volume/concentration traits
      ▼
[Measurement Process] --(outputs)--> [Quant Data Product]
      │
      ▼
[Normalisation Process] --(outputs)--> [Robot Report]
      │
      ├─ consumes --> [Buffer Reagent]
      ├─ produces --> [Normalised Well Artefact] --(assigned to)--> [Dest Slot A1]
      └─ updates --> [Source Well Assignment residual volume]
```

This example demonstrates how the unified artefact, process, containment, and
trait structures capture real-world lab operations while keeping measurements,
QC calls, and robot activities traceable through provenance.
