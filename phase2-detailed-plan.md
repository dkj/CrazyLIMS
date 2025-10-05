# Detailed Implementation Plan – Phase 2: Samples & Inventory Domain

## Objectives
- Model laboratory sample lineage, aliquots, and labware containers (tubes, plates, bespoke carriers) along with their environmental storage hierarchy (room → freezer → shelf → slot) to support precise chain-of-custody tracking.
- Provide inventory management primitives for reagents/consumables, including thresholds, barcode assignment, and restock alerts tied to physical locations.
- Expose read/write APIs (via PostgREST/PostGraphile) that respect existing RBAC policies, support barcode-driven workflows, and enrich audit visibility for scientific operations.
- Deliver analytics-ready views for sample status, container location, storage utilization, and inventory health.

## Domain Modeling
- **Sample Core & Lineage**
  - Expand `lims.samples` with lifecycle metadata (collection protocol, condition flags, stability windows) and support for both primary and derivative samples.
  - Introduce `lims.sample_derivations` (explicit lineage table) to represent aliquots/splits with enforced DAG constraints (parent must exist, prevent cycles) and capture derivation method (e.g., dilution, plating).
  - Maintain `lims.sample_properties` (JSONB key/value or normalized attributes) for assay-specific metadata without schema churn.
  - Document the canonical sample definition (single material identity spanning multiple labware pieces) and project-scoped visibility rules in `docs/domain-samples.md`.

- **Labware & Barcoding**
  - Create `lims.labware_types` describing container formats (tube 2 mL, 96-well plate, custom cartridge) with attributes: capacity, well layout, barcode schema requirements (1D/2D, prefix rules).
  - Define `lims.labware` table representing physical items with unique barcode (system-generated or imported), type reference, optional serial/lot, owner project, and lifecycle status (active, decontaminated, discarded).
  - Add `lims.labware_wells` (or `labware_positions`) for multi-well labware to enumerate coordinate system (row/column), tie each position to physical offsets, and allow sample occupancy mapping.
  - Capture temporary/ephemeral labware by flagging `is_disposable`, storing `expected_disposal_at`, and linking to custody events even if the labware is short-lived.

- **Storage & Environmental Hierarchy**
  - Model `lims.storage_facilities` (rooms, buildings) → `lims.storage_units` (freezers, incubators) → `lims.storage_sublocations` (shelves, racks, slots) with environmental metadata (temperature setpoint, humidity, calibration schedule).
  - Support durable vs. transient storage: allow labware to be “checked out” from storage (tracked via custody events) while retaining last known location.
  - Include optional barcode/QR IDs for each storage node to support scanning.

- **Sample Placement & Custody**
  - Create `lims.sample_labware_assignments` linking sample IDs (or aliquot IDs) to labware wells/slots with effective dates, volume/amount metadata, and occupancy constraints.
  - Implement `lims.custody_events` capturing actor, action (transfer, thaw, discard), source/destination labware or storage location, environmental notes, and instrument references. Guarantee chronological order and require reason codes for exceptional actions (e.g., deviating from SOP).
  - Provide `lims.labware_location_history` to track labware movement between storage sublocations, retaining path (room → freezer → shelf → slot) and environmental conditions at the time.

- **Inventory Management**
  - Create `lims.inventory_items` (or `reagents`) for consumables with catalog reference, barcode (if affixed), quantity units, min/max thresholds, supplier, cost center, and storage requirements.
  - Track `lims.inventory_transactions` for usage, replenishment, QC failures. Support conversions (e.g., cases to individual units) and enforce non-negative inventory balances.
  - Link inventory items to labware when stored together (e.g., reagent racks) by referencing `labware` and storage nodes.

- **Lookup & Reference Data**
  - Maintain controlled vocabularies for sample types, custody event types, labware types, storage condition codes, and transaction reasons with admin-editable enumerations.
  - Document barcode formats and allocation rules (prefix ranges, check digits) to ensure uniqueness across labware/inventory.

## Security & RLS
- Extend RLS policies to all new tables:
  - `app_admin` retains full control.
  - `app_operator` can create/modify labware, custody events, storage assignments, and inventory transactions.
  - `app_researcher` receives scoped read access (own project samples, labware they have custodial rights to, inventory statuses read-only).
  - `app_automation` allowed to append custody events, update labware locations, and register new samples under guarded functions.
