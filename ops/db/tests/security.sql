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

SET ROLE app_researcher;

DO $$
DECLARE
  v_self_id uuid := NULL;
  v_exists integer;
BEGIN
  BEGIN
    v_self_id := current_setting('session.alice_id', true)::uuid;
  EXCEPTION
    WHEN others THEN
      v_self_id := NULL;
  END;

  IF v_self_id IS NULL THEN
    SELECT id INTO v_self_id FROM app_core.users WHERE email = 'alice@example.org';
  END IF;

  PERFORM set_config('app.actor_id', v_self_id::text, true);
  PERFORM set_config('app.actor_identity', 'alice@example.org', true);
  PERFORM set_config('app.roles', 'app_researcher', true);

  SELECT 1 INTO v_exists
  FROM app_core.v_handover_overview
  LIMIT 1;

  -- No exception means the view is accessible under RLS.
  IF v_exists IS NULL THEN
    RAISE NOTICE 'No handover rows visible for researcher (expected if none created)';
  END IF;
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

  IF EXISTS (
    SELECT 1
      FROM app_core.v_labware_contents
     WHERE barcode = 'PLATE-0007'
       AND position_label IS NULL
  ) THEN
    RAISE EXCEPTION 'Slotted plate labware unexpectedly produced null position labels';
  END IF;

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
DECLARE
  v_admin uuid;
  v_operator uuid;
  v_researcher uuid;
  v_research_scope uuid;
  v_ops_scope uuid;
  v_source uuid;
  v_duplicate uuid;
  v_ops_scope_key text := format('ops:test:%s', replace(gen_random_uuid()::text, '-', ''));
  v_value text;
  v_numeric numeric;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin seed user missing';
  END IF;

  PERFORM set_config('app.actor_id', v_admin::text, true);
  PERFORM set_config('app.actor_identity', 'admin@example.org', true);
  PERFORM set_config('app.roles', 'app_admin', true);

  SELECT artefact_id
    INTO v_source
    FROM app_provenance.artefacts
   WHERE external_identifier = 'SAMPLE-GP-001-A';
  IF v_source IS NULL THEN
    RAISE EXCEPTION 'Expected sample artefact missing';
  END IF;

  SELECT scope_id
    INTO v_research_scope
    FROM app_security.scopes
   WHERE scope_key = 'dataset:pilot_plasma';
  IF v_research_scope IS NULL THEN
    RAISE EXCEPTION 'Dataset scope missing';
  END IF;

  v_ops_scope := app_provenance.sp_handover_to_ops(
    p_research_scope_id => v_research_scope,
    p_ops_scope_key     => v_ops_scope_key,
    p_artefact_ids      => ARRAY[v_source],
    p_field_whitelist   => ARRAY['well_volume_ul']
  );

  IF v_ops_scope IS NULL THEN
    RAISE EXCEPTION 'Handover did not return ops scope id';
  END IF;

  SELECT child_artefact_id
    INTO v_duplicate
    FROM app_provenance.artefact_relationships
   WHERE parent_artefact_id = v_source
     AND relationship_type = 'handover_duplicate'
   ORDER BY created_at DESC
   LIMIT 1;

  IF v_duplicate IS NULL THEN
    RAISE EXCEPTION 'Handover duplicate artefact not recorded';
  END IF;

  IF NOT EXISTS (
        SELECT 1
          FROM app_provenance.artefact_scopes
         WHERE artefact_id = v_duplicate
           AND scope_id = v_ops_scope
       ) THEN
    RAISE EXCEPTION 'Ops duplicate missing scope membership';
  END IF;

  SELECT metadata ->> 'well_volume_ul'
    INTO v_value
    FROM app_provenance.artefacts
   WHERE artefact_id = v_duplicate;

  IF v_value IS NULL THEN
    RAISE EXCEPTION 'Ops duplicate missing whitelisted metadata (well_volume_ul)';
  END IF;

  SELECT trim(both '"' FROM tv.value::text)
    INTO v_value
    FROM app_provenance.artefact_trait_values tv
    JOIN app_provenance.artefact_traits t ON t.trait_id = tv.trait_id
   WHERE tv.artefact_id = v_source
    AND t.trait_key = 'transfer_state'
   ORDER BY tv.effective_at DESC
   LIMIT 1;

  IF v_value <> 'transferred' THEN
    RAISE EXCEPTION 'Source artefact transfer_state expected transferred, saw %', v_value;
  END IF;

  SELECT metadata ->> 'well_volume_ul'
    INTO v_value
    FROM app_provenance.artefacts
   WHERE artefact_id = v_duplicate;
  v_numeric := (v_value)::numeric;
  IF v_numeric IS NULL THEN
    RAISE EXCEPTION 'Research visible volume should parse to numeric, saw %', v_value;
  END IF;

  PERFORM set_config('session.handover_source', v_source::text, false);
  PERFORM set_config('session.handover_duplicate', v_duplicate::text, false);
  PERFORM set_config('session.handover_research_scope', v_research_scope::text, false);
  PERFORM set_config('session.handover_ops_scope', v_ops_scope::text, false);
