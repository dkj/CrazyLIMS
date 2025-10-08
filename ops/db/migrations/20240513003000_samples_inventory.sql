-- migrate:up

-------------------------------------------------------------------------------
-- Lookup tables
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lims.sample_statuses (
  status_code text PRIMARY KEY,
  description text NOT NULL,
  is_terminal boolean NOT NULL DEFAULT false
);

INSERT INTO lims.sample_statuses(status_code, description, is_terminal)
VALUES
  ('available', 'Available for use', false),
  ('consumed', 'Consumed during processing', true),
  ('discarded', 'Discarded / destroyed', true),
  ('quarantined', 'Quarantined pending investigation', false)
ON CONFLICT (status_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS lims.sample_types_lookup (
  sample_type_code text PRIMARY KEY,
  description text NOT NULL,
  is_active boolean NOT NULL DEFAULT true
);

INSERT INTO lims.sample_types_lookup(sample_type_code, description)
VALUES
  ('cell', 'Cellular sample'),
  ('fluid', 'Fluid sample'),
  ('dna', 'DNA sample'),
  ('rna', 'RNA sample'),
  ('library', 'Sequencing library'),
  ('pooled_library', 'Pooled sequencing library')
ON CONFLICT (sample_type_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS lims.custody_event_types (
  event_type text PRIMARY KEY,
  description text NOT NULL,
  requires_destination boolean NOT NULL DEFAULT false
);

INSERT INTO lims.custody_event_types(event_type, description, requires_destination)
VALUES
  ('transfer', 'Transfer between storage or labware', true),
  ('checkout', 'Removed from storage for processing', false),
  ('return', 'Returned to storage', true),
  ('discard', 'Sample discarded', false)
ON CONFLICT (event_type) DO NOTHING;

CREATE TABLE IF NOT EXISTS lims.labware_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  capacity integer,
  layout jsonb NOT NULL DEFAULT '{}'::jsonb,
  barcode_format text,
  is_disposable boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS lims.inventory_transaction_types (
  transaction_type text PRIMARY KEY,
  description text NOT NULL,
  direction text CHECK (direction IN ('increase','decrease','neutral')) NOT NULL
);

INSERT INTO lims.inventory_transaction_types(transaction_type, description, direction)
VALUES
  ('receipt', 'Stock received', 'increase'),
  ('usage', 'Stock consumed', 'decrease'),
  ('adjustment', 'Manual adjustment', 'neutral')
ON CONFLICT (transaction_type) DO NOTHING;

-------------------------------------------------------------------------------
-- Storage hierarchy
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lims.storage_facilities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  location text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS lims.storage_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id uuid REFERENCES lims.storage_facilities(id) ON DELETE CASCADE,
  name text NOT NULL,
  storage_type text NOT NULL,
  temperature_setpoint numeric,
  humidity_setpoint numeric,
  barcode text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (facility_id, name)
);

CREATE TABLE IF NOT EXISTS lims.storage_sublocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id uuid REFERENCES lims.storage_units(id) ON DELETE CASCADE,
  parent_sublocation_id uuid REFERENCES lims.storage_sublocations(id) ON DELETE CASCADE,
  name text NOT NULL,
  barcode text,
  capacity integer,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (unit_id, name)
);

-------------------------------------------------------------------------------
-- Labware and positions
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lims.labware (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  labware_type_id uuid REFERENCES lims.labware_types(id) ON DELETE RESTRICT,
  barcode text UNIQUE,
  display_name text,
  status text NOT NULL DEFAULT 'in_use',
  is_disposable boolean NOT NULL DEFAULT false,
  expected_disposal_at timestamptz,
  current_storage_sublocation_id uuid REFERENCES lims.storage_sublocations(id),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES lims.users(id),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lims.labware_positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  labware_id uuid NOT NULL REFERENCES lims.labware(id) ON DELETE CASCADE,
  position_label text NOT NULL,
  row_index integer,
  column_index integer,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (labware_id, position_label)
);

CREATE TRIGGER trg_touch_labware
BEFORE UPDATE ON lims.labware
FOR EACH ROW
EXECUTE FUNCTION lims.fn_touch_updated_at();

-------------------------------------------------------------------------------
-- Samples enhancements
-------------------------------------------------------------------------------

ALTER TABLE lims.samples
  ADD COLUMN sample_status text REFERENCES lims.sample_statuses(status_code) DEFAULT 'available',
  ADD COLUMN sample_type_code text REFERENCES lims.sample_types_lookup(sample_type_code),
  ADD COLUMN collected_at timestamptz,
  ADD COLUMN collected_by uuid REFERENCES lims.users(id),
  ADD COLUMN condition_notes text,
  ADD COLUMN metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN current_labware_id uuid REFERENCES lims.labware(id);

UPDATE lims.samples SET sample_type_code = sample_type
WHERE sample_type IS NOT NULL;

CREATE TRIGGER trg_touch_samples
BEFORE UPDATE ON lims.samples
FOR EACH ROW
EXECUTE FUNCTION lims.fn_touch_updated_at();

CREATE TABLE IF NOT EXISTS lims.sample_derivations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_sample_id uuid NOT NULL REFERENCES lims.samples(id) ON DELETE CASCADE,
  child_sample_id uuid NOT NULL REFERENCES lims.samples(id) ON DELETE CASCADE,
  method text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES lims.users(id),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (parent_sample_id, child_sample_id)
);

CREATE TABLE IF NOT EXISTS lims.custody_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sample_id uuid NOT NULL REFERENCES lims.samples(id) ON DELETE CASCADE,
  labware_id uuid REFERENCES lims.labware(id) ON DELETE SET NULL,
  from_sublocation_id uuid REFERENCES lims.storage_sublocations(id) ON DELETE SET NULL,
  to_sublocation_id uuid REFERENCES lims.storage_sublocations(id) ON DELETE SET NULL,
  event_type text NOT NULL REFERENCES lims.custody_event_types(event_type),
  performed_by uuid REFERENCES lims.users(id),
  performed_at timestamptz NOT NULL DEFAULT now(),
  event_notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS lims.sample_labware_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sample_id uuid NOT NULL REFERENCES lims.samples(id) ON DELETE CASCADE,
  labware_id uuid NOT NULL REFERENCES lims.labware(id) ON DELETE CASCADE,
  labware_position_id uuid REFERENCES lims.labware_positions(id) ON DELETE SET NULL,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  assigned_by uuid REFERENCES lims.users(id),
  volume numeric,
  volume_unit text,
  released_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (sample_id, labware_id, labware_position_id)
);

