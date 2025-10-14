\set ON_ERROR_STOP on
SET client_min_messages TO WARNING;

-- Ensure new schemas exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app_core') THEN
    RAISE EXCEPTION 'app_core schema missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app_security') THEN
    RAISE EXCEPTION 'app_security schema missing';
  END IF;
END;
$$;

-------------------------------------------------------------------------------
-- Admin operations require transaction context
-------------------------------------------------------------------------------

SET ROLE app_admin;

DO $$
DECLARE
  v_txn text;
BEGIN
  PERFORM set_config('app.txn_id', '', true);

  INSERT INTO app_core.roles (role_name, display_name)
  VALUES ('app_temp', 'Temp')
  ON CONFLICT DO NOTHING;

  SELECT current_setting('app.txn_id', true) INTO v_txn;
  IF v_txn IS NULL OR v_txn = '' THEN
    RAISE EXCEPTION 'Transaction context was not auto-initialised for admin write';
  END IF;

  DELETE FROM app_core.roles WHERE role_name = 'app_temp';
  PERFORM set_config('app.txn_id', '', true);
END;
$$;

DO $$
DECLARE
  v_txn uuid;
  v_user_id uuid;
  v_audit_count integer;
  v_email text := format('unit-%s@example.org', substr(gen_random_uuid()::text, 1, 8));
BEGIN
  v_txn := app_security.start_transaction_context(
    p_actor_id => (SELECT id FROM app_core.users WHERE email = 'admin@example.org'),
    p_actor_identity => 'unit-test-admin',
    p_effective_roles => ARRAY['app_admin'],
    p_client_app => 'unit-tests'
  );

  INSERT INTO app_core.users (external_id, email, full_name, default_role, metadata)
  VALUES ('urn:app:' || v_email, v_email, 'Unit Test User', 'app_researcher', jsonb_build_object('test', true))
  RETURNING id INTO v_user_id;

  UPDATE app_core.users
  SET full_name = 'Unit Test User Updated'
  WHERE id = v_user_id;

  DELETE FROM app_core.users WHERE id = v_user_id;

  SELECT count(*)
    INTO v_audit_count
    FROM app_security.audit_log
   WHERE txn_id = v_txn
     AND table_name = 'users';

  IF v_audit_count <> 3 THEN
    RAISE EXCEPTION 'Expected 3 audit rows for insert/update/delete, saw %', v_audit_count;
  END IF;

  PERFORM app_security.finish_transaction_context(v_txn, 'committed', 'unit tests');
END;
$$;

DO $$
DECLARE
  v_operator uuid;
  v_researcher uuid;
  v_external uuid;
  v_automation uuid;
BEGIN
  SELECT id INTO v_operator FROM app_core.users WHERE email = 'ops@example.org';
  PERFORM set_config('session.operator_id', v_operator::text, false);

  SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';
  IF v_researcher IS NOT NULL THEN
    PERFORM set_config('session.researcher_id', v_researcher::text, false);
  END IF;

  INSERT INTO app_core.users (external_id, email, full_name, default_role, metadata)
  VALUES (
    'urn:app:external',
    'external@example.org',
    'External Collaborator',
    'app_external',
    jsonb_build_object('seed', true)
  )
  ON CONFLICT (email) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        default_role = EXCLUDED.default_role
  RETURNING id INTO v_external;

  INSERT INTO app_core.user_roles (user_id, role_name, granted_by)
  VALUES (v_external, 'app_external', (SELECT id FROM app_core.users WHERE email = 'admin@example.org'))
  ON CONFLICT (user_id, role_name) DO NOTHING;

  PERFORM set_config('session.external_id', v_external::text, false);

  INSERT INTO app_core.users (external_id, email, full_name, default_role, metadata, is_service_account)
  VALUES (
    'urn:app:automation',
    'automation@example.org',
    'Automation Service',
    'app_automation',
    jsonb_build_object('seed', true),
    true
  )
  ON CONFLICT (email) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        default_role = EXCLUDED.default_role,
        is_service_account = EXCLUDED.is_service_account
  RETURNING id INTO v_automation;

  INSERT INTO app_core.user_roles (user_id, role_name, granted_by)
  VALUES (v_automation, 'app_automation', (SELECT id FROM app_core.users WHERE email = 'admin@example.org'))
  ON CONFLICT (user_id, role_name) DO NOTHING;

  PERFORM set_config('session.automation_id', v_automation::text, false);
END;
$$;

DO $$
DECLARE
  v_status text;
  v_finished_at timestamptz;
BEGIN
  SELECT finished_status, finished_at
    INTO v_status, v_finished_at
    FROM app_security.transaction_contexts
   ORDER BY started_at DESC
   LIMIT 1;

  IF v_status <> 'committed' OR v_finished_at IS NULL THEN
    RAISE EXCEPTION 'Latest transaction context not closed properly (status %, finished_at %)', v_status, v_finished_at;
  END IF;
