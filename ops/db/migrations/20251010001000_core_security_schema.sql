-- migrate:up
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS citext;

CREATE SCHEMA IF NOT EXISTS app_core AUTHORIZATION postgres;
CREATE SCHEMA IF NOT EXISTS app_security AUTHORIZATION postgres;

GRANT USAGE ON SCHEMA app_core TO app_auth, dev, postgrest_authenticator, postgraphile_authenticator;
GRANT USAGE ON SCHEMA app_security TO app_auth, dev, postgrest_authenticator, postgraphile_authenticator;
GRANT CREATE ON SCHEMA app_core TO dev;
GRANT CREATE ON SCHEMA app_security TO dev;

-------------------------------------------------------------------------------
-- Core reference tables
-------------------------------------------------------------------------------

CREATE TABLE app_core.roles (
  role_name      text PRIMARY KEY,
  display_name   text NOT NULL,
  description    text,
  is_system_role boolean NOT NULL DEFAULT false,
  is_assignable  boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by     uuid,
  CHECK (role_name = lower(role_name))
);

CREATE TABLE app_core.users (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id            text UNIQUE,
  email                  citext UNIQUE NOT NULL,
  full_name              text NOT NULL,
  default_role           text REFERENCES app_core.roles(role_name),
  is_service_account     boolean NOT NULL DEFAULT false,
  is_active              boolean NOT NULL DEFAULT true,
  metadata               jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at             timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at             timestamptz NOT NULL DEFAULT clock_timestamp(),
  last_authenticated_at  timestamptz,
  created_by             uuid,
  updated_by             uuid,
  CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE TABLE app_core.user_roles (
  user_id     uuid NOT NULL REFERENCES app_core.users(id) ON DELETE CASCADE,
  role_name   text NOT NULL REFERENCES app_core.roles(role_name) ON DELETE CASCADE,
  granted_by  uuid REFERENCES app_core.users(id) ON DELETE SET NULL,
  granted_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (user_id, role_name)
);

-------------------------------------------------------------------------------
-- Security integration tables
-------------------------------------------------------------------------------

CREATE TABLE app_security.api_clients (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_identifier text UNIQUE NOT NULL,
  display_name    text NOT NULL,
  description     text,
  contact_email   citext,
  allowed_roles   text[] NOT NULL DEFAULT ARRAY[]::text[],
  metadata        jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by      uuid REFERENCES app_core.users(id),
  updated_by      uuid REFERENCES app_core.users(id),
  CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE TABLE app_security.api_tokens (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  api_client_id   uuid NOT NULL REFERENCES app_security.api_clients(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES app_core.users(id) ON DELETE CASCADE,
  token_digest    text NOT NULL,
  token_hint      text NOT NULL,
  allowed_roles   text[] NOT NULL DEFAULT ARRAY[]::text[],
  expires_at      timestamptz,
  revoked_at      timestamptz,
  revoked_by      uuid REFERENCES app_core.users(id),
  metadata        jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by      uuid REFERENCES app_core.users(id),
  CHECK (char_length(token_digest) = 64),
  CHECK (jsonb_typeof(metadata) = 'object')
);

-------------------------------------------------------------------------------
-- Helper functions for session and claims handling
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_security.current_claims()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  raw text;
BEGIN
  raw := current_setting('request.jwt.claims', true);
  IF raw IS NULL OR raw = '' THEN
    RETURN '{}'::jsonb;
  END IF;
  BEGIN
    RETURN raw::jsonb;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN '{}'::jsonb;
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION app_security.current_claims() TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_security.lookup_user_id(p_claims jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  candidate uuid;
BEGIN
  IF p_claims ? 'user_id' THEN
    BEGIN
      candidate := (p_claims ->> 'user_id')::uuid;
      IF EXISTS (SELECT 1 FROM app_core.users u WHERE u.id = candidate) THEN
        RETURN candidate;
      END IF;
    EXCEPTION
      WHEN invalid_text_representation THEN NULL;
    END;
  END IF;

  IF p_claims ? 'sub' THEN
    SELECT u.id INTO candidate
    FROM app_core.users u
    WHERE u.external_id = p_claims->>'sub'
    LIMIT 1;
    IF candidate IS NOT NULL THEN
      RETURN candidate;
    END IF;
  END IF;

  IF p_claims ? 'email' THEN
    SELECT u.id INTO candidate
    FROM app_core.users u
    WHERE lower(u.email::text) = lower(p_claims->>'email')
    LIMIT 1;
    IF candidate IS NOT NULL THEN
      RETURN candidate;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION app_security.lookup_user_id(jsonb) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_security.current_roles()
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  claims jsonb := app_security.current_claims();
  collected text[] := ARRAY[]::text[];
  cfg text;
  membership text[];
  active_role text;
BEGIN
  IF claims ? 'roles' THEN
    collected := collected || ARRAY(
      SELECT lower(value)
      FROM jsonb_array_elements_text(claims->'roles') AS value
    );
  END IF;
  IF claims ? 'role' THEN
    collected := array_append(collected, lower(claims->>'role'));
  END IF;

  cfg := current_setting('app.roles', true);
  IF cfg IS NOT NULL AND cfg <> '' THEN
    collected := collected || string_to_array(lower(cfg), ',');
  END IF;

  BEGIN
    active_role := current_setting('role', true);
  EXCEPTION
    WHEN undefined_object THEN
      active_role := NULL;
  END;

  IF active_role IS NULL OR active_role = '' OR lower(active_role) = 'none' THEN
    active_role := lower(current_user::text);
  END IF;

  membership := ARRAY(
    SELECT DISTINCT lower(r.rolname)
    FROM pg_roles r
    WHERE pg_has_role(active_role, r.rolname, 'member')
      AND r.rolname LIKE 'app_%'
  );

  collected := collected || membership;

  collected := ARRAY(SELECT DISTINCT trim(both FROM r) FROM unnest(collected) AS r WHERE r IS NOT NULL AND r <> '');
  RETURN collected;
END;
$$;

GRANT EXECUTE ON FUNCTION app_security.current_roles() TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_security.has_role(p_role text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT lower(p_role) = ANY(app_security.current_roles());
$$;

GRANT EXECUTE ON FUNCTION app_security.has_role(text) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_security.current_actor_id()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  cfg text;
  claims jsonb;
  resolved uuid;
BEGIN
  cfg := current_setting('app.actor_id', true);
  IF cfg IS NOT NULL AND cfg <> '' THEN
    BEGIN
      resolved := cfg::uuid;
      RETURN resolved;
    EXCEPTION WHEN invalid_text_representation THEN
      NULL;
    END;
  END IF;

  claims := app_security.current_claims();
  RETURN app_security.lookup_user_id(claims);
END;
$$;

GRANT EXECUTE ON FUNCTION app_security.current_actor_id() TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_security.pre_request()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  claims jsonb := app_security.current_claims();
  actor uuid;
  roles text[];
  actor_identifier text;
BEGIN
  actor := app_security.lookup_user_id(claims);

  IF claims ? 'roles' THEN
    roles := ARRAY(
      SELECT DISTINCT lower(value)
      FROM jsonb_array_elements_text(claims->'roles') AS value
      WHERE value IS NOT NULL
    );
  ELSE
    roles := ARRAY[]::text[];
  END IF;

  IF claims ? 'role' THEN
    roles := array_append(roles, lower(claims->>'role'));
  END IF;

  roles := ARRAY(SELECT DISTINCT r FROM unnest(roles) AS r WHERE r IS NOT NULL AND r <> '');

  IF claims ? 'sub' THEN
    actor_identifier := claims->>'sub';
  ELSIF claims ? 'email' THEN
    actor_identifier := lower(claims->>'email');
  END IF;

  PERFORM set_config('app.jwt_claims', claims::text, true);
  IF actor IS NOT NULL THEN
    PERFORM set_config('app.actor_id', actor::text, true);
  ELSE
    PERFORM set_config('app.actor_id', '', true);
  END IF;
  PERFORM set_config('app.actor_identity', coalesce(actor_identifier, ''), true);
  PERFORM set_config('app.roles', array_to_string(roles, ','), true);
END;
$$;

GRANT EXECUTE ON FUNCTION app_security.pre_request() TO postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- API token helper
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_security.create_api_token(
  p_user_id uuid,
  p_plaintext_token text,
  p_allowed_roles text[],
  p_expires_at timestamptz DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_client_identifier text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  digest text;
  hint text;
  v_client_id uuid;
  v_token_id uuid;
  v_allowed_roles text[];
  creator uuid := app_security.current_actor_id();
BEGIN
  IF p_plaintext_token IS NULL OR length(p_plaintext_token) < 32 THEN
    RAISE EXCEPTION 'API token must be at least 32 characters';
  END IF;

  digest := encode(digest(p_plaintext_token, 'sha256'), 'hex');
  hint := right(p_plaintext_token, 6);

  IF p_client_identifier IS NOT NULL THEN
    SELECT c.id INTO v_client_id
    FROM app_security.api_clients c
    WHERE c.client_identifier = p_client_identifier
    LIMIT 1;
    IF v_client_id IS NULL THEN
      RAISE EXCEPTION 'Unknown API client identifier %', p_client_identifier;
    END IF;
  END IF;

  v_allowed_roles := ARRAY(
    SELECT DISTINCT trim(both FROM lower(role_value))
    FROM unnest(coalesce(p_allowed_roles, ARRAY[]::text[])) AS role_value
    WHERE role_value IS NOT NULL AND trim(both FROM role_value) <> ''
  );
  v_allowed_roles := coalesce(v_allowed_roles, ARRAY[]::text[]);

  INSERT INTO app_security.api_tokens (
    api_client_id,
    user_id,
    token_digest,
    token_hint,
    allowed_roles,
    expires_at,
    metadata,
    created_by
  )
  VALUES (
    v_client_id,
    p_user_id,
    digest,
    hint,
    v_allowed_roles,
    p_expires_at,
    coalesce(p_metadata, '{}'::jsonb),
    creator
  )
  RETURNING id INTO v_token_id;

  RETURN v_token_id;
END;
$$;

GRANT EXECUTE ON FUNCTION app_security.create_api_token(uuid, text, text[], timestamptz, jsonb, text) TO app_admin;

-------------------------------------------------------------------------------
-- Triggers for bookkeeping
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_security.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_touch_api_clients
BEFORE UPDATE ON app_security.api_clients
FOR EACH ROW
EXECUTE FUNCTION app_security.touch_updated_at();

CREATE TRIGGER trg_touch_users
BEFORE UPDATE ON app_core.users
FOR EACH ROW
EXECUTE FUNCTION app_security.touch_updated_at();

-------------------------------------------------------------------------------
-- Grants & RLS
-------------------------------------------------------------------------------

GRANT SELECT ON app_core.roles TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_core.roles TO app_admin;
GRANT SELECT, INSERT, UPDATE ON app_core.users TO app_auth;
GRANT DELETE ON app_core.users TO app_admin;
GRANT SELECT ON app_core.user_roles TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_core.user_roles TO app_admin;
GRANT SELECT ON app_security.api_clients TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_security.api_clients TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON app_security.api_tokens TO app_admin;

ALTER TABLE app_core.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.api_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.api_tokens ENABLE ROW LEVEL SECURITY;

ALTER TABLE app_core.roles FORCE ROW LEVEL SECURITY;
ALTER TABLE app_core.users FORCE ROW LEVEL SECURITY;
ALTER TABLE app_core.user_roles FORCE ROW LEVEL SECURITY;
ALTER TABLE app_security.api_clients FORCE ROW LEVEL SECURITY;
ALTER TABLE app_security.api_tokens FORCE ROW LEVEL SECURITY;

CREATE POLICY roles_read_any ON app_core.roles
  FOR SELECT
  USING (true);

CREATE POLICY roles_admin_manage ON app_core.roles
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

CREATE POLICY users_self_or_admin_read ON app_core.users
  FOR SELECT
  USING (
    app_security.has_role('app_admin') OR id = app_security.current_actor_id()
  );

CREATE POLICY users_admin_manage ON app_core.users
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

CREATE POLICY user_roles_admin_manage ON app_core.user_roles
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

CREATE POLICY api_clients_admin_manage ON app_security.api_clients
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

CREATE POLICY api_tokens_admin_manage ON app_security.api_tokens
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

-- migrate:down
DROP POLICY IF EXISTS api_tokens_admin_manage ON app_security.api_tokens;
DROP POLICY IF EXISTS api_clients_admin_manage ON app_security.api_clients;
DROP POLICY IF EXISTS user_roles_admin_manage ON app_core.user_roles;
DROP POLICY IF EXISTS users_admin_manage ON app_core.users;
DROP POLICY IF EXISTS users_self_or_admin_read ON app_core.users;
DROP POLICY IF EXISTS roles_admin_manage ON app_core.roles;
DROP POLICY IF EXISTS roles_read_any ON app_core.roles;

ALTER TABLE app_security.api_tokens DISABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.api_clients DISABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.user_roles DISABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.roles DISABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_touch_users ON app_core.users;
DROP TRIGGER IF EXISTS trg_touch_api_clients ON app_security.api_clients;
DROP FUNCTION IF EXISTS app_security.touch_updated_at();

REVOKE EXECUTE ON FUNCTION app_security.create_api_token(uuid, text, text[], timestamptz, jsonb, text) FROM app_admin;
DROP FUNCTION IF EXISTS app_security.create_api_token(uuid, text, text[], timestamptz, jsonb, text);

REVOKE EXECUTE ON FUNCTION app_security.pre_request() FROM postgrest_authenticator, postgraphile_authenticator;
DROP FUNCTION IF EXISTS app_security.pre_request();
REVOKE EXECUTE ON FUNCTION app_security.current_actor_id() FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
DROP FUNCTION IF EXISTS app_security.current_actor_id();
REVOKE EXECUTE ON FUNCTION app_security.has_role(text) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
DROP FUNCTION IF EXISTS app_security.has_role(text);
REVOKE EXECUTE ON FUNCTION app_security.current_roles() FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
DROP FUNCTION IF EXISTS app_security.current_roles();
REVOKE EXECUTE ON FUNCTION app_security.lookup_user_id(jsonb) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
DROP FUNCTION IF EXISTS app_security.lookup_user_id(jsonb);
REVOKE EXECUTE ON FUNCTION app_security.current_claims() FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
DROP FUNCTION IF EXISTS app_security.current_claims();

DROP TABLE IF EXISTS app_security.api_tokens;
DROP TABLE IF EXISTS app_security.api_clients;
DROP TABLE IF EXISTS app_core.user_roles;
DROP TABLE IF EXISTS app_core.users;
DROP TABLE IF EXISTS app_core.roles;

REVOKE USAGE ON SCHEMA app_security FROM app_auth, dev, postgrest_authenticator, postgraphile_authenticator;
REVOKE USAGE ON SCHEMA app_core FROM app_auth, dev, postgrest_authenticator, postgraphile_authenticator;
REVOKE CREATE ON SCHEMA app_security FROM dev;
REVOKE CREATE ON SCHEMA app_core FROM dev;

DROP SCHEMA IF EXISTS app_security;
DROP SCHEMA IF EXISTS app_core;

DROP EXTENSION IF EXISTS citext;
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP EXTENSION IF EXISTS pgcrypto;