CREATE TABLE IF NOT EXISTS lims.labware_location_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  labware_id uuid NOT NULL REFERENCES lims.labware(id) ON DELETE CASCADE,
  storage_sublocation_id uuid REFERENCES lims.storage_sublocations(id) ON DELETE SET NULL,
  moved_at timestamptz NOT NULL DEFAULT now(),
  moved_by uuid REFERENCES lims.users(id),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-------------------------------------------------------------------------------
-- Inventory domain
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lims.inventory_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  barcode text UNIQUE,
  name text NOT NULL,
  description text,
  catalogue_number text,
  lot_number text,
  quantity numeric NOT NULL DEFAULT 0,
  unit text NOT NULL DEFAULT 'unit',
  minimum_quantity numeric,
  storage_requirements text,
  expires_at timestamptz,
  storage_sublocation_id uuid REFERENCES lims.storage_sublocations(id),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES lims.users(id),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_touch_inventory_items
BEFORE UPDATE ON lims.inventory_items
FOR EACH ROW
EXECUTE FUNCTION lims.fn_touch_updated_at();

CREATE TABLE IF NOT EXISTS lims.inventory_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_item_id uuid NOT NULL REFERENCES lims.inventory_items(id) ON DELETE CASCADE,
  transaction_type text NOT NULL REFERENCES lims.inventory_transaction_types(transaction_type),
  quantity_delta numeric NOT NULL,
  unit text,
  reason text,
  performed_at timestamptz NOT NULL DEFAULT now(),
  performed_by uuid REFERENCES lims.users(id),
  resulting_quantity numeric,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-------------------------------------------------------------------------------
-- Views
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW lims.v_sample_overview
WITH (security_invoker = true)
AS
SELECT
  s.id,
  s.name,
  s.sample_type_code,
  s.sample_status,
  s.collected_at,
  s.project_code,
  lab.barcode AS current_labware_barcode,
  loc_path.path_text AS storage_path,
  (
    SELECT jsonb_agg(jsonb_build_object('child_sample_id', sd.child_sample_id, 'method', sd.method))
    FROM lims.sample_derivations sd
    WHERE sd.parent_sample_id = s.id
  ) AS derivatives
FROM lims.samples s
LEFT JOIN lims.labware lab ON lab.id = s.current_labware_id
LEFT JOIN LATERAL (
  SELECT string_agg(
           format('%s/%s/%s', COALESCE(sf.name, ''), COALESCE(su.name, ''), COALESCE(ss.name, '')),
           ' → '
         ) AS path_text
  FROM lims.storage_sublocations ss
  LEFT JOIN lims.storage_units su ON su.id = ss.unit_id
  LEFT JOIN lims.storage_facilities sf ON sf.id = su.facility_id
  WHERE ss.id = lab.current_storage_sublocation_id
) loc_path ON true;

CREATE OR REPLACE VIEW lims.v_labware_contents
WITH (security_invoker = true)
AS
SELECT
  lw.id AS labware_id,
  lw.barcode,
  lw.display_name,
  lw.status,
  pos.position_label,
  sla.sample_id,
  s.name AS sample_name,
  sla.volume,
  sla.volume_unit,
  lw.current_storage_sublocation_id
FROM lims.labware lw
LEFT JOIN lims.labware_positions pos ON pos.labware_id = lw.id
LEFT JOIN lims.sample_labware_assignments sla ON sla.labware_id = lw.id AND (sla.labware_position_id = pos.id OR sla.labware_position_id IS NULL)
LEFT JOIN lims.samples s ON s.id = sla.sample_id;

CREATE OR REPLACE VIEW lims.v_storage_dashboard
WITH (security_invoker = true)
AS
SELECT
  sf.name AS facility,
  su.name AS unit,
  su.storage_type,
  ss.name AS sublocation,
  COUNT(DISTINCT lw.id) AS labware_count,
  COUNT(DISTINCT sla.sample_id) AS sample_count
FROM lims.storage_sublocations ss
LEFT JOIN lims.storage_units su ON su.id = ss.unit_id
LEFT JOIN lims.storage_facilities sf ON sf.id = su.facility_id
LEFT JOIN lims.labware lw ON lw.current_storage_sublocation_id = ss.id
LEFT JOIN lims.sample_labware_assignments sla ON sla.labware_id = lw.id AND sla.released_at IS NULL
GROUP BY sf.name, su.name, su.storage_type, ss.name;

CREATE OR REPLACE VIEW lims.v_inventory_status
WITH (security_invoker = true)
AS
SELECT
  ii.id,
  ii.name,
  ii.barcode,
  ii.quantity,
  ii.unit,
  ii.minimum_quantity,
  (ii.quantity <= COALESCE(ii.minimum_quantity, -1)) AS below_threshold,
  ii.expires_at,
  ii.storage_sublocation_id
FROM lims.inventory_items ii;

-------------------------------------------------------------------------------
-- Row Level Security
-------------------------------------------------------------------------------

ALTER TABLE lims.labware ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.labware FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.labware_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.labware_positions FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.sample_derivations ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.sample_derivations FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.custody_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.custody_events FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.sample_labware_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.sample_labware_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.labware_location_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.labware_location_history FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.inventory_items FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.inventory_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.inventory_transactions FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.storage_facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.storage_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.storage_sublocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.storage_facilities FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.storage_units FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.storage_sublocations FORCE ROW LEVEL SECURITY;

CREATE POLICY p_labware_admin_all ON lims.labware FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_labware_operator_all ON lims.labware FOR ALL TO app_operator USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_labware_select_researcher ON lims.labware FOR SELECT TO app_auth USING (TRUE);

CREATE POLICY p_labware_positions_admin_all ON lims.labware_positions FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_labware_positions_operator_all ON lims.labware_positions FOR ALL TO app_operator USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_labware_positions_select_researcher ON lims.labware_positions FOR SELECT TO app_auth USING (TRUE);