END;
$$;

RESET ROLE;

SET ROLE app_operator;

DO $$
DECLARE
  v_operator uuid := current_setting('session.operator_id', false)::uuid;
  v_duplicate uuid := current_setting('session.handover_duplicate', false)::uuid;
BEGIN
  IF v_operator IS NULL THEN
    RAISE EXCEPTION 'Operator session id missing';
  END IF;
  IF v_duplicate IS NULL THEN
    RAISE EXCEPTION 'Handover duplicate id missing';
  END IF;

  PERFORM set_config('app.actor_id', v_operator::text, true);
  PERFORM set_config('app.actor_identity', 'ops@example.org', true);
  PERFORM set_config('app.roles', 'app_operator', true);

  IF NOT app_provenance.can_update_handover_metadata(v_duplicate) THEN
    RAISE EXCEPTION 'Operator should be permitted to adjust ops duplicate metadata before return';
  END IF;
END;
$$;

RESET ROLE;

SET ROLE app_researcher;

DO $$
DECLARE
  v_researcher uuid := current_setting('session.researcher_id', false)::uuid;
  v_duplicate uuid := current_setting('session.handover_duplicate', false)::uuid;
  v_allowed boolean;
BEGIN
  IF v_researcher IS NULL THEN
    SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';
  END IF;
  IF v_researcher IS NULL THEN
    RAISE EXCEPTION 'Researcher session id missing';
  END IF;
  IF v_duplicate IS NULL THEN
    RAISE EXCEPTION 'Handover duplicate id missing for researcher check';
  END IF;

  PERFORM set_config('app.actor_id', v_researcher::text, true);
  PERFORM set_config('app.actor_identity', 'alice@example.org', true);
  PERFORM set_config('app.roles', 'app_researcher', true);

  SELECT app_provenance.can_access_artefact(v_duplicate)
    INTO v_allowed;
  IF NOT COALESCE(v_allowed, false) THEN
    RAISE EXCEPTION 'Researcher could not see ops duplicate via lineage';
  END IF;

  SELECT app_provenance.can_update_handover_metadata(v_duplicate)
    INTO v_allowed;
  IF COALESCE(v_allowed, false) THEN
    RAISE EXCEPTION 'Researcher should not be allowed to update ops duplicate metadata';
  END IF;
END;
$$;

RESET ROLE;

SET ROLE app_admin;

