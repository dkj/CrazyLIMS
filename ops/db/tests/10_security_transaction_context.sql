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
  PERFORM pg_temp.ok(coalesce(v_txn, '') <> '', 'Admin writes auto-initialise transaction context');

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

  PERFORM pg_temp.is(v_audit_count, 3, 'Audit log captures insert/update/delete activity');

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
  PERFORM pg_temp.isnt_null(v_operator, 'Operator fixture user present');

  SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';
  IF v_researcher IS NOT NULL THEN
    PERFORM set_config('session.researcher_id', v_researcher::text, false);
    PERFORM pg_temp.isnt_null(v_researcher, 'Researcher fixture user present');
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
  PERFORM pg_temp.isnt_null(v_external, 'External collaborator fixture present');

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
  PERFORM pg_temp.isnt_null(v_automation, 'Automation service account fixture present');
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

  PERFORM pg_temp.is(v_status, 'committed', 'Latest transaction context marked committed');
  PERFORM pg_temp.isnt_null(v_finished_at, 'Transaction context finished_at populated');
END;
$$;

-- Ensure transaction context must be active to finish
SELECT pg_temp.throws_like(
  $$SELECT app_security.finish_transaction_context(NULL, 'committed', 'should fail');$$,
  '%No transaction context active%',
  'finish_transaction_context requires an active transaction context'
);

RESET ROLE;
