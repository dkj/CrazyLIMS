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
  v_external uuid;
  v_automation uuid;
BEGIN
  SELECT id INTO v_operator FROM app_core.users WHERE email = 'ops@example.org';
  PERFORM set_config('session.operator_id', v_operator::text, false);

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

RESET ROLE;

-------------------------------------------------------------------------------
-- RLS behaviour for operator persona
-------------------------------------------------------------------------------

SET ROLE app_operator;

DO $$
DECLARE
  v_self_id uuid := current_setting('session.operator_id', false)::uuid;
  v_count integer;
BEGIN
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
SELECT set_config('session.alice_id', (SELECT id::text FROM app_core.users WHERE email = 'alice@example.org'), false);
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
