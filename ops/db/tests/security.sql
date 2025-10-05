\set ON_ERROR_STOP on
SET client_min_messages TO WARNING;

-- Ensure tables exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'lims' AND table_name = 'user_tokens') THEN
    RAISE EXCEPTION 'lims.user_tokens table missing';
  END IF;
END;
$$;

-- Create a service account user and token as admin
SET ROLE app_admin;

DO $$
DECLARE
  admin_id uuid;
  service_user_id uuid;
  token_id uuid;
  digest text;
  hint text;
BEGIN
  SELECT id INTO admin_id FROM lims.users WHERE email = 'admin@example.org';

  INSERT INTO lims.users (external_id, email, full_name, default_role, is_service_account, metadata, is_active)
  VALUES (
    'urn:lims:service:test-client',
    'test-client@service.local',
    'Test Client',
    'app_operator',
    true,
    jsonb_build_object('origin', 'security test'),
    true
  )
  ON CONFLICT (email) DO UPDATE
    SET is_service_account = true
  RETURNING id INTO service_user_id;

  INSERT INTO lims.user_roles (user_id, role_name, granted_by)
  VALUES (service_user_id, 'app_operator', admin_id)
  ON CONFLICT (user_id, role_name) DO NOTHING;

  token_id := lims.create_api_token(service_user_id, repeat('a', 32) || 'XYZ123', ARRAY['app_operator'], now() + interval '1 day');
  SELECT token_digest, token_hint INTO digest, hint FROM lims.user_tokens WHERE id = token_id;

  IF digest IS NULL OR length(digest) <> 64 THEN
    RAISE EXCEPTION 'Token digest not stored correctly';
  END IF;

  IF hint IS DISTINCT FROM 'XYZ123' THEN
    RAISE EXCEPTION 'Token hint was not derived correctly';
  END IF;
END;
$$;

RESET ROLE;

-- Cache researcher IDs for session use under RLS
SET ROLE app_admin;
SELECT set_config('session.alice_id', (SELECT id::text FROM lims.users WHERE email = 'alice@example.org'), false);
SELECT set_config('session.bob_id', (SELECT id::text FROM lims.users WHERE email = 'bob@example.org'), false);
RESET ROLE;

-- Labware and storage setup
SET ROLE app_admin;
DO $$
DECLARE
  facility_id_var uuid;
  unit_id_var uuid;
  sublocation_id_var uuid;
  labware_id uuid;
  sample_id uuid;
BEGIN
  SELECT id INTO facility_id_var FROM lims.storage_facilities WHERE name = 'Main Lab';
  IF facility_id_var IS NULL THEN
    INSERT INTO lims.storage_facilities(name) VALUES ('Test Facility') RETURNING id INTO facility_id_var;
  END IF;

  INSERT INTO lims.storage_units(facility_id, name, storage_type)
  VALUES (facility_id_var, 'Test Freezer', 'freezer')
  ON CONFLICT (facility_id, name) DO NOTHING;

  SELECT id INTO unit_id_var FROM lims.storage_units WHERE facility_id = facility_id_var AND name = 'Test Freezer';

  INSERT INTO lims.storage_sublocations(unit_id, name, capacity)
  VALUES (unit_id_var, 'Rack A', 20)
  ON CONFLICT (unit_id, name) DO NOTHING;

  SELECT id INTO sublocation_id_var FROM lims.storage_sublocations WHERE unit_id = unit_id_var AND name = 'Rack A';

  INSERT INTO lims.labware(labware_type_id, barcode, current_storage_sublocation_id, created_by)
  VALUES ((SELECT id FROM lims.labware_types WHERE name = '2mL Tube' LIMIT 1), 'TEST-LABWARE-001', sublocation_id_var, (SELECT id FROM lims.users WHERE email = 'admin@example.org'))
  ON CONFLICT (barcode) DO NOTHING;

  SELECT id INTO labware_id FROM lims.labware WHERE barcode = 'TEST-LABWARE-001';
  SELECT id INTO sample_id FROM lims.samples WHERE name = 'PBMC Batch 001';

  INSERT INTO lims.sample_labware_assignments(sample_id, labware_id, assigned_by)
  VALUES (sample_id, labware_id, (SELECT id FROM lims.users WHERE email = 'admin@example.org'))
  ON CONFLICT DO NOTHING;

  UPDATE lims.samples SET current_labware_id = labware_id WHERE id = sample_id;
END;
$$;

RESET ROLE;

-- Researcher should only see their own record via RLS (simulating PostgREST session)
SET ROLE app_researcher;
SELECT set_config('lims.current_roles', 'app_researcher', false);
SELECT set_config('lims.current_user_id', current_setting('session.alice_id', true), false);

DO $$
DECLARE
  total_users integer;
  others integer;
  visible_projects text[];
