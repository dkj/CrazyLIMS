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

  PERFORM pg_temp.isnt_null(v_self_id, 'Researcher fixture user present');

  EXECUTE format('SET app.roles = %L', 'app_admin');
  SELECT scope_id INTO v_dataset_scope
  FROM app_security.scopes
  WHERE scope_key = 'dataset:pilot_plasma';
  EXECUTE format('SET app.roles = %L', 'app_researcher');

  PERFORM pg_temp.isnt_null(v_dataset_scope, 'Dataset pilot plasma scope fixture present');

  EXECUTE format('SET app.actor_id = %L', v_self_id::text);
  EXECUTE format('SET app.actor_identity = %L', 'alice@example.org');
  EXECUTE format('SET app.roles = %L', 'app_researcher');

  PERFORM pg_temp.ok(app_security.actor_has_scope(v_dataset_scope), 'Researcher resolves dataset scope membership');

  EXECUTE format('SET app.roles = %L', 'app_admin');
  SELECT count(*) INTO v_count
  FROM app_security.scope_memberships
  WHERE user_id = v_self_id
    AND scope_id = v_dataset_scope;
  EXECUTE format('SET app.roles = %L', 'app_researcher');
  PERFORM pg_temp.cmp_ok(v_count, '>', 0, 'Researcher membership recorded for dataset scope');

  PERFORM pg_temp.is(
    position('app_admin' in coalesce(current_setting('app.roles', true), '')),
    0,
    'Researcher role context excludes admin privileges'
  );
  PERFORM pg_temp.ok(
    NOT app_provenance.can_access_artefact((
      SELECT artefact_id FROM app_provenance.artefacts WHERE external_identifier = 'REAGENT-BUF-042'
    )),
    'Researcher blocked from facility-only reagent'
  );

  PERFORM pg_temp.ok(NOT app_security.has_role('app_admin'), 'Researcher does not satisfy admin role checks');

  SELECT array_agg(name ORDER BY name)
    INTO v_names
    FROM app_provenance.v_accessible_artefacts;

  PERFORM pg_temp.isnt_null(v_names, 'Researcher resolved accessible artefact names');
  PERFORM pg_temp.ok(array_position(v_names, 'Plasma Aliquot GP-001-A') IS NOT NULL, 'Researcher can view plasma aliquot');
  PERFORM pg_temp.ok(array_position(v_names, 'FASTQ Bundle GP-001-A') IS NOT NULL, 'Researcher can view sequencing data product');
  PERFORM pg_temp.ok(array_position(v_names, 'Plasma Prep Buffer Lot 42') IS NULL, 'Researcher cannot view facility-only reagent');

  BEGIN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship)
    VALUES (
      (SELECT artefact_id FROM app_provenance.artefacts WHERE external_identifier = 'SAMPLE-GP-001-A'),
      v_dataset_scope,
      'supplementary'
    );
    PERFORM pg_temp.fail('Researcher unexpectedly inserted artefact scope row');
  EXCEPTION
    WHEN others THEN
      PERFORM pg_temp.ok(
        SQLSTATE IN ('42501','55000','P0001')
        OR SQLERRM LIKE '%permission denied%'
        OR SQLERRM LIKE '%row-level security%',
        'Researcher prevented from writing provenance scope memberships'
      );
  END;
END;
$$;


RESET ROLE;

-------------------------------------------------------------------------------
-- Researcher can access handover overview view
-------------------------------------------------------------------------------

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
  v_event_time timestamptz := timestamptz '2025-01-02 08:15+00';
  v_checkout_time timestamptz := timestamptz '2025-01-02 09:00+00';
  v_last_type text;
  v_last_at timestamptz;
  v_view_type text;
  v_view_at timestamptz;