CREATE POLICY p_sample_derivations_admin_all ON lims.sample_derivations FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_sample_derivations_operator_all ON lims.sample_derivations FOR ALL TO app_operator USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_sample_derivations_select_researcher ON lims.sample_derivations FOR SELECT TO app_auth USING (TRUE);

CREATE POLICY p_custody_events_admin_all ON lims.custody_events FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_custody_events_operator_all ON lims.custody_events FOR ALL TO app_operator USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_custody_events_select_researcher ON lims.custody_events FOR SELECT TO app_auth USING (TRUE);

CREATE POLICY p_sample_labware_assign_admin_all ON lims.sample_labware_assignments FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_sample_labware_assign_operator_all ON lims.sample_labware_assignments FOR ALL TO app_operator USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_sample_labware_assign_select_researcher ON lims.sample_labware_assignments FOR SELECT TO app_auth USING (TRUE);

CREATE POLICY p_labware_location_history_admin_all ON lims.labware_location_history FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_labware_location_history_operator_all ON lims.labware_location_history FOR ALL TO app_operator USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_labware_location_history_select_researcher ON lims.labware_location_history FOR SELECT TO app_auth USING (TRUE);

CREATE POLICY p_inventory_items_admin_all ON lims.inventory_items FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_inventory_items_operator_all ON lims.inventory_items FOR ALL TO app_operator USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_inventory_items_select_researcher ON lims.inventory_items FOR SELECT TO app_auth USING (TRUE);

CREATE POLICY p_inventory_transactions_admin_all ON lims.inventory_transactions FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_inventory_transactions_operator_all ON lims.inventory_transactions FOR ALL TO app_operator USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_inventory_transactions_select_researcher ON lims.inventory_transactions FOR SELECT TO app_auth USING (TRUE);

CREATE POLICY p_storage_facilities_admin_all ON lims.storage_facilities FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_storage_units_admin_all ON lims.storage_units FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_storage_sublocations_admin_all ON lims.storage_sublocations FOR ALL TO app_admin USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY p_storage_facilities_select_auth ON lims.storage_facilities FOR SELECT TO app_auth USING (TRUE);
CREATE POLICY p_storage_units_select_auth ON lims.storage_units FOR SELECT TO app_auth USING (TRUE);
CREATE POLICY p_storage_sublocations_select_auth ON lims.storage_sublocations FOR SELECT TO app_auth USING (TRUE);

-------------------------------------------------------------------------------
-- Grants
-------------------------------------------------------------------------------

GRANT SELECT ON lims.sample_statuses, lims.sample_types_lookup, lims.custody_event_types, lims.inventory_transaction_types TO app_auth;
GRANT SELECT ON lims.labware_types TO app_auth;
GRANT SELECT ON lims.v_sample_overview, lims.v_labware_contents, lims.v_storage_dashboard, lims.v_inventory_status TO app_auth;

GRANT SELECT, INSERT, UPDATE, DELETE ON lims.storage_facilities, lims.storage_units, lims.storage_sublocations TO app_admin;
GRANT SELECT ON lims.storage_facilities, lims.storage_units, lims.storage_sublocations TO app_auth;

GRANT SELECT, INSERT, UPDATE, DELETE ON lims.inventory_items, lims.inventory_transactions TO app_admin;
GRANT SELECT, INSERT, UPDATE ON lims.inventory_items, lims.inventory_transactions TO app_operator;

GRANT SELECT ON lims.labware, lims.labware_positions, lims.sample_derivations, lims.sample_labware_assignments, lims.custody_events, lims.labware_location_history TO app_auth;
GRANT INSERT, UPDATE, DELETE ON lims.labware, lims.labware_positions, lims.sample_derivations, lims.sample_labware_assignments, lims.custody_events, lims.labware_location_history TO app_admin;
GRANT INSERT, UPDATE, DELETE ON lims.labware, lims.sample_labware_assignments, lims.custody_events, lims.labware_location_history TO app_operator;

-------------------------------------------------------------------------------
-- Seed data
-------------------------------------------------------------------------------

INSERT INTO lims.labware_types(name, description, capacity, layout, barcode_format, is_disposable)
VALUES
  ('2mL Tube', 'Standard 2mL cryovial', 1, '{}'::jsonb, '1D', true),
  ('96-Well Plate', 'Standard 8x12 well plate', 96, jsonb_build_object('rows', 8, 'columns', 12), '2D', false)
ON CONFLICT (name) DO NOTHING;

-- Default storage structure for development/demo
INSERT INTO lims.storage_facilities(name, description, location)
VALUES ('Main Lab', 'Primary laboratory storage', 'Building A - Level 2')
ON CONFLICT (name) DO NOTHING;

INSERT INTO lims.storage_units(facility_id, name, storage_type, temperature_setpoint)
SELECT id, 'Freezer 1', 'freezer', -40 FROM lims.storage_facilities WHERE name = 'Main Lab'
ON CONFLICT (facility_id, name) DO NOTHING;

INSERT INTO lims.storage_sublocations(unit_id, name, capacity)
SELECT su.id, 'Shelf 1', 50
FROM lims.storage_units su
JOIN lims.storage_facilities sf ON sf.id = su.facility_id AND sf.name = 'Main Lab'
WHERE su.name = 'Freezer 1'
ON CONFLICT (unit_id, name) DO NOTHING;