BEGIN
  SELECT count(*) INTO total_users FROM lims.users;
  IF total_users <> 1 THEN
    RAISE EXCEPTION 'Researcher should only see their own user record';
  END IF;

  SELECT count(*) INTO others FROM lims.users WHERE email <> 'alice@example.org';
  IF others <> 0 THEN
    RAISE EXCEPTION 'Researcher was able to see other user records';
  END IF;

  IF (SELECT count(*) FROM lims.user_tokens) <> 0 THEN
    RAISE EXCEPTION 'Researcher should not see other user tokens';
  END IF;

  BEGIN
    UPDATE lims.labware SET display_name = 'Should fail' WHERE barcode = 'TEST-LABWARE-001';
    RAISE EXCEPTION 'Researcher should not update labware';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;

  SELECT count(*) INTO total_users FROM lims.v_sample_overview WHERE current_labware_barcode = 'TEST-LABWARE-001';
  IF total_users <> 1 THEN
    RAISE EXCEPTION 'Researcher should see sample overview for their accessible sample';
  END IF;

  SELECT array_agg(project_code ORDER BY project_code) INTO visible_projects
  FROM lims.projects;
  IF visible_projects IS NULL OR visible_projects <> ARRAY['PRJ-001','PRJ-002'] THEN
    RAISE EXCEPTION 'Alice project visibility incorrect: %', visible_projects;
  END IF;
END;
$$;

RESET ROLE;

-- Custody events must remain in chronological order per sample
DO $$
DECLARE
  out_of_order integer;
BEGIN
  SELECT count(*) INTO out_of_order
  FROM (
    SELECT sample_id,
           performed_at,
           lag(performed_at) OVER (PARTITION BY sample_id ORDER BY performed_at) AS prev_at
    FROM lims.custody_events
  ) ordered
  WHERE prev_at IS NOT NULL AND performed_at < prev_at;

  IF out_of_order > 0 THEN
    RAISE EXCEPTION 'Custody events detected out-of-order timestamps';
  END IF;
END;
$$;

-- Active labware occupancy may not exceed the declared capacity
DO $$
DECLARE
  over_capacity integer;
BEGIN
  SELECT count(*) INTO over_capacity
  FROM (
    SELECT lw.id,
           lt.capacity,
           count(*) FILTER (WHERE sla.released_at IS NULL) AS active_assignments
    FROM lims.labware lw
    JOIN lims.labware_types lt ON lt.id = lw.labware_type_id
    LEFT JOIN lims.sample_labware_assignments sla ON sla.labware_id = lw.id
    GROUP BY lw.id, lt.capacity
  ) occupancy
  WHERE occupancy.capacity IS NOT NULL
    AND occupancy.capacity >= 0
    AND occupancy.active_assignments > occupancy.capacity;

  IF over_capacity > 0 THEN
    RAISE EXCEPTION 'Labware exceeded configured capacity';
  END IF;
END;
$$;

-- Inventory balances must remain non-negative in all records
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM lims.inventory_items WHERE quantity < 0) THEN
    RAISE EXCEPTION 'Inventory item quantity dropped below zero';
  END IF;

  IF EXISTS (SELECT 1 FROM lims.inventory_transactions WHERE resulting_quantity IS NOT NULL AND resulting_quantity < 0) THEN
    RAISE EXCEPTION 'Inventory transaction recorded negative resulting quantity';
  END IF;
END;
$$;

-- Second researcher should only see their own data
SET ROLE app_researcher;
SELECT set_config('lims.current_roles', 'app_researcher', false);
SELECT set_config('lims.current_user_id', current_setting('session.bob_id', true), false);

DO $$
DECLARE
  visible_users integer;
  visible_projects text[];
BEGIN
  SELECT count(*) INTO visible_users FROM lims.users;
  IF visible_users <> 1 THEN
    RAISE EXCEPTION 'Bob should only see his own user record';
  END IF;

  IF EXISTS (SELECT 1 FROM lims.users WHERE email <> 'bob@example.org') THEN
    RAISE EXCEPTION 'Bob was able to see other user records';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM lims.samples
    WHERE name IN ('PBMC Batch 001', 'Serum Plate Control')
  ) THEN
    RAISE EXCEPTION 'Bob should not see Alice samples';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM lims.samples
    WHERE name = 'Neutralizing Panel B'
  ) THEN
    RAISE EXCEPTION 'Bob did not see his own sample';
  END IF;

  IF (SELECT count(*) FROM lims.v_sample_overview) <> 1 THEN
    RAISE EXCEPTION 'Bob sample overview count mismatch';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM lims.v_sample_overview
    WHERE name = 'Neutralizing Panel B'
  ) THEN
    RAISE EXCEPTION 'Bob sample overview missing own record';
  END IF;

  SELECT array_agg(project_code ORDER BY project_code) INTO visible_projects
  FROM lims.projects;
  IF visible_projects IS NULL OR visible_projects <> ARRAY['PRJ-003'] THEN
    RAISE EXCEPTION 'Bob project visibility incorrect: %', visible_projects;
  END IF;

  BEGIN
    PERFORM 1 FROM lims.inventory_items;
    RAISE EXCEPTION 'Bob should not see inventory items';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END;
$$;

RESET ROLE;

-- Clean up
SET ROLE app_admin;
DELETE FROM lims.user_tokens WHERE user_id IN (SELECT id FROM lims.users WHERE email = 'test-client@service.local');
DELETE FROM lims.user_roles WHERE user_id IN (SELECT id FROM lims.users WHERE email = 'test-client@service.local');
DELETE FROM lims.users WHERE email = 'test-client@service.local';
UPDATE lims.samples SET current_labware_id = NULL WHERE current_labware_id IN (SELECT id FROM lims.labware WHERE barcode = 'TEST-LABWARE-001');
DELETE FROM lims.sample_labware_assignments WHERE labware_id IN (SELECT id FROM lims.labware WHERE barcode = 'TEST-LABWARE-001');
DELETE FROM lims.labware WHERE barcode = 'TEST-LABWARE-001';
RESET ROLE;