BEGIN
  EXECUTE format('SET app.roles = %L', 'app_admin');
  SELECT id INTO v_self_id FROM app_core.users WHERE email = 'ops@example.org';
  EXECUTE format('SET app.roles = %L', 'app_operator');

  PERFORM pg_temp.isnt_null(v_self_id, 'Operator fixture user present');

  EXECUTE format('SET app.actor_id = %L', v_self_id::text);
  EXECUTE format('SET app.actor_identity = %L', 'ops@example.org');
  EXECUTE format('SET app.roles = %L', 'app_operator');

  SELECT count(*) INTO v_count FROM app_core.users;
  PERFORM pg_temp.is(v_count, 1, 'Operator sees only own user row');

  BEGIN
    INSERT INTO app_core.users (email, full_name, default_role)
    VALUES ('operator-denied@example.org', 'Should Fail', 'app_researcher');
    PERFORM pg_temp.fail('Operator unexpectedly inserted user');
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT LIKE '%permission denied%' AND SQLERRM NOT LIKE '%violates row-level security%' THEN
        RAISE;
      END IF;
  END;

  UPDATE app_core.users
  SET full_name = 'Should Fail'
  WHERE email = 'admin@example.org';
  PERFORM pg_temp.ok(NOT FOUND, 'Operator cannot update admin record');

  BEGIN
    PERFORM 1 FROM app_security.api_tokens;
    PERFORM pg_temp.fail('Operator unexpectedly read api_tokens');
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN others THEN
      IF SQLERRM NOT LIKE '%permission denied%' THEN
        RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_node_count
  FROM app_provenance.artefacts a
  JOIN app_provenance.artefact_types t ON t.artefact_type_id = a.artefact_type_id
  WHERE t.type_key IN ('storage_facility','storage_unit','storage_sublocation','storage_virtual','storage_external');
  PERFORM pg_temp.cmp_ok(v_node_count, '>=', 3, 'Operator can view storage artefacts');

  v_sample_id := (SELECT artefact_id FROM app_provenance.artefacts WHERE external_identifier = 'SAMPLE-GP-001-A');
  v_shelf_id := (SELECT artefact_id FROM app_provenance.artefacts WHERE external_identifier = 'sublocation:freezer_nf1:shelf_a');

  PERFORM pg_temp.ok(app_provenance.can_access_artefact(v_sample_id), 'Operator can access sample artefact');

  v_txn := app_security.start_transaction_context(
    p_actor_id => v_self_id,
    p_actor_identity => 'ops@example.org',
    p_effective_roles => ARRAY['app_operator'],
    p_client_app => 'unit-tests'
  );

  -- Use RPC to set/clear location with operator privileges
  PERFORM app_provenance.sp_set_location(
    jsonb_build_object(
      'artefact_id', v_sample_id::text,
      'to_storage_id', v_shelf_id::text,
      'reason', 'unit-test operator',
      'event_type', 'check_in',
      'occurred_at', v_event_time::text,
      'metadata', jsonb_build_object('unit_test','operator')
    )
  );

  EXECUTE 'SET ROLE app_admin';
  EXECUTE format('SET app.roles = %L', 'app_admin');

  SELECT
    rel.metadata->>'last_event_type',
    (rel.metadata->>'last_event_at')::timestamptz
  INTO v_last_type, v_last_at
  FROM app_provenance.artefact_relationships rel
  WHERE rel.child_artefact_id = v_sample_id
    AND rel.relationship_type = 'located_in'
  ORDER BY rel.created_at DESC
  LIMIT 1;

  PERFORM pg_temp.isnt_null(v_last_type, 'sp_set_location recorded last event metadata');
  PERFORM pg_temp.is(v_last_type, 'check_in', 'sp_set_location captured last event type');
  PERFORM pg_temp.is(v_last_at::text, v_event_time::text, 'sp_set_location captured occurred_at timestamp');

  SELECT last_event_type, last_event_at
  INTO v_view_type, v_view_at
  FROM app_provenance.v_artefact_current_location
  WHERE artefact_id = v_sample_id
  LIMIT 1;

  PERFORM pg_temp.isnt_null(v_view_type, 'v_artefact_current_location exposes sample row');
  PERFORM pg_temp.is(v_view_type, 'check_in', 'v_artefact_current_location exposes last event type');
  PERFORM pg_temp.is(v_view_at::text, v_event_time::text, 'v_artefact_current_location exposes last event timestamp');

  PERFORM app_provenance.sp_set_location(
    jsonb_build_object(
      'artefact_id', v_sample_id::text,
      'expected_from_storage_id', v_shelf_id::text,
      'reason', 'unit-test checkout',
      'event_type', 'check_out',
      'occurred_at', v_checkout_time::text
    )
  );
  EXECUTE 'SET ROLE app_operator';
  EXECUTE format('SET app.roles = %L', 'app_operator');

  PERFORM app_security.finish_transaction_context(v_txn, 'rolled_back', 'unit-tests');
END;
$$;

RESET ROLE;
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
  PERFORM pg_temp.is(v_count, 1, 'External sees only own user row');

  BEGIN
    INSERT INTO app_core.users (email, full_name, default_role)
    VALUES ('external-denied@example.org', 'Should Fail', 'app_researcher');
    PERFORM pg_temp.fail('External unexpectedly inserted user');
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT LIKE '%permission denied%' AND SQLERRM NOT LIKE '%violates row-level security%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    PERFORM 1 FROM app_security.api_tokens;
    PERFORM pg_temp.fail('External unexpectedly read api_tokens');
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
  PERFORM pg_temp.is(v_count, 1, 'Automation role sees only itself');

  BEGIN
    INSERT INTO app_core.users (email, full_name, default_role)
    VALUES ('automation-denied@example.org', 'Should Fail', 'app_researcher');
    PERFORM pg_temp.fail('Automation unexpectedly inserted user');
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT LIKE '%permission denied%' AND SQLERRM NOT LIKE '%violates row-level security%' THEN
        RAISE;
      END IF;
  END;
END;
$$;
RESET ROLE;

-------------------------------------------------------------------------------
-- RLS restricts researcher to own user record
-------------------------------------------------------------------------------

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
  PERFORM pg_temp.is(v_self_count, 1, 'Researcher sees only one user row');

  SELECT count(*) INTO v_other_count FROM app_core.users WHERE email <> 'alice@example.org';
  PERFORM pg_temp.is(v_other_count, 0, 'Researcher does not see other user rows');

  BEGIN
    PERFORM 1 FROM app_security.api_tokens;
    PERFORM pg_temp.fail('Researcher unexpectedly read api_tokens');
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END;
$$;

RESET ROLE;