DO $$
DECLARE
  admin_id uuid := (SELECT id FROM lims.users WHERE email = 'admin@example.org');
  alice_id uuid := (SELECT id FROM lims.users WHERE email = 'alice@example.org');
  bob_id uuid := (SELECT id FROM lims.users WHERE email = 'bob@example.org');
  shelf_id uuid := (
    SELECT ss.id
    FROM lims.storage_sublocations ss
    JOIN lims.storage_units su ON su.id = ss.unit_id
    JOIN lims.storage_facilities sf ON sf.id = su.facility_id
    WHERE sf.name = 'Main Lab' AND su.name = 'Freezer 1' AND ss.name = 'Shelf 1'
    LIMIT 1
  );
  sample_pbmc_aliquot uuid;
  sample_serum_control uuid;
  sample_neutralizing uuid;
  sample_blood_draw uuid;
  sample_pbmc_batch uuid;
  sample_dna_batch1_101 uuid;
  sample_dna_batch1_102 uuid;
  sample_dna_batch1_103 uuid;
  sample_dna_batch2_201 uuid;
  sample_dna_batch2_202 uuid;
  sample_dna_batch2_203 uuid;
  sample_library_batch1_101 uuid;
  sample_library_batch1_102 uuid;
  sample_library_batch1_103 uuid;
  sample_library_batch2_201 uuid;
  sample_library_batch2_202 uuid;
  sample_library_batch2_203 uuid;
  sample_sequencing_pool uuid;
  labware_tube_one uuid;
  labware_tube_two uuid;
  labware_plate uuid;
  labware_dna_plate_one uuid;
  labware_dna_plate_two uuid;
  labware_library_plate uuid;
  labware_pool_vessel uuid;
  pos_a1 uuid;
  pos_a2 uuid;
  dna_plate_one_a1 uuid;
  dna_plate_one_a2 uuid;
  dna_plate_one_a3 uuid;
  dna_plate_two_a1 uuid;
  dna_plate_two_a2 uuid;
  dna_plate_two_a3 uuid;
  library_plate_a1 uuid;
  library_plate_a2 uuid;
  library_plate_a3 uuid;
  library_plate_b1 uuid;
  library_plate_b2 uuid;
  library_plate_b3 uuid;