END;
$$;

-- Ensure transaction context must be active to finish
DO $$
BEGIN
  BEGIN
    PERFORM app_security.finish_transaction_context(NULL, 'committed', 'should fail');
    RAISE EXCEPTION 'finish_transaction_context unexpectedly succeeded';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT LIKE '%No transaction context active%' THEN
        RAISE EXCEPTION 'Unexpected finish error: %', SQLERRM;
      END IF;
  END;
END;
$$;

-------------------------------------------------------------------------------
-- RLS behaviour for researcher persona
-------------------------------------------------------------------------------

SET ROLE app_researcher;

DO $$
DECLARE
  v_self_id uuid;
  v_dataset_scope uuid;
  v_count integer;
  v_names text[];
BEGIN
  EXECUTE format('SET app.roles = %L', 'app_admin');
  SELECT id INTO v_self_id FROM app_core.users WHERE email = 'alice@example.org';
  EXECUTE format('SET app.roles = %L', 'app_researcher');

  IF v_self_id IS NULL THEN
    RAISE EXCEPTION 'Researcher seed user missing';
  END IF;

  EXECUTE format('SET app.roles = %L', 'app_admin');
  SELECT scope_id INTO v_dataset_scope
  FROM app_security.scopes
  WHERE scope_key = 'dataset:pilot_plasma';
  EXECUTE format('SET app.roles = %L', 'app_researcher');

  IF v_dataset_scope IS NULL THEN
    RAISE EXCEPTION 'Dataset scope missing for tests';
  END IF;

  EXECUTE format('SET app.actor_id = %L', v_self_id::text);
  EXECUTE format('SET app.actor_identity = %L', 'alice@example.org');
  EXECUTE format('SET app.roles = %L', 'app_researcher');

  IF NOT app_security.actor_has_scope(v_dataset_scope) THEN
    RAISE EXCEPTION 'Researcher failed to resolve dataset scope';
  END IF;

  EXECUTE format('SET app.roles = %L', 'app_admin');
  SELECT count(*) INTO v_count
  FROM app_security.scope_memberships
  WHERE user_id = v_self_id
    AND scope_id = v_dataset_scope;
  EXECUTE format('SET app.roles = %L', 'app_researcher');
  IF v_count = 0 THEN
    RAISE EXCEPTION 'Researcher membership missing for dataset scope';
  END IF;

  IF position('app_admin' in coalesce(current_setting('app.roles', true), '')) > 0 THEN
    RAISE EXCEPTION 'Roles unexpectedly retain admin: %', current_setting('app.roles', true);
  END IF;
  IF app_provenance.can_access_artefact((SELECT artefact_id FROM app_provenance.artefacts WHERE external_identifier = 'REAGENT-BUF-042')) THEN
    RAISE EXCEPTION 'Researcher unexpectedly granted facility reagent access';
  END IF;

  IF app_security.has_role('app_admin') THEN
    RAISE EXCEPTION 'Researcher unexpectedly satisfies admin role check';
  END IF;

  SELECT array_agg(name ORDER BY name)
    INTO v_names
    FROM app_provenance.v_accessible_artefacts;

  IF v_names IS NULL OR array_position(v_names, 'Plasma Aliquot GP-001-A') IS NULL THEN
    RAISE EXCEPTION 'Researcher could not view plasma aliquot (names=%)', v_names;
  END IF;
  IF array_position(v_names, 'FASTQ Bundle GP-001-A') IS NULL THEN
    RAISE EXCEPTION 'Researcher could not view sequencing data product';
  END IF;
  IF array_position(v_names, 'Plasma Prep Buffer Lot 42') IS NOT NULL THEN
    RAISE EXCEPTION 'Researcher unexpectedly saw facility-only reagent';
  END IF;

  BEGIN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship)
    VALUES (
      (SELECT artefact_id FROM app_provenance.artefacts WHERE external_identifier = 'SAMPLE-GP-001-A'),
      v_dataset_scope,
      'supplementary'
    );
    RAISE EXCEPTION 'Researcher unexpectedly inserted artefact scope row';
  EXCEPTION
    WHEN others THEN
      IF SQLSTATE NOT IN ('42501','55000','P0001') AND SQLERRM NOT LIKE '%permission denied%' AND SQLERRM NOT LIKE '%row-level security%' THEN
        RAISE;
      END IF;
  END;
END;
$$;

RESET ROLE;

-------------------------------------------------------------------------------
-- Convenience views include slotless labware contents
-------------------------------------------------------------------------------

SET ROLE app_admin;

DO $$
DECLARE
  v_admin_id uuid;
  v_samples text[];