- Introduce helper functions (if not already present) for project scoping (`lims.current_project_ids()`) and labware access checks (validate user is assigned custodian or has parent sample rights).
- All new tables receive audit triggers (reuse `lims.fn_audit`) and targeted reporting views summarizing custody changes and inventory adjustments; highlight overdue labware returns or storage deviations.
- Evaluate whether labware/inventory tables require row-level denies for external collaborators (`app_external`) and document rationale.

## APIs & Business Rules
- Define PostgREST views/functions supporting barcode workflows:
  - `v_sample_overview` with current labware barcode, storage path, custody status, and derivative counts.
  - `v_labware_contents` listing samples per labware with occupancy metadata (volumes, well positions).
  - `v_storage_dashboard` summarizing storage unit utilization and environmental alerts.
  - `v_inventory_status` showing stock levels, thresholds, upcoming expirations, and reorder suggestions.
- Provide RPC/GraphQL mutations for key workflows:
  - `create_aliquot(parent_sample_id, labware_id, …)` ensuring lineage and labware capacity rules.
  - `transfer_labware(labware_id, destination_storage_id, reason)` with custody logging.
  - `record_inventory_transaction(item_id, delta, reason)` enforcing non-negative balance and capturing metadata.
- Support barcode scanning endpoints (e.g., look up labware by barcode, check sample history) optimized for mobile/LIMS UI integrations.
- Update API contracts to expose filtering on labware barcode, storage path, inventory status, and allow optimistic concurrency via timestamp columns.

## Testing Strategy
- Expand SQL regression suite:
  - Validate labware capacity constraints, unique barcode generation, and lineage DAG integrity.
  - Ensure custody events enforce chronological order and require valid predecessors (no backdated overlaps).
  - Test storage assignment invariants (only one active assignment per sample, capacity of wells/slots not exceeded).
  - Confirm inventory transactions maintain non-negative balances and respect unit conversions.
- Extend RBAC smoke tests:
  - Operators can move labware and adjust inventory; researchers cannot mutate inventory transactions or custody events outside their samples.
  - Automation role permitted to register custody events via API, but blocked from manual labware creation.
- Consider pgTAP or additional SQL scripts to simulate barcode scanning flows (lookup by barcode, verifying permissions) and multi-step operations (bulk transfer across labware).
- Evaluate test fixtures (mock labware, storage tree) to support deterministic tests; seed via migrations or test harness.

## Data Quality & Analytics
- Implement materialized views or event-driven snapshots for:
  - Sample integrity (time since thaw, time above temperature limits) using custody events + environmental metadata.
  - Storage utilization (occupied vs. capacity by facility/unit/well) and flagging over-capacity scenarios.
  - Inventory restock alerts, expired reagents, and unused labware (no activity for configurable period).
- Add monitor tables capturing freezer temperature deviations, door-open events, and tie to custody events for audit correlation.
- Define indexes/partitioning strategies for high-volume tables (`custody_events`, `labware_location_history`, `inventory_transactions`). Consider time-based partitioning if data volumes warrant.
- Ensure barcode uniqueness via btree indexes and, if needed, sequences/prefix allocation per labware type.

## Documentation & Operations
- Update `docs/security-model.md` to include labware, custody, and inventory tables plus RBAC implications.
- Produce domain docs (`docs/domain-samples.md`, `docs/domain-inventory.md`) covering labware types, barcode rules, custody workflows, and API examples for field/lab staff.
- Document SOP-aligned runbooks: registering new labware batches, labeling/barcoding procedures, assigning storage units, handling exceptions (lost labware, freezer outage).
- Coordinate with operations teams to align barcode formats with physical printing hardware; capture mapping of prefix → labware type.
- Publish change logs alongside contract exports to notify downstream systems about new endpoints/fields.
- Plan training/demo sessions with lab teams once APIs and storage dashboards are available.

## Milestones & Exit Criteria
1. **Schema Delivery**: migrations covering sample lineage, storage, inventory tables with RLS and audit triggers; migrations apply cleanly over Phase 1 baseline.
2. **API Exposure**: PostgREST/PostGraphile reflect new resources; contract exports updated with sample/inventory endpoints.
3. **Testing**: `make db/test` extended to new domain rules, `make test/security` updated with additional sample/inventory scenarios; both pass reliably.
4. **Documentation**: README/security/domain docs updated; developer onboarding describes new workflows.
5. **Stakeholder Review**: domain experts sign off on sample lifecycle, custody rules, and inventory reporting requirements.

Meeting these criteria will complete Phase 2 and provide a robust foundation for ELN integration in subsequent phases.