BEGIN
  IF admin_id IS NULL THEN
    RAISE NOTICE 'Skipping seed data: admin user missing.';
    RETURN;
  END IF;

  IF alice_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'PBMC Aliquot A') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by)
      VALUES ('PBMC Aliquot A', 'cell', 'PRJ-001', 'available', 'cell', now() - interval '3 days', alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'Serum QC Control Sample') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by)
      VALUES ('Serum QC Control Sample', 'fluid', 'PRJ-002', 'available', 'fluid', now() - interval '1 day', alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'DNA Intake Batch 001 - Donor 101') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('DNA Intake Batch 001 - Donor 101', 'dna', 'PRJ-002', 'available', 'dna', now() - interval '20 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'DNA Intake Batch 001 - Donor 102') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('DNA Intake Batch 001 - Donor 102', 'dna', 'PRJ-002', 'available', 'dna', now() - interval '19 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'DNA Intake Batch 001 - Donor 103') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('DNA Intake Batch 001 - Donor 103', 'dna', 'PRJ-002', 'available', 'dna', now() - interval '19 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'DNA Intake Batch 002 - Donor 201') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('DNA Intake Batch 002 - Donor 201', 'dna', 'PRJ-002', 'available', 'dna', now() - interval '18 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'DNA Intake Batch 002 - Donor 202') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('DNA Intake Batch 002 - Donor 202', 'dna', 'PRJ-002', 'available', 'dna', now() - interval '18 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'DNA Intake Batch 002 - Donor 203') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('DNA Intake Batch 002 - Donor 203', 'dna', 'PRJ-002', 'available', 'dna', now() - interval '17 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'Indexed Library Batch 001 - Donor 101') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('Indexed Library Batch 001 - Donor 101', 'library', 'PRJ-002', 'available', 'library', now() - interval '8 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'Indexed Library Batch 001 - Donor 102') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('Indexed Library Batch 001 - Donor 102', 'library', 'PRJ-002', 'available', 'library', now() - interval '7 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'Indexed Library Batch 001 - Donor 103') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('Indexed Library Batch 001 - Donor 103', 'library', 'PRJ-002', 'available', 'library', now() - interval '7 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'Indexed Library Batch 002 - Donor 201') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('Indexed Library Batch 002 - Donor 201', 'library', 'PRJ-002', 'available', 'library', now() - interval '6 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'Indexed Library Batch 002 - Donor 202') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('Indexed Library Batch 002 - Donor 202', 'library', 'PRJ-002', 'available', 'library', now() - interval '6 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'Indexed Library Batch 002 - Donor 203') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('Indexed Library Batch 002 - Donor 203', 'library', 'PRJ-002', 'available', 'library', now() - interval '5 hours', alice_id, alice_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'Sequencing Pool Run 001') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by, collected_by)
      VALUES ('Sequencing Pool Run 001', 'pooled_library', 'PRJ-002', 'available', 'pooled_library', now() - interval '2 hours', alice_id, alice_id);
    END IF;
  END IF;

  IF bob_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM lims.samples WHERE name = 'Neutralizing Panel B') THEN
      INSERT INTO lims.samples(name, sample_type, project_code, sample_status, sample_type_code, collected_at, created_by)
      VALUES ('Neutralizing Panel B', 'cell', 'PRJ-003', 'available', 'cell', now() - interval '5 days', bob_id);
    END IF;
  END IF;

  SELECT id INTO sample_pbmc_aliquot FROM lims.samples WHERE name = 'PBMC Aliquot A';
  SELECT id INTO sample_serum_control FROM lims.samples WHERE name = 'Serum QC Control Sample';
  SELECT id INTO sample_neutralizing FROM lims.samples WHERE name = 'Neutralizing Panel B';
  SELECT id INTO sample_blood_draw FROM lims.samples WHERE name = 'Participant 001 Blood Draw';
  SELECT id INTO sample_pbmc_batch FROM lims.samples WHERE name = 'PBMC Batch 001';
  SELECT id INTO sample_dna_batch1_101 FROM lims.samples WHERE name = 'DNA Intake Batch 001 - Donor 101';
  SELECT id INTO sample_dna_batch1_102 FROM lims.samples WHERE name = 'DNA Intake Batch 001 - Donor 102';
  SELECT id INTO sample_dna_batch1_103 FROM lims.samples WHERE name = 'DNA Intake Batch 001 - Donor 103';
  SELECT id INTO sample_dna_batch2_201 FROM lims.samples WHERE name = 'DNA Intake Batch 002 - Donor 201';
  SELECT id INTO sample_dna_batch2_202 FROM lims.samples WHERE name = 'DNA Intake Batch 002 - Donor 202';
  SELECT id INTO sample_dna_batch2_203 FROM lims.samples WHERE name = 'DNA Intake Batch 002 - Donor 203';
  SELECT id INTO sample_library_batch1_101 FROM lims.samples WHERE name = 'Indexed Library Batch 001 - Donor 101';
  SELECT id INTO sample_library_batch1_102 FROM lims.samples WHERE name = 'Indexed Library Batch 001 - Donor 102';
  SELECT id INTO sample_library_batch1_103 FROM lims.samples WHERE name = 'Indexed Library Batch 001 - Donor 103';
  SELECT id INTO sample_library_batch2_201 FROM lims.samples WHERE name = 'Indexed Library Batch 002 - Donor 201';
  SELECT id INTO sample_library_batch2_202 FROM lims.samples WHERE name = 'Indexed Library Batch 002 - Donor 202';
  SELECT id INTO sample_library_batch2_203 FROM lims.samples WHERE name = 'Indexed Library Batch 002 - Donor 203';
  SELECT id INTO sample_sequencing_pool FROM lims.samples WHERE name = 'Sequencing Pool Run 001';

  IF shelf_id IS NULL THEN
    RAISE NOTICE 'Skipping labware/inventory seeds: storage shelf missing.';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lims.labware WHERE barcode = 'TUBE-0001') THEN
    INSERT INTO lims.labware(labware_type_id, barcode, display_name, status, is_disposable, expected_disposal_at, current_storage_sublocation_id, metadata, created_by)
    SELECT id, 'TUBE-0001', 'PBMC Aliquot Tube', 'in_use', true, now() + interval '7 days', shelf_id, jsonb_build_object('contents', 'PBMC aliquot'), admin_id
    FROM lims.labware_types
    WHERE name = '2mL Tube'
    LIMIT 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lims.labware WHERE barcode = 'PLATE-0001') THEN
    INSERT INTO lims.labware(labware_type_id, barcode, display_name, status, is_disposable, current_storage_sublocation_id, metadata, created_by)
    SELECT id, 'PLATE-0001', 'Serum Control Plate', 'in_use', false, shelf_id, jsonb_build_object('assay', 'ELISA'), admin_id
    FROM lims.labware_types
    WHERE name = '96-Well Plate'
    LIMIT 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lims.labware WHERE barcode = 'TUBE-0002') THEN
    INSERT INTO lims.labware(labware_type_id, barcode, display_name, status, is_disposable, expected_disposal_at, current_storage_sublocation_id, metadata, created_by)
    SELECT id, 'TUBE-0002', 'Neutralizing Panel Tube', 'in_use', true, now() + interval '5 days', shelf_id, jsonb_build_object('contents', 'Neutralizing panel replicate'), admin_id
    FROM lims.labware_types
    WHERE name = '2mL Tube'
    LIMIT 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lims.labware WHERE barcode = 'PLATE-DNA-0001') THEN
    INSERT INTO lims.labware(labware_type_id, barcode, display_name, status, is_disposable, current_storage_sublocation_id, metadata, created_by)
    SELECT id, 'PLATE-DNA-0001', 'DNA Intake Batch 001', 'in_use', false, shelf_id, jsonb_build_object('batch', '001'), admin_id
    FROM lims.labware_types
    WHERE name = '96-Well Plate'
    LIMIT 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lims.labware WHERE barcode = 'PLATE-DNA-0002') THEN
    INSERT INTO lims.labware(labware_type_id, barcode, display_name, status, is_disposable, current_storage_sublocation_id, metadata, created_by)
    SELECT id, 'PLATE-DNA-0002', 'DNA Intake Batch 002', 'in_use', false, shelf_id, jsonb_build_object('batch', '002'), admin_id
    FROM lims.labware_types
    WHERE name = '96-Well Plate'
    LIMIT 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lims.labware WHERE barcode = 'PLATE-LIB-0001') THEN
    INSERT INTO lims.labware(labware_type_id, barcode, display_name, status, is_disposable, current_storage_sublocation_id, metadata, created_by)
    SELECT id, 'PLATE-LIB-0001', 'Indexed Library Batch 001/002', 'in_use', false, shelf_id, jsonb_build_object('workflow_stage', 'indexed_library'), admin_id
    FROM lims.labware_types
    WHERE name = '96-Well Plate'
    LIMIT 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lims.labware WHERE barcode = 'POOL-SEQ-0001') THEN
    INSERT INTO lims.labware(labware_type_id, barcode, display_name, status, is_disposable, expected_disposal_at, current_storage_sublocation_id, metadata, created_by)
    SELECT id, 'POOL-SEQ-0001', 'Sequencing Pool Run 001 Vessel', 'in_use', true, now() + interval '2 days', shelf_id, jsonb_build_object('workflow_stage', 'pooled_library'), admin_id
    FROM lims.labware_types
    WHERE name = '2mL Tube'
    LIMIT 1;
  END IF;

  SELECT id INTO labware_tube_one FROM lims.labware WHERE barcode = 'TUBE-0001';
  SELECT id INTO labware_plate FROM lims.labware WHERE barcode = 'PLATE-0001';
  SELECT id INTO labware_tube_two FROM lims.labware WHERE barcode = 'TUBE-0002';
  SELECT id INTO labware_dna_plate_one FROM lims.labware WHERE barcode = 'PLATE-DNA-0001';
  SELECT id INTO labware_dna_plate_two FROM lims.labware WHERE barcode = 'PLATE-DNA-0002';
  SELECT id INTO labware_library_plate FROM lims.labware WHERE barcode = 'PLATE-LIB-0001';
  SELECT id INTO labware_pool_vessel FROM lims.labware WHERE barcode = 'POOL-SEQ-0001';

  IF labware_plate IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_plate AND position_label = 'A1') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_plate, 'A1', 1, 1);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_plate AND position_label = 'A2') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_plate, 'A2', 1, 2);
    END IF;
  END IF;

  SELECT id INTO pos_a1 FROM lims.labware_positions WHERE labware_id = labware_plate AND position_label = 'A1';
  SELECT id INTO pos_a2 FROM lims.labware_positions WHERE labware_id = labware_plate AND position_label = 'A2';

  IF labware_dna_plate_one IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_one AND position_label = 'A1') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_dna_plate_one, 'A1', 1, 1);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_one AND position_label = 'A2') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_dna_plate_one, 'A2', 1, 2);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_one AND position_label = 'A3') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_dna_plate_one, 'A3', 1, 3);
    END IF;
  END IF;

  IF labware_dna_plate_two IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_two AND position_label = 'A1') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_dna_plate_two, 'A1', 1, 1);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_two AND position_label = 'A2') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_dna_plate_two, 'A2', 1, 2);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_two AND position_label = 'A3') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_dna_plate_two, 'A3', 1, 3);
    END IF;
  END IF;

  IF labware_library_plate IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'A1') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_library_plate, 'A1', 1, 1);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'A2') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_library_plate, 'A2', 1, 2);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'A3') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_library_plate, 'A3', 1, 3);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'B1') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_library_plate, 'B1', 2, 1);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'B2') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_library_plate, 'B2', 2, 2);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'B3') THEN
      INSERT INTO lims.labware_positions(labware_id, position_label, row_index, column_index)
      VALUES (labware_library_plate, 'B3', 2, 3);
    END IF;
  END IF;

  SELECT id INTO dna_plate_one_a1 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_one AND position_label = 'A1';
  SELECT id INTO dna_plate_one_a2 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_one AND position_label = 'A2';
  SELECT id INTO dna_plate_one_a3 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_one AND position_label = 'A3';
  SELECT id INTO dna_plate_two_a1 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_two AND position_label = 'A1';
  SELECT id INTO dna_plate_two_a2 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_two AND position_label = 'A2';
  SELECT id INTO dna_plate_two_a3 FROM lims.labware_positions WHERE labware_id = labware_dna_plate_two AND position_label = 'A3';
  SELECT id INTO library_plate_a1 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'A1';
  SELECT id INTO library_plate_a2 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'A2';
  SELECT id INTO library_plate_a3 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'A3';
  SELECT id INTO library_plate_b1 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'B1';
  SELECT id INTO library_plate_b2 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'B2';
  SELECT id INTO library_plate_b3 FROM lims.labware_positions WHERE labware_id = labware_library_plate AND position_label = 'B3';

  IF labware_tube_one IS NOT NULL AND sample_pbmc_aliquot IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM lims.sample_labware_assignments
      WHERE sample_id = sample_pbmc_aliquot AND labware_id = labware_tube_one AND labware_position_id IS NULL
    ) THEN
      INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
      VALUES (sample_pbmc_aliquot, labware_tube_one, NULL, now() - interval '2 days', admin_id, 1.5, 'mL');
    END IF;

    UPDATE lims.samples
    SET current_labware_id = labware_tube_one
    WHERE id = sample_pbmc_aliquot
      AND current_labware_id IS DISTINCT FROM labware_tube_one;
  END IF;

  IF labware_plate IS NOT NULL AND sample_blood_draw IS NOT NULL AND pos_a1 IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM lims.sample_labware_assignments
      WHERE sample_id = sample_blood_draw AND labware_id = labware_plate AND labware_position_id = pos_a1
    ) THEN
      INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
      VALUES (sample_blood_draw, labware_plate, pos_a1, now() - interval '12 hours', admin_id, 50, 'µL');
    END IF;
  END IF;

  IF labware_plate IS NOT NULL AND sample_serum_control IS NOT NULL AND pos_a2 IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM lims.sample_labware_assignments
      WHERE sample_id = sample_serum_control AND labware_id = labware_plate AND labware_position_id = pos_a2
    ) THEN
      INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
      VALUES (sample_serum_control, labware_plate, pos_a2, now() - interval '10 hours', admin_id, 45, 'µL');
    END IF;

    UPDATE lims.samples
    SET current_labware_id = labware_plate
    WHERE id = sample_serum_control
      AND current_labware_id IS DISTINCT FROM labware_plate;
  END IF;

  IF labware_tube_two IS NOT NULL AND sample_neutralizing IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM lims.sample_labware_assignments
      WHERE sample_id = sample_neutralizing AND labware_id = labware_tube_two AND labware_position_id IS NULL
    ) THEN
      INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
      VALUES (sample_neutralizing, labware_tube_two, NULL, now() - interval '4 days', admin_id, 1.2, 'mL');
    END IF;

    UPDATE lims.samples
    SET current_labware_id = labware_tube_two
    WHERE id = sample_neutralizing
      AND current_labware_id IS DISTINCT FROM labware_tube_two;
  END IF;

  IF sample_pbmc_batch IS NOT NULL THEN
    -- Ensure legacy sample still reports a current labware if linked via assignment
    UPDATE lims.samples
    SET current_labware_id = (SELECT labware_id FROM lims.sample_labware_assignments WHERE sample_id = sample_pbmc_batch ORDER BY assigned_at DESC LIMIT 1)
    WHERE id = sample_pbmc_batch AND current_labware_id IS NULL;
  END IF;

  IF labware_dna_plate_one IS NOT NULL THEN
    IF sample_dna_batch1_101 IS NOT NULL AND dna_plate_one_a1 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_dna_batch1_101 AND labware_id = labware_dna_plate_one AND labware_position_id = dna_plate_one_a1
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_dna_batch1_101, labware_dna_plate_one, dna_plate_one_a1, now() - interval '20 hours', alice_id, 40, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_dna_plate_one
      WHERE id = sample_dna_batch1_101 AND current_labware_id IS DISTINCT FROM labware_dna_plate_one;
    END IF;

    IF sample_dna_batch1_102 IS NOT NULL AND dna_plate_one_a2 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_dna_batch1_102 AND labware_id = labware_dna_plate_one AND labware_position_id = dna_plate_one_a2
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_dna_batch1_102, labware_dna_plate_one, dna_plate_one_a2, now() - interval '19 hours', alice_id, 38, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_dna_plate_one
      WHERE id = sample_dna_batch1_102 AND current_labware_id IS DISTINCT FROM labware_dna_plate_one;
    END IF;

    IF sample_dna_batch1_103 IS NOT NULL AND dna_plate_one_a3 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_dna_batch1_103 AND labware_id = labware_dna_plate_one AND labware_position_id = dna_plate_one_a3
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_dna_batch1_103, labware_dna_plate_one, dna_plate_one_a3, now() - interval '19 hours', alice_id, 39, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_dna_plate_one
      WHERE id = sample_dna_batch1_103 AND current_labware_id IS DISTINCT FROM labware_dna_plate_one;
    END IF;
  END IF;

  IF labware_dna_plate_two IS NOT NULL THEN
    IF sample_dna_batch2_201 IS NOT NULL AND dna_plate_two_a1 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_dna_batch2_201 AND labware_id = labware_dna_plate_two AND labware_position_id = dna_plate_two_a1
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_dna_batch2_201, labware_dna_plate_two, dna_plate_two_a1, now() - interval '18 hours', alice_id, 36, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_dna_plate_two
      WHERE id = sample_dna_batch2_201 AND current_labware_id IS DISTINCT FROM labware_dna_plate_two;
    END IF;

    IF sample_dna_batch2_202 IS NOT NULL AND dna_plate_two_a2 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_dna_batch2_202 AND labware_id = labware_dna_plate_two AND labware_position_id = dna_plate_two_a2
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_dna_batch2_202, labware_dna_plate_two, dna_plate_two_a2, now() - interval '18 hours', alice_id, 37, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_dna_plate_two
      WHERE id = sample_dna_batch2_202 AND current_labware_id IS DISTINCT FROM labware_dna_plate_two;
    END IF;

    IF sample_dna_batch2_203 IS NOT NULL AND dna_plate_two_a3 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_dna_batch2_203 AND labware_id = labware_dna_plate_two AND labware_position_id = dna_plate_two_a3
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_dna_batch2_203, labware_dna_plate_two, dna_plate_two_a3, now() - interval '17 hours', alice_id, 35, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_dna_plate_two
      WHERE id = sample_dna_batch2_203 AND current_labware_id IS DISTINCT FROM labware_dna_plate_two;
    END IF;
  END IF;

  IF labware_library_plate IS NOT NULL THEN
    IF sample_library_batch1_101 IS NOT NULL AND library_plate_a1 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_library_batch1_101 AND labware_id = labware_library_plate AND labware_position_id = library_plate_a1
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_library_batch1_101, labware_library_plate, library_plate_a1, now() - interval '8 hours', alice_id, 32, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_library_plate
      WHERE id = sample_library_batch1_101 AND current_labware_id IS DISTINCT FROM labware_library_plate;
    END IF;

    IF sample_library_batch1_102 IS NOT NULL AND library_plate_a2 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_library_batch1_102 AND labware_id = labware_library_plate AND labware_position_id = library_plate_a2
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_library_batch1_102, labware_library_plate, library_plate_a2, now() - interval '7 hours', alice_id, 31, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_library_plate
      WHERE id = sample_library_batch1_102 AND current_labware_id IS DISTINCT FROM labware_library_plate;
    END IF;

    IF sample_library_batch1_103 IS NOT NULL AND library_plate_a3 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_library_batch1_103 AND labware_id = labware_library_plate AND labware_position_id = library_plate_a3
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_library_batch1_103, labware_library_plate, library_plate_a3, now() - interval '7 hours', alice_id, 30, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_library_plate
      WHERE id = sample_library_batch1_103 AND current_labware_id IS DISTINCT FROM labware_library_plate;
    END IF;

    IF sample_library_batch2_201 IS NOT NULL AND library_plate_b1 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_library_batch2_201 AND labware_id = labware_library_plate AND labware_position_id = library_plate_b1
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_library_batch2_201, labware_library_plate, library_plate_b1, now() - interval '6 hours', alice_id, 33, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_library_plate
      WHERE id = sample_library_batch2_201 AND current_labware_id IS DISTINCT FROM labware_library_plate;
    END IF;

    IF sample_library_batch2_202 IS NOT NULL AND library_plate_b2 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_library_batch2_202 AND labware_id = labware_library_plate AND labware_position_id = library_plate_b2
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_library_batch2_202, labware_library_plate, library_plate_b2, now() - interval '6 hours', alice_id, 34, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_library_plate
      WHERE id = sample_library_batch2_202 AND current_labware_id IS DISTINCT FROM labware_library_plate;
    END IF;

    IF sample_library_batch2_203 IS NOT NULL AND library_plate_b3 IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM lims.sample_labware_assignments
        WHERE sample_id = sample_library_batch2_203 AND labware_id = labware_library_plate AND labware_position_id = library_plate_b3
      ) THEN
        INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
        VALUES (sample_library_batch2_203, labware_library_plate, library_plate_b3, now() - interval '5 hours', alice_id, 32, 'µL');
      END IF;

      UPDATE lims.samples
      SET current_labware_id = labware_library_plate
      WHERE id = sample_library_batch2_203 AND current_labware_id IS DISTINCT FROM labware_library_plate;
    END IF;
  END IF;

  IF labware_pool_vessel IS NOT NULL AND sample_sequencing_pool IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM lims.sample_labware_assignments
      WHERE sample_id = sample_sequencing_pool AND labware_id = labware_pool_vessel AND labware_position_id IS NULL
    ) THEN
      INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, labware_position_id, assigned_at, assigned_by, volume, volume_unit)
      VALUES (sample_sequencing_pool, labware_pool_vessel, NULL, now() - interval '2 hours', alice_id, 600, 'µL');
    END IF;

    UPDATE lims.samples
    SET current_labware_id = labware_pool_vessel
    WHERE id = sample_sequencing_pool AND current_labware_id IS DISTINCT FROM labware_pool_vessel;
  END IF;

  INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_by)
  SELECT parent_id, child_id, method, COALESCE(alice_id, admin_id)
  FROM (
    VALUES
      (sample_dna_batch1_101, sample_library_batch1_101, 'workflow:indexed_library_prep'),
      (sample_dna_batch1_102, sample_library_batch1_102, 'workflow:indexed_library_prep'),
      (sample_dna_batch1_103, sample_library_batch1_103, 'workflow:indexed_library_prep'),
      (sample_dna_batch2_201, sample_library_batch2_201, 'workflow:indexed_library_prep'),
      (sample_dna_batch2_202, sample_library_batch2_202, 'workflow:indexed_library_prep'),
      (sample_dna_batch2_203, sample_library_batch2_203, 'workflow:indexed_library_prep')
  ) AS mapping(parent_id, child_id, method)
  WHERE parent_id IS NOT NULL
    AND child_id IS NOT NULL
  ON CONFLICT (parent_sample_id, child_sample_id) DO NOTHING;

  INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_by)
  SELECT parent_id, child_id, method, COALESCE(alice_id, admin_id)
  FROM (
    VALUES
      (sample_library_batch1_101, sample_sequencing_pool, 'workflow:library_pooling'),
      (sample_library_batch1_102, sample_sequencing_pool, 'workflow:library_pooling'),
      (sample_library_batch1_103, sample_sequencing_pool, 'workflow:library_pooling'),
      (sample_library_batch2_201, sample_sequencing_pool, 'workflow:library_pooling'),
      (sample_library_batch2_202, sample_sequencing_pool, 'workflow:library_pooling'),
      (sample_library_batch2_203, sample_sequencing_pool, 'workflow:library_pooling')
  ) AS pooling(parent_id, child_id, method)
  WHERE parent_id IS NOT NULL
    AND child_id IS NOT NULL
  ON CONFLICT (parent_sample_id, child_sample_id) DO NOTHING;