DO $$
DECLARE
  v_admin uuid;
  v_source uuid := current_setting('session.handover_source', false)::uuid;
  v_duplicate uuid := current_setting('session.handover_duplicate', false)::uuid;
  v_research_scope uuid := current_setting('session.handover_research_scope', false)::uuid;
  v_value text;
  v_numeric numeric;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin seed user missing (phase 2)';
  END IF;
  IF v_source IS NULL OR v_duplicate IS NULL OR v_research_scope IS NULL THEN
    RAISE EXCEPTION 'Handover context missing for admin propagation phase';
  END IF;

  PERFORM set_config('app.actor_id', v_admin::text, true);
  PERFORM set_config('app.actor_identity', 'admin@example.org', true);
  PERFORM set_config('app.roles', 'app_admin', true);

  UPDATE app_provenance.artefacts
     SET metadata = (metadata - 'well_volume_ul') || jsonb_build_object('well_volume_ul', 432)
   WHERE artefact_id = v_source;

  SELECT (metadata ->> 'well_volume_ul')::numeric
    INTO v_numeric
    FROM app_provenance.artefacts
   WHERE artefact_id = v_duplicate;

  IF v_numeric <> 432 THEN
    RAISE EXCEPTION 'Whitelisted propagation failed, expected 432 saw %', v_numeric;
  END IF;

  UPDATE app_provenance.artefacts
     SET metadata = metadata || jsonb_build_object('sensitive_note', 'keep private')
   WHERE artefact_id = v_source;

  IF EXISTS (
        SELECT 1
        FROM app_provenance.artefacts
       WHERE artefact_id = v_duplicate
         AND metadata ? 'sensitive_note'
       ) THEN
    RAISE EXCEPTION 'Non-whitelisted metadata propagated unexpectedly';
  END IF;

  PERFORM app_provenance.sp_return_from_ops(v_duplicate, ARRAY[v_research_scope]);

  SELECT trim(both '"' FROM tv.value::text)
    INTO v_value
    FROM app_provenance.artefact_trait_values tv
    JOIN app_provenance.artefact_traits t ON t.trait_id = tv.trait_id
   WHERE tv.artefact_id = v_duplicate
     AND t.trait_key = 'transfer_state'
   ORDER BY tv.effective_at DESC
   LIMIT 1;

  IF v_value <> 'returned' THEN
    RAISE EXCEPTION 'Ops artefact transfer_state expected returned, saw %', v_value;
  END IF;

  IF NOT EXISTS (
        SELECT 1
        FROM app_provenance.artefact_scopes
       WHERE artefact_id = v_duplicate
         AND scope_id = v_research_scope
       ) THEN
    RAISE EXCEPTION 'Returned ops artefact missing research scope membership';
  END IF;
END;
$$;

RESET ROLE;

SET ROLE app_operator;

DO $$
DECLARE
  v_operator uuid := current_setting('session.operator_id', false)::uuid;
  v_duplicate uuid := current_setting('session.handover_duplicate', false)::uuid;
  v_allowed boolean;
BEGIN
  IF v_operator IS NULL OR v_duplicate IS NULL THEN
    RAISE EXCEPTION 'Operator post-return context missing';
  END IF;

  PERFORM set_config('app.actor_id', v_operator::text, true);
  PERFORM set_config('app.actor_identity', 'ops@example.org', true);
  PERFORM set_config('app.roles', 'app_operator', true);

  SELECT app_provenance.can_update_handover_metadata(v_duplicate)
    INTO v_allowed;
  IF COALESCE(v_allowed, false) THEN
    RAISE EXCEPTION 'Operator should not update metadata once returned';
  END IF;
END;
$$;

RESET ROLE;

SET ROLE app_researcher;

DO $$
DECLARE
  v_researcher uuid := current_setting('session.researcher_id', false)::uuid;
  v_duplicate uuid := current_setting('session.handover_duplicate', false)::uuid;
  v_allowed boolean;
BEGIN
  IF v_researcher IS NULL THEN
    SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';
  END IF;
  IF v_duplicate IS NULL THEN
    RAISE EXCEPTION 'Researcher post-return duplicate id missing';
  END IF;

  PERFORM set_config('app.actor_id', v_researcher::text, true);
  PERFORM set_config('app.actor_identity', 'alice@example.org', true);
  PERFORM set_config('app.roles', 'app_researcher', true);

  SELECT app_provenance.can_access_artefact(v_duplicate)
    INTO v_allowed;
  IF NOT COALESCE(v_allowed, false) THEN
    RAISE EXCEPTION 'Researcher lost visibility after return';
  END IF;
END;
$$;

RESET ROLE;

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


SET ROLE app_admin;