BEGIN
  SELECT id INTO v_admin_id
  FROM app_core.users
  WHERE email = 'admin@example.org';

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin seed user missing';
  END IF;

  PERFORM set_config('app.actor_id', v_admin_id::text, false);
  PERFORM set_config('app.actor_identity', 'admin@example.org', false);
  PERFORM set_config('app.roles', 'app_admin', false);

  SELECT array_agg(sample_name ORDER BY sample_name)
    INTO v_samples
    FROM app_core.v_labware_contents
   WHERE barcode = 'TUBE-0001'
     AND position_label IS NULL;

  IF v_samples IS NULL OR array_length(v_samples, 1) <> 2 THEN
    RAISE EXCEPTION 'Slotless labware sample set unexpected: %', v_samples;
  END IF;

  IF v_samples <> ARRAY['Organoid Expansion Batch RDX-01 Cryo Backup', 'Serum QC Control Sample'] THEN
    RAISE EXCEPTION 'Slotless labware sample set mismatch: %', v_samples;
  END IF;
END;
$$;

RESET ROLE;

-------------------------------------------------------------------------------
-- Convenience views include slotted plate labware contents
-------------------------------------------------------------------------------

SET ROLE app_admin;

DO $$
DECLARE
  v_admin_id uuid;
  v_positions text[];
BEGIN
  SELECT id INTO v_admin_id
  FROM app_core.users
  WHERE email = 'admin@example.org';

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin seed user missing';
  END IF;

  PERFORM set_config('app.actor_id', v_admin_id::text, false);
  PERFORM set_config('app.actor_identity', 'admin@example.org', false);
  PERFORM set_config('app.roles', 'app_admin', false);

  SELECT array_agg(format('%s:%s', position_label, sample_name) ORDER BY position_label, sample_name)
    INTO v_positions
    FROM app_core.v_labware_contents
   WHERE barcode = 'PLATE-0007';

  IF v_positions IS NULL OR array_length(v_positions, 1) <> 2 THEN
    RAISE EXCEPTION 'Slotted plate labware sample set unexpected: %', v_positions;
  END IF;

  IF v_positions <> ARRAY['A1:Plasma Aliquot GP-001-A', 'A2:Plasma Prep Buffer Lot 42'] THEN
    RAISE EXCEPTION 'Slotted plate labware sample set mismatch: %', v_positions;
  END IF;
END;
$$;

RESET ROLE;

-------------------------------------------------------------------------------
-- RLS behaviour for operator persona
-------------------------------------------------------------------------------

SET ROLE app_operator;

DO $$
DECLARE
  v_self_id uuid;
  v_count integer;
  v_node_count integer;
  v_sample_id uuid;
  v_shelf_id uuid;
  v_txn uuid;
BEGIN
  EXECUTE format('SET app.roles = %L', 'app_admin');
  SELECT id INTO v_self_id FROM app_core.users WHERE email = 'ops@example.org';
  EXECUTE format('SET app.roles = %L', 'app_operator');

  IF v_self_id IS NULL THEN
    RAISE EXCEPTION 'Operator seed user missing';
  END IF;

  EXECUTE format('SET app.actor_id = %L', v_self_id::text);
  EXECUTE format('SET app.actor_identity = %L', 'ops@example.org');
  EXECUTE format('SET app.roles = %L', 'app_operator');

  SELECT count(*) INTO v_count FROM app_core.users;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Operator should only see self, saw %', v_count;
  END IF;

  BEGIN
    INSERT INTO app_core.users (email, full_name, default_role)
    VALUES ('operator-denied@example.org', 'Should Fail', 'app_researcher');
    RAISE EXCEPTION 'Operator unexpectedly inserted user';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT LIKE '%permission denied%' AND SQLERRM NOT LIKE '%violates row-level security%' THEN
        RAISE;
      END IF;
  END;

  UPDATE app_core.users
  SET full_name = 'Should Fail'
  WHERE email = 'admin@example.org';
  IF FOUND THEN
    RAISE EXCEPTION 'Operator unexpectedly updated admin record';
  END IF;

  BEGIN
    PERFORM 1 FROM app_security.api_tokens;
    RAISE EXCEPTION 'Operator unexpectedly read api_tokens';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN others THEN
      IF SQLERRM NOT LIKE '%permission denied%' THEN
        RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_node_count FROM app_provenance.storage_nodes;
  IF v_node_count < 3 THEN
    RAISE EXCEPTION 'Operator expected storage nodes to be visible (count=%).', v_node_count;
  END IF;

  v_sample_id := (SELECT artefact_id FROM app_provenance.artefacts WHERE external_identifier = 'SAMPLE-GP-001-A');
  v_shelf_id := (SELECT storage_node_id FROM app_provenance.storage_nodes WHERE node_key = 'sublocation:freezer_nf1:shelf_a');

  IF NOT app_provenance.can_access_artefact(v_sample_id) THEN
    RAISE EXCEPTION 'Operator should have access to sample artefact';
  END IF;

  v_txn := app_security.start_transaction_context(
    p_actor_id => v_self_id,
    p_actor_identity => 'ops@example.org',
    p_effective_roles => ARRAY['app_operator'],
    p_client_app => 'unit-tests'
  );

  INSERT INTO app_provenance.artefact_storage_events (
    artefact_id,
    from_storage_node_id,
    to_storage_node_id,
    event_type,
    occurred_at,
    actor_id,
    reason,
    metadata
  )
  VALUES (
    v_sample_id,
    v_shelf_id,
    NULL,
    'check_out',
    clock_timestamp(),
    v_self_id,
    'unit-test checkout',
    jsonb_build_object('unit_test','operator')
  );

  EXECUTE 'SET ROLE app_admin';
  EXECUTE format('SET app.roles = %L', 'app_admin');
  DELETE FROM app_provenance.artefact_storage_events
  WHERE metadata ->> 'unit_test' = 'operator';
  EXECUTE 'SET ROLE app_operator';
  EXECUTE format('SET app.roles = %L', 'app_operator');

  PERFORM app_security.finish_transaction_context(v_txn, 'rolled_back', 'unit-tests');