END;
$$;

-- Assign seeded samples to statuses/types
UPDATE lims.samples SET sample_status = 'available' WHERE sample_status IS NULL;
UPDATE lims.samples SET sample_type_code = 'cell' WHERE sample_type_code IS NULL AND sample_type = 'cell';
UPDATE lims.samples SET sample_type_code = 'fluid' WHERE sample_type_code IS NULL AND sample_type = 'fluid';
UPDATE lims.samples SET sample_type_code = 'dna' WHERE sample_type_code IS NULL AND sample_type = 'dna';
UPDATE lims.samples SET sample_type_code = 'library' WHERE sample_type_code IS NULL AND sample_type = 'library';
UPDATE lims.samples SET sample_type_code = 'pooled_library' WHERE sample_type_code IS NULL AND sample_type = 'pooled_library';

DO $$
DECLARE
  admin_id uuid := (SELECT id FROM lims.users WHERE email = 'admin@example.org');
  shelf_id uuid := (
    SELECT ss.id
    FROM lims.storage_sublocations ss
    JOIN lims.storage_units su ON su.id = ss.unit_id
    JOIN lims.storage_facilities sf ON sf.id = su.facility_id
    WHERE sf.name = 'Main Lab' AND su.name = 'Freezer 1' AND ss.name = 'Shelf 1'
    LIMIT 1
  );