DO $$
DECLARE
  v_admin uuid;
  v_source uuid := current_setting('session.handover_source', true)::uuid;
  v_research_scope uuid := current_setting('session.handover_research_scope', true)::uuid;
  v_collab_scope uuid;
  v_duplicate uuid;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin seed user missing for generalised handover tests';
  END IF;

  IF v_source IS NULL THEN
    SELECT artefact_id INTO v_source
      FROM app_provenance.artefacts
     WHERE external_identifier = 'SAMPLE-GP-001-A';
  END IF;
  IF v_source IS NULL THEN
    RAISE EXCEPTION 'Generalised handover source artefact missing';
  END IF;

  IF v_research_scope IS NULL THEN
    SELECT scope_id INTO v_research_scope
      FROM app_security.scopes
     WHERE scope_key = 'dataset:pilot_plasma';
  END IF;
  IF v_research_scope IS NULL THEN
    RAISE EXCEPTION 'Research scope missing for generalised handover tests';
  END IF;

  v_collab_scope := app_provenance.sp_transfer_between_scopes(
    p_source_scope_id      => v_research_scope,
    p_target_scope_key     => 'project:pilot-collab',
    p_target_scope_type    => 'project',
    p_artefact_ids         => ARRAY[v_source],
    p_field_whitelist      => ARRAY['well_volume_ul'],
    p_allowed_roles        => ARRAY['app_researcher'],
    p_relationship_metadata => jsonb_build_object('test_case', 'generalised-collab')
  );

  IF v_collab_scope IS NULL THEN
    RAISE EXCEPTION 'sp_transfer_between_scopes did not return collab scope id';
  END IF;

  SELECT child_artefact_id
    INTO v_duplicate
    FROM app_provenance.artefact_relationships rel
   WHERE rel.parent_artefact_id = v_source
     AND rel.relationship_type = 'handover_duplicate'
   ORDER BY rel.created_at DESC
   LIMIT 1;

  IF v_duplicate IS NULL THEN
    RAISE EXCEPTION 'Generalised handover duplicate not created';
  END IF;

  PERFORM set_config('session.collab_scope', v_collab_scope::text, false);
  PERFORM set_config('session.collab_duplicate', v_duplicate::text, false);

  INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, granted_by, metadata)
  VALUES (
    v_collab_scope,
    (SELECT id FROM app_core.users WHERE email = 'alice@example.org'),
    'app_researcher',
    v_admin,
    jsonb_build_object('test', 'generalised')
  )
  ON CONFLICT (scope_id, user_id, role_name) DO NOTHING;
END;
$$;

RESET ROLE;

SET ROLE app_researcher;

DO $$
DECLARE
  v_researcher uuid := current_setting('session.researcher_id', true)::uuid;
  v_duplicate uuid := current_setting('session.collab_duplicate', true)::uuid;
  v_roles text[];
  v_allowed boolean;
  v_view record;
BEGIN
  IF v_researcher IS NULL THEN
    SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';
  END IF;
  IF v_researcher IS NULL THEN
    RAISE EXCEPTION 'Researcher session id missing for generalised handover tests';
  END IF;
  IF v_duplicate IS NULL THEN
    RAISE EXCEPTION 'Collaborative duplicate id missing for researcher test';
  END IF;

  PERFORM set_config('app.actor_id', v_researcher::text, true);
  PERFORM set_config('app.actor_identity', 'alice@example.org', true);
  PERFORM set_config('app.roles', 'app_researcher', true);

  v_roles := app_provenance.transfer_allowed_roles(v_duplicate);
  IF array_length(v_roles, 1) IS DISTINCT FROM 1 OR v_roles[1] <> 'app_researcher' THEN
    RAISE EXCEPTION 'Expected transfer_allowed_roles to return app_researcher, saw %', v_roles;
  END IF;

  SELECT app_provenance.can_update_handover_metadata(v_duplicate)
    INTO v_allowed;
  IF NOT COALESCE(v_allowed, false) THEN
    RAISE EXCEPTION 'Researcher should be permitted to update collaborative duplicate metadata';
  END IF;

  SELECT allowed_roles, relationship_type
    INTO v_view
    FROM app_core.v_scope_transfer_overview
   WHERE target_artefact_id = v_duplicate;

  IF v_view.relationship_type IS DISTINCT FROM 'handover_duplicate' THEN
    RAISE EXCEPTION 'Unexpected relationship_type %, expected handover_duplicate', v_view.relationship_type;
  END IF;
  IF NOT (v_view.allowed_roles @> ARRAY['app_researcher']) THEN
    RAISE EXCEPTION 'v_scope_transfer_overview missing expected allowed role set';
  END IF;
