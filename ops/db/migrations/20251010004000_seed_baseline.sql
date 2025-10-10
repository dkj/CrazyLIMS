-- migrate:up
DO $$
DECLARE
  v_txn uuid;
  v_admin_id uuid;
  v_operator_id uuid;
  v_researcher_id uuid;
BEGIN
  v_txn := app_security.start_transaction_context(
    p_actor_identity => 'migration/bootstrap',
    p_effective_roles => ARRAY['app_admin'],
    p_client_app => 'dbmate:migration',
    p_metadata => jsonb_build_object('seed', 'phase1-redux')
  );

  INSERT INTO app_core.roles (role_name, display_name, description, is_system_role, created_by)
  VALUES
    ('app_admin', 'Administrator', 'Full platform administrator', true, NULL),
    ('app_operator', 'Operator', 'Operations staff with elevated privileges', true, NULL),
    ('app_researcher', 'Researcher', 'Standard researcher persona', true, NULL),
    ('app_external', 'External Collaborator', 'External collaborators with curated access', true, NULL),
    ('app_automation', 'Automation', 'Machine and workflow automation persona', true, NULL)
  ON CONFLICT (role_name) DO NOTHING;

  INSERT INTO app_core.users (external_id, email, full_name, default_role, is_service_account, metadata)
  VALUES
    ('urn:app:admin', 'admin@example.org', 'System Administrator', 'app_admin', false, jsonb_build_object('seed', true)),
    ('urn:app:ops', 'ops@example.org', 'Operations Lead', 'app_operator', false, jsonb_build_object('seed', true)),
    ('urn:app:alice', 'alice@example.org', 'Alice Researcher', 'app_researcher', false, jsonb_build_object('seed', true))
  ON CONFLICT (email) DO UPDATE
    SET full_name = EXCLUDED.full_name;

  SELECT id INTO v_admin_id FROM app_core.users WHERE email = 'admin@example.org';
  SELECT id INTO v_operator_id FROM app_core.users WHERE email = 'ops@example.org';
  SELECT id INTO v_researcher_id FROM app_core.users WHERE email = 'alice@example.org';

  IF v_admin_id IS NOT NULL THEN
    PERFORM set_config('app.actor_id', v_admin_id::text, true);
    PERFORM set_config('app.actor_identity', 'seed:admin', true);
    UPDATE app_security.transaction_contexts
    SET actor_id = v_admin_id,
        actor_identity = 'seed:admin'
    WHERE txn_id = v_txn;
  END IF;

  INSERT INTO app_core.user_roles (user_id, role_name, granted_by)
  VALUES
    (v_admin_id, 'app_admin', v_admin_id),
    (v_operator_id, 'app_operator', v_admin_id),
    (v_researcher_id, 'app_researcher', v_admin_id)
  ON CONFLICT (user_id, role_name) DO NOTHING;

  INSERT INTO app_security.api_clients (client_identifier, display_name, description, contact_email, allowed_roles, metadata, created_by)
  VALUES
    ('cli:automation', 'Automation Service', 'Seed automation client', 'ops@example.org', ARRAY['app_automation'], jsonb_build_object('seed', true), v_admin_id)
  ON CONFLICT (client_identifier) DO UPDATE
    SET allowed_roles = EXCLUDED.allowed_roles;

  PERFORM app_security.create_api_token(
    p_user_id => v_operator_id,
    p_plaintext_token => repeat('x', 32) || 'seed-op',
    p_allowed_roles => ARRAY['app_operator'],
    p_expires_at => clock_timestamp() + interval '30 days',
    p_metadata => jsonb_build_object('seed', true),
    p_client_identifier => 'cli:automation'
  );

  PERFORM app_security.finish_transaction_context(v_txn, 'committed', 'baseline seed');
END;
$$;

-- migrate:down
DELETE FROM app_security.api_tokens WHERE metadata ->> 'seed' = 'true';
DELETE FROM app_security.api_clients WHERE metadata ->> 'seed' = 'true';
DELETE FROM app_core.user_roles WHERE user_id IN (
  SELECT id FROM app_core.users WHERE metadata ->> 'seed' = 'true'
);
DELETE FROM app_core.users WHERE metadata ->> 'seed' = 'true';
DELETE FROM app_core.roles WHERE role_name IN ('app_admin','app_operator','app_researcher','app_external','app_automation');