BEGIN
  IF admin_id IS NULL OR shelf_id IS NULL THEN
    RAISE NOTICE 'Skipping inventory seed data: prerequisites missing.';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lims.inventory_items WHERE barcode = 'INV-CRYO-001') THEN
    INSERT INTO lims.inventory_items(
      barcode,
      name,
      description,
      catalogue_number,
      lot_number,
      quantity,
      unit,
      minimum_quantity,
      storage_requirements,
      expires_at,
      storage_sublocation_id,
      metadata,
      created_by
    )
    VALUES (
      'INV-CRYO-001',
      'Cryovial Labels',
      'Self-adhesive cryogenic labels',
      'LBL-CRYO',
      'LOT-117',
      24,
      'roll',
      10,
      'Store at room temperature',
      now() + interval '8 months',
      shelf_id,
      jsonb_build_object('vendor', 'LabStuff Inc.'),
      admin_id
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lims.inventory_items WHERE barcode = 'INV-REAG-042') THEN
    INSERT INTO lims.inventory_items(
      barcode,
      name,
      description,
      catalogue_number,
      lot_number,
      quantity,
      unit,
      minimum_quantity,
      storage_requirements,
      expires_at,
      storage_sublocation_id,
      metadata,
      created_by
    )
    VALUES (
      'INV-REAG-042',
      'ELISA Wash Buffer',
      'Ready-to-use buffer concentrate',
      'ELISA-WASH',
      'LOT-42B',
      1.5,
      'L',
      2,
      'Keep refrigerated',
      now() + interval '2 months',
      shelf_id,
      jsonb_build_object('hazard', 'Irritant'),
      admin_id
    );
  END IF;