END;
$$;

RESET ROLE;

SET ROLE app_operator;

DO $$
DECLARE
  v_operator uuid := current_setting('session.operator_id', true)::uuid;
  v_duplicate uuid := current_setting('session.collab_duplicate', true)::uuid;
BEGIN
  IF v_operator IS NULL THEN
    SELECT id INTO v_operator FROM app_core.users WHERE email = 'ops@example.org';
  END IF;
  IF v_duplicate IS NULL THEN
    RAISE EXCEPTION 'Collaborative duplicate id missing for operator check';
  END IF;

  PERFORM set_config('app.actor_id', v_operator::text, true);
  PERFORM set_config('app.actor_identity', 'ops@example.org', true);
  PERFORM set_config('app.roles', 'app_operator', true);

  IF app_provenance.can_update_handover_metadata(v_duplicate) THEN
    RAISE EXCEPTION 'Operator should not update collaborative duplicate metadata';
  END IF;
END;
$$;

RESET ROLE;

SET ROLE app_researcher;

DO $$
DECLARE
  v_researcher uuid := current_setting('session.researcher_id', true)::uuid;
  v_duplicate uuid := current_setting('session.collab_duplicate', true)::uuid;
  v_collab_scope uuid := current_setting('session.collab_scope', true)::uuid;
  v_return_scope uuid := current_setting('session.handover_research_scope', true)::uuid;
  v_state text;
BEGIN
  IF v_researcher IS NULL THEN
    SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';
  END IF;
  IF v_researcher IS NULL THEN
    RAISE EXCEPTION 'Researcher context missing for completion test';
  END IF;
  IF v_duplicate IS NULL OR v_collab_scope IS NULL THEN
    RAISE EXCEPTION 'Collaborative context missing for completion test';
  END IF;
  IF v_return_scope IS NULL THEN
    RAISE EXCEPTION 'Research scope missing for completion test';
  END IF;

  PERFORM set_config('app.actor_id', v_researcher::text, true);
  PERFORM set_config('app.actor_identity', 'alice@example.org', true);
  PERFORM set_config('app.roles', 'app_researcher', true);

  PERFORM app_provenance.sp_complete_transfer(
    p_target_artefact_id => v_duplicate,
    p_return_scope_ids   => ARRAY[v_return_scope]
  );

  IF NOT EXISTS (
        SELECT 1
        FROM app_provenance.artefact_scopes
       WHERE artefact_id = v_duplicate
         AND scope_id = v_return_scope
         AND relationship = 'derived_from'
     ) THEN
    RAISE EXCEPTION 'Collaborative duplicate missing research derived_from scope after completion';
  END IF;

  SELECT trim(both '"' FROM tv.value::text)
    INTO v_state
    FROM app_provenance.artefact_trait_values tv
    JOIN app_provenance.artefact_traits t ON t.trait_id = tv.trait_id
   WHERE tv.artefact_id = v_duplicate
     AND t.trait_key = 'transfer_state'
   ORDER BY tv.effective_at DESC
   LIMIT 1;

  IF v_state <> 'returned' THEN
    RAISE EXCEPTION 'Collaborative duplicate transfer_state expected returned, saw %', v_state;
  END IF;

  IF app_provenance.can_update_handover_metadata(v_duplicate) THEN
    RAISE EXCEPTION 'Researcher should not update metadata once collaborative handover is complete';
  END IF;
END;
$$;

RESET ROLE;
