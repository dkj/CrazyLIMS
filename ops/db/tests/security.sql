\set ON_ERROR_STOP on
SET client_min_messages TO WARNING;

-- Ensure tables exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'lims' AND table_name = 'api_clients') THEN
    RAISE EXCEPTION 'lims.api_clients table missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'lims' AND table_name = 'api_tokens') THEN
    RAISE EXCEPTION 'lims.api_tokens table missing';
  END IF;
END;
$$;

-- Create an API client and token as admin
SET ROLE app_admin;

DO $$
DECLARE
  admin_id uuid;
  client_id uuid;
  token_id uuid;
  digest text;
  hint text;
BEGIN
  SELECT id INTO admin_id FROM lims.users WHERE email = 'admin@example.org';

  INSERT INTO lims.api_clients (client_identifier, display_name, description, created_by)
  VALUES ('test-client', 'Test Client', 'Created by automated test', admin_id)
  ON CONFLICT (client_identifier) DO UPDATE
    SET description = EXCLUDED.description
  RETURNING id INTO client_id;

  token_id := lims.create_api_token(client_id, repeat('a', 32) || 'XYZ123', now() + interval '1 day');
  SELECT token_digest, token_hint INTO digest, hint FROM lims.api_tokens WHERE id = token_id;

  IF digest IS NULL OR length(digest) <> 64 THEN
    RAISE EXCEPTION 'Token digest not stored correctly';
  END IF;

  IF hint IS DISTINCT FROM 'XYZ123' THEN
    RAISE EXCEPTION 'Token hint was not derived correctly';
  END IF;
END;
$$;

RESET ROLE;

SET ROLE app_admin;
SELECT set_config('session.researcher_id', (SELECT id::text FROM lims.users WHERE email = 'alice@example.org'), false);
RESET ROLE;

-- Researcher should only see their own record via RLS (simulating PostgREST session)
SET ROLE app_auth;
SELECT set_config('role', 'app_researcher', false);
SELECT set_config('lims.current_roles', 'app_researcher', false);
SELECT set_config('lims.current_user_id', current_setting('session.researcher_id', true), false);

DO $$
DECLARE
  total_users integer;
  others integer;
BEGIN
  SELECT count(*) INTO total_users FROM lims.users;
  IF total_users <> 1 THEN
    RAISE EXCEPTION 'Researcher should only see their own user record';
  END IF;

  SELECT count(*) INTO others FROM lims.users WHERE email <> 'alice@example.org';
  IF others <> 0 THEN
    RAISE EXCEPTION 'Researcher was able to see other user records';
  END IF;

  BEGIN
    PERFORM 1 FROM lims.api_tokens;
    RAISE EXCEPTION 'Researcher should not read api_tokens';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END;
$$;

RESET ROLE;

-- Clean up
SET ROLE app_admin;
DELETE FROM lims.api_tokens WHERE api_client_id IN (SELECT id FROM lims.api_clients WHERE client_identifier = 'test-client');
DELETE FROM lims.api_clients WHERE client_identifier = 'test-client';
RESET ROLE;