END;
$$;

-------------------------------------------------------------------------------
-- migrate:down
-------------------------------------------------------------------------------

DROP VIEW IF EXISTS lims.v_inventory_status;
DROP VIEW IF EXISTS lims.v_storage_dashboard;
DROP VIEW IF EXISTS lims.v_labware_contents;
DROP VIEW IF EXISTS lims.v_sample_overview;

DROP TABLE IF EXISTS lims.inventory_transactions;
DROP TABLE IF EXISTS lims.inventory_items;
DROP TABLE IF EXISTS lims.inventory_transaction_types;

DROP TABLE IF EXISTS lims.labware_location_history;
DROP TABLE IF EXISTS lims.sample_labware_assignments;
DROP TABLE IF EXISTS lims.custody_events;
DROP TABLE IF EXISTS lims.sample_derivations;
DROP TABLE IF EXISTS lims.labware_positions;
DROP TABLE IF EXISTS lims.labware;
DROP TABLE IF EXISTS lims.labware_types;

ALTER TABLE lims.samples
  DROP COLUMN IF EXISTS current_labware_id,
  DROP COLUMN IF EXISTS updated_at,
  DROP COLUMN IF EXISTS metadata,
  DROP COLUMN IF EXISTS condition_notes,
  DROP COLUMN IF EXISTS collected_by,
  DROP COLUMN IF EXISTS collected_at,
  DROP COLUMN IF EXISTS sample_type_code,
  DROP COLUMN IF EXISTS sample_status;

DROP TABLE IF EXISTS lims.storage_sublocations;
DROP TABLE IF EXISTS lims.storage_units;
DROP TABLE IF EXISTS lims.storage_facilities;

DROP TABLE IF EXISTS lims.custody_event_types;
DROP TABLE IF EXISTS lims.sample_types_lookup;
DROP TABLE IF EXISTS lims.sample_statuses;