END;
$$;

RESET ROLE;

-------------------------------------------------------------------------------
-- RLS behaviour for external persona
-------------------------------------------------------------------------------

SET ROLE app_external;

DO $$
DECLARE
  v_self_id uuid := current_setting('session.external_id', false)::uuid;
  v_count integer;
BEGIN
  EXECUTE format('SET app.actor_id = %L', v_self_id::text);
  EXECUTE format('SET app.actor_identity = %L', 'external@example.org');
  EXECUTE format('SET app.roles = %L', 'app_external');

  SELECT count(*) INTO v_count FROM app_core.users;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'External should only see self, saw %', v_count;
  END IF;

  BEGIN
    INSERT INTO app_core.users (email, full_name, default_role)
    VALUES ('external-denied@example.org', 'Should Fail', 'app_researcher');
    RAISE EXCEPTION 'External unexpectedly inserted user';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT LIKE '%permission denied%' AND SQLERRM NOT LIKE '%violates row-level security%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    PERFORM 1 FROM app_security.api_tokens;
    RAISE EXCEPTION 'External unexpectedly read api_tokens';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN others THEN
      IF SQLERRM NOT LIKE '%permission denied%' THEN
        RAISE;
      END IF;
  END;
END;
$$;

RESET ROLE;

-------------------------------------------------------------------------------
-- RLS behaviour for automation persona
-------------------------------------------------------------------------------

SET ROLE app_automation;

DO $$
DECLARE
  v_self_id uuid := current_setting('session.automation_id', false)::uuid;
  v_count integer;
BEGIN
  EXECUTE format('SET app.actor_id = %L', v_self_id::text);
  EXECUTE format('SET app.actor_identity = %L', 'automation@example.org');
  EXECUTE format('SET app.roles = %L', 'app_automation');

  SELECT count(*) INTO v_count FROM app_core.users;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Automation role should only see itself, saw %', v_count;
  END IF;

  BEGIN
    INSERT INTO app_core.users (email, full_name, default_role)
    VALUES ('automation-denied@example.org', 'Should Fail', 'app_researcher');
    RAISE EXCEPTION 'Automation unexpectedly inserted user';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT LIKE '%permission denied%' AND SQLERRM NOT LIKE '%violates row-level security%' THEN
        RAISE;
      END IF;
  END;
END;
$$;

SET ROLE app_admin;
DO $$
BEGIN
  PERFORM set_config('session.alice_id', (SELECT id::text FROM app_core.users WHERE email = 'alice@example.org'), false);
END;
$$;
RESET ROLE;
SET ROLE app_researcher;

DO $$
DECLARE
  v_self_count integer;
  v_other_count integer;
  v_self_id uuid := current_setting('session.alice_id', false)::uuid;
BEGIN
  EXECUTE format('SET app.actor_id = %L', v_self_id::text);
  EXECUTE format('SET app.actor_identity = %L', 'alice@example.org');
  EXECUTE format('SET app.roles = %L', 'app_researcher');

  SELECT count(*) INTO v_self_count FROM app_core.users;
  IF v_self_count <> 1 THEN
    RAISE EXCEPTION 'Researcher should only see 1 user row, saw %', v_self_count;
  END IF;

  SELECT count(*) INTO v_other_count FROM app_core.users WHERE email <> 'alice@example.org';
  IF v_other_count <> 0 THEN
    RAISE EXCEPTION 'Researcher saw other user rows: %', v_other_count;
  END IF;

  BEGIN
    PERFORM 1 FROM app_security.api_tokens;
    RAISE EXCEPTION 'Researcher unexpectedly read api_tokens';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END;
$$;

RESET ROLE;
