-- migrate:up
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS citext;

CREATE SCHEMA IF NOT EXISTS lims AUTHORIZATION postgres;
ALTER SCHEMA lims OWNER TO postgres;

GRANT USAGE ON SCHEMA lims TO web_anon, app_auth, dev;
GRANT CREATE ON SCHEMA lims TO dev;

-------------------------------------------------------------------------------
-- Core domain tables
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lims.roles (
  role_name       text PRIMARY KEY,
  display_name    text NOT NULL,
  description     text,
  is_system_role  boolean NOT NULL DEFAULT false,
  is_assignable   boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  CHECK (role_name = lower(role_name))
);

CREATE TABLE IF NOT EXISTS lims.users (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id            text UNIQUE,
  email                  citext UNIQUE NOT NULL,
  full_name              text NOT NULL,
  default_role           text REFERENCES lims.roles(role_name),
  is_active              boolean NOT NULL DEFAULT true,
  metadata               jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  last_authenticated_at  timestamptz,
  CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE TABLE IF NOT EXISTS lims.user_roles (
  user_id     uuid NOT NULL REFERENCES lims.users(id) ON DELETE CASCADE,
  role_name   text NOT NULL REFERENCES lims.roles(role_name) ON DELETE CASCADE,
  granted_by  uuid REFERENCES lims.users(id) ON DELETE SET NULL,
  granted_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_name)
);

CREATE TABLE IF NOT EXISTS lims.samples (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id  text UNIQUE,
  name         text NOT NULL,
  sample_type  text NOT NULL,
  project_code text,
  parent_id    uuid REFERENCES lims.samples(id) ON DELETE SET NULL,
  created_by   uuid REFERENCES lims.users(id),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lims.audit_log (
  id             bigserial PRIMARY KEY,
  ts             timestamptz NOT NULL DEFAULT now(),
  actor_id       uuid,
  actor_identity text,
  actor_roles    text[] NOT NULL DEFAULT ARRAY[]::text[],
  action         text NOT NULL,
  table_name     text NOT NULL,
  row_pk         text,
  diff           jsonb
);

-------------------------------------------------------------------------------
-- Helper functions
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION lims.current_claims()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
DECLARE
  raw text;
BEGIN
  raw := current_setting('request.jwt.claims', true);
  IF raw IS NULL OR raw = '' THEN
    RETURN '{}'::jsonb;
  END IF;
  RETURN raw::jsonb;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN '{}'::jsonb;
  WHEN others THEN
    RETURN '{}'::jsonb;
END;
$$;

ALTER FUNCTION lims.current_claims() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.current_claims() TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.current_roles()
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
DECLARE
  claims jsonb := lims.current_claims();
  role_list text[] := ARRAY[]::text[];
  cfg text;
BEGIN
  IF claims ? 'roles' THEN
    role_list := ARRAY(SELECT lower(value) FROM jsonb_array_elements_text(claims->'roles') AS value);
  ELSIF claims ? 'role' THEN
    role_list := ARRAY[lower(claims->>'role')];
  END IF;

  cfg := current_setting('lims.current_roles', true);
  IF cfg IS NOT NULL AND cfg <> '' THEN
    role_list := role_list || string_to_array(lower(cfg), ',');
  END IF;

  RETURN role_list || ARRAY(
    SELECT r.rolname
    FROM pg_roles r
    WHERE pg_has_role(current_user, r.rolname, 'member')
      AND r.rolname LIKE 'app_%'
  );
END;
$$;

ALTER FUNCTION lims.current_roles() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.current_roles() TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.current_user_id()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
DECLARE
  claims jsonb := lims.current_claims();
  user_id uuid;
  cfg text;
BEGIN
  IF claims ? 'user_id' THEN
    BEGIN
      user_id := (claims ->> 'user_id')::uuid;
    EXCEPTION
      WHEN invalid_text_representation THEN
        user_id := NULL;
    END;
  END IF;

  IF user_id IS NULL AND claims ? 'sub' THEN
    SELECT u.id INTO user_id
    FROM lims.users u
    WHERE u.external_id = claims->>'sub'
    LIMIT 1;
  END IF;

  IF user_id IS NULL THEN
    cfg := current_setting('lims.current_user_id', true);
    IF cfg IS NOT NULL AND cfg <> '' THEN
      BEGIN
        user_id := cfg::uuid;
      EXCEPTION
        WHEN invalid_text_representation THEN
          user_id := NULL;
      END;
    END IF;
  END IF;

  IF user_id IS NULL THEN
    SELECT ur.user_id INTO user_id
    FROM lims.user_roles ur
    WHERE pg_has_role(current_user, ur.role_name, 'member')
    LIMIT 1;
  END IF;

  RETURN user_id;
END;
$$;

ALTER FUNCTION lims.current_user_id() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.current_user_id() TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.current_actor()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
DECLARE
  claims jsonb := lims.current_claims();
  actor text;
BEGIN
  IF claims ? 'preferred_username' THEN
    actor := claims->>'preferred_username';
  ELSIF claims ? 'email' THEN
    actor := claims->>'email';
  ELSIF claims ? 'sub' THEN
    actor := claims->>'sub';
  END IF;

  IF actor IS NULL THEN
    SELECT u.email INTO actor FROM lims.users u WHERE u.id = lims.current_user_id();
  END IF;

  RETURN COALESCE(actor, current_user);
END;
$$;

ALTER FUNCTION lims.current_actor() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.current_actor() TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.has_role(role_name text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
DECLARE
  normalized text := lower(role_name);
  role_entry text;
BEGIN
  IF role_name IS NULL OR role_name = '' THEN
    RETURN false;
  END IF;

  FOREACH role_entry IN ARRAY lims.current_roles() LOOP
    IF lower(role_entry) = normalized THEN
      RETURN true;
    END IF;
  END LOOP;

  IF lims.current_user_id() IS NOT NULL THEN
    RETURN EXISTS (
      SELECT 1
      FROM lims.user_roles ur
      WHERE ur.user_id = lims.current_user_id()
        AND lower(ur.role_name) = normalized
    );
  END IF;

  RETURN false;
END;
$$;

ALTER FUNCTION lims.has_role(text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.has_role(text) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.pre_request(jwt jsonb DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
DECLARE
  claims jsonb := COALESCE(jwt, lims.current_claims());
  roles_array text[] := ARRAY[]::text[];
  roles_csv text := '';
  user_id uuid := lims.current_user_id();
BEGIN
  IF claims ? 'roles' THEN
    roles_array := ARRAY(SELECT lower(value) FROM jsonb_array_elements_text(claims->'roles') AS value);
  ELSIF claims ? 'role' THEN
    roles_array := ARRAY[lower(claims->>'role')];
  END IF;

  IF array_length(roles_array, 1) IS NULL THEN
    roles_csv := '';
  ELSE
    roles_csv := array_to_string(roles_array, ',');
  END IF;

  IF user_id IS NOT NULL THEN
    PERFORM set_config('lims.current_user_id', user_id::text, true);
  ELSE
    PERFORM set_config('lims.current_user_id', '', true);
  END IF;

  PERFORM set_config('lims.current_roles', roles_csv, true);
END;
$$;

ALTER FUNCTION lims.pre_request(jsonb) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.pre_request(jsonb) TO postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Audit and maintenance triggers
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION lims.fn_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$$;

ALTER FUNCTION lims.fn_touch_updated_at() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.fn_touch_updated_at() TO app_admin, app_operator, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.fn_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
DECLARE
  new_doc jsonb;
  old_doc jsonb;
  pk text := NULL;
  row_diff jsonb;
  user_component text;
  role_component text;
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    new_doc := to_jsonb(NEW);
  END IF;
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    old_doc := to_jsonb(OLD);
  END IF;

  IF new_doc IS NOT NULL AND new_doc ? 'id' THEN
    pk := new_doc->>'id';
  ELSIF old_doc IS NOT NULL AND old_doc ? 'id' THEN
    pk := old_doc->>'id';
  END IF;

  IF pk IS NULL THEN
    IF new_doc IS NOT NULL AND new_doc ? 'role_name' THEN
      pk := new_doc->>'role_name';
    ELSIF old_doc IS NOT NULL AND old_doc ? 'role_name' THEN
      pk := old_doc->>'role_name';
    END IF;
  END IF;

  IF pk IS NULL THEN
    IF new_doc IS NOT NULL AND new_doc ? 'email' THEN
      pk := new_doc->>'email';
    ELSIF old_doc IS NOT NULL AND old_doc ? 'email' THEN
      pk := old_doc->>'email';
    END IF;
  END IF;

  IF pk IS NULL AND (
        (new_doc IS NOT NULL AND new_doc ? 'user_id')
        OR (old_doc IS NOT NULL AND old_doc ? 'user_id')
      ) THEN
    user_component := CASE
      WHEN new_doc IS NOT NULL AND new_doc ? 'user_id' THEN new_doc->>'user_id'
      ELSE old_doc->>'user_id'
    END;
    role_component := CASE
      WHEN new_doc IS NOT NULL AND new_doc ? 'role_name' THEN new_doc->>'role_name'
      ELSE old_doc->>'role_name'
    END;
    pk := concat_ws(':', user_component, role_component);
  END IF;

  IF TG_OP = 'INSERT' THEN
    row_diff := jsonb_build_object('new', new_doc);
  ELSIF TG_OP = 'UPDATE' THEN
    row_diff := jsonb_build_object('old', old_doc, 'new', new_doc);
  ELSE
    row_diff := jsonb_build_object('old', old_doc);
  END IF;

  INSERT INTO lims.audit_log(actor_id, actor_identity, actor_roles, action, table_name, row_pk, diff)
  VALUES (
    lims.current_user_id(),
    lims.current_actor(),
    COALESCE(lims.current_roles(), ARRAY[]::text[]),
    TG_OP,
    TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
    pk,
    row_diff
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION lims.fn_audit() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.fn_audit() TO app_admin, app_operator, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Constraints and triggers
-------------------------------------------------------------------------------

ALTER TABLE lims.roles
  ADD CONSTRAINT roles_created_by_fk
  FOREIGN KEY (created_by)
  REFERENCES lims.users(id)
  DEFERRABLE INITIALLY DEFERRED;

DROP TRIGGER IF EXISTS trg_touch_users ON lims.users;
CREATE TRIGGER trg_touch_users
BEFORE UPDATE ON lims.users
FOR EACH ROW
EXECUTE FUNCTION lims.fn_touch_updated_at();

DROP TRIGGER IF EXISTS trg_audit_roles ON lims.roles;
CREATE TRIGGER trg_audit_roles
AFTER INSERT OR UPDATE OR DELETE ON lims.roles
FOR EACH ROW
EXECUTE FUNCTION lims.fn_audit();

DROP TRIGGER IF EXISTS trg_audit_users ON lims.users;
CREATE TRIGGER trg_audit_users
AFTER INSERT OR UPDATE OR DELETE ON lims.users
FOR EACH ROW
EXECUTE FUNCTION lims.fn_audit();

DROP TRIGGER IF EXISTS trg_audit_user_roles ON lims.user_roles;
CREATE TRIGGER trg_audit_user_roles
AFTER INSERT OR UPDATE OR DELETE ON lims.user_roles
FOR EACH ROW
EXECUTE FUNCTION lims.fn_audit();

DROP TRIGGER IF EXISTS trg_audit_samples ON lims.samples;
CREATE TRIGGER trg_audit_samples
AFTER INSERT OR UPDATE OR DELETE ON lims.samples
FOR EACH ROW
EXECUTE FUNCTION lims.fn_audit();

-------------------------------------------------------------------------------
-- Row level security policies
-------------------------------------------------------------------------------

ALTER TABLE lims.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.roles FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.users FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.user_roles FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.samples ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.samples FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_roles_select_all ON lims.roles;
CREATE POLICY p_roles_select_all
ON lims.roles
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR is_assignable
);

DROP POLICY IF EXISTS p_roles_write_admin ON lims.roles;
CREATE POLICY p_roles_write_admin
ON lims.roles
FOR ALL
TO app_admin
USING (TRUE)
WITH CHECK (TRUE);

DROP POLICY IF EXISTS p_users_admin_all ON lims.users;
CREATE POLICY p_users_admin_all
ON lims.users
FOR ALL
TO app_admin
USING (TRUE)
WITH CHECK (TRUE);

DROP POLICY IF EXISTS p_users_operator_select ON lims.users;
CREATE POLICY p_users_operator_select
ON lims.users
FOR SELECT
TO app_operator
USING (TRUE);

DROP POLICY IF EXISTS p_users_self_access ON lims.users;
CREATE POLICY p_users_self_access
ON lims.users
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.current_user_id() = id
);

DROP POLICY IF EXISTS p_users_self_update ON lims.users;
CREATE POLICY p_users_self_update
ON lims.users
FOR UPDATE
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.current_user_id() = id
)
WITH CHECK (
  lims.has_role('app_admin')
  OR lims.current_user_id() = id
);

DROP POLICY IF EXISTS p_user_roles_admin_all ON lims.user_roles;
CREATE POLICY p_user_roles_admin_all
ON lims.user_roles
FOR ALL
TO app_admin
USING (TRUE)
WITH CHECK (TRUE);

DROP POLICY IF EXISTS p_user_roles_self_select ON lims.user_roles;
CREATE POLICY p_user_roles_self_select
ON lims.user_roles
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.current_user_id() = user_id
);

DROP POLICY IF EXISTS p_samples_select_all ON lims.samples;
CREATE POLICY p_samples_select_all
ON lims.samples
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_samples_insert_ops ON lims.samples;
DROP POLICY IF EXISTS p_samples_update_ops ON lims.samples;
DROP POLICY IF EXISTS p_samples_delete_ops ON lims.samples;
DROP POLICY IF EXISTS p_samples_insert_admin ON lims.samples;
DROP POLICY IF EXISTS p_samples_update_admin ON lims.samples;
DROP POLICY IF EXISTS p_samples_delete_admin ON lims.samples;
DROP POLICY IF EXISTS p_samples_insert_automation ON lims.samples;
DROP POLICY IF EXISTS p_samples_update_automation ON lims.samples;

CREATE POLICY p_samples_insert_ops
ON lims.samples
FOR INSERT
TO app_operator
WITH CHECK (TRUE);

CREATE POLICY p_samples_update_ops
ON lims.samples
FOR UPDATE
TO app_operator
USING (TRUE)
WITH CHECK (TRUE);

CREATE POLICY p_samples_delete_ops
ON lims.samples
FOR DELETE
TO app_operator
USING (TRUE);

CREATE POLICY p_samples_insert_admin
ON lims.samples
FOR INSERT
TO app_admin
WITH CHECK (TRUE);

CREATE POLICY p_samples_update_admin
ON lims.samples
FOR UPDATE
TO app_admin
USING (TRUE)
WITH CHECK (TRUE);

CREATE POLICY p_samples_delete_admin
ON lims.samples
FOR DELETE
TO app_admin
USING (TRUE);

CREATE POLICY p_samples_insert_automation
ON lims.samples
FOR INSERT
TO app_automation
WITH CHECK (TRUE);

CREATE POLICY p_samples_update_automation
ON lims.samples
FOR UPDATE
TO app_automation
USING (TRUE)
WITH CHECK (TRUE);

-------------------------------------------------------------------------------
-- Grants
-------------------------------------------------------------------------------

REVOKE ALL ON ALL TABLES IN SCHEMA lims FROM web_anon;
REVOKE ALL ON ALL TABLES IN SCHEMA lims FROM app_auth;
REVOKE ALL ON ALL TABLES IN SCHEMA lims FROM app_admin;
REVOKE ALL ON ALL TABLES IN SCHEMA lims FROM app_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA lims FROM app_researcher;
REVOKE ALL ON ALL TABLES IN SCHEMA lims FROM app_external;
REVOKE ALL ON ALL TABLES IN SCHEMA lims FROM app_automation;
REVOKE ALL ON ALL TABLES IN SCHEMA lims FROM dev;

GRANT SELECT ON lims.roles TO app_auth;
GRANT INSERT, UPDATE, DELETE ON lims.roles TO app_admin;

GRANT SELECT, UPDATE ON lims.users TO app_auth;
GRANT INSERT, DELETE ON lims.users TO app_admin;
GRANT UPDATE ON lims.users TO app_operator;

GRANT SELECT ON lims.user_roles TO app_auth;
GRANT INSERT, UPDATE, DELETE ON lims.user_roles TO app_admin;

GRANT SELECT ON lims.samples TO app_auth;
GRANT INSERT, UPDATE, DELETE ON lims.samples TO app_operator;
GRANT INSERT, UPDATE, DELETE ON lims.samples TO app_admin;
GRANT INSERT, UPDATE ON lims.samples TO app_automation;

GRANT SELECT ON lims.audit_log TO app_admin;
GRANT SELECT ON lims.audit_log TO app_operator;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA lims TO app_admin, app_operator;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA lims TO app_automation;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA lims TO dev;

-------------------------------------------------------------------------------
-- Seed data
-------------------------------------------------------------------------------

INSERT INTO lims.roles (role_name, display_name, description, is_system_role, is_assignable)
VALUES
  ('app_admin', 'Administrator', 'Full administrative control over the LIMS instance.', true, true),
  ('app_operator', 'Lab Operator', 'Manage operational data and sample lifecycle.', true, true),
  ('app_researcher', 'Researcher', 'Read access to data and ability to manage owned records.', true, true),
  ('app_external', 'External Collaborator', 'Restricted access for external stakeholders.', true, true),
  ('app_automation', 'Automation', 'Service account role for automated instruments and pipelines.', true, false)
ON CONFLICT (role_name) DO UPDATE
SET display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    is_system_role = EXCLUDED.is_system_role,
    is_assignable = EXCLUDED.is_assignable;

INSERT INTO lims.users (email, full_name, external_id, default_role, is_active)
SELECT email, full_name, external_id, default_role, is_active
FROM (
  VALUES
    ('admin@example.org', 'Admin User', 'urn:lims:user:admin', 'app_admin', true),
    ('alice@example.org', 'Alice Scientist', 'urn:lims:user:alice', 'app_researcher', true)
) AS seed(email, full_name, external_id, default_role, is_active)
ON CONFLICT (email) DO UPDATE
SET full_name = EXCLUDED.full_name,
    default_role = EXCLUDED.default_role,
    is_active = EXCLUDED.is_active;

INSERT INTO lims.user_roles (user_id, role_name, granted_by)
SELECT u.id, r.role_name, admin_user.id
FROM (
  VALUES
    ('admin@example.org', 'app_admin'),
    ('admin@example.org', 'app_operator'),
    ('alice@example.org', 'app_researcher')
) AS seed(email, role_name)
JOIN lims.users u ON u.email = seed.email
JOIN lims.users admin_user ON admin_user.email = 'admin@example.org'
JOIN lims.roles r ON r.role_name = seed.role_name
ON CONFLICT (user_id, role_name) DO NOTHING;

INSERT INTO lims.samples(name, sample_type, project_code, created_by)
SELECT seed.name, seed.sample_type, seed.project_code, seed.created_by
FROM (
  VALUES
    (
      'PBMC Batch 001',
      'cell',
      'PRJ-001',
      (SELECT id FROM lims.users WHERE email = 'alice@example.org')
    ),
    (
      'Serum Tube A',
      'fluid',
      'PRJ-002',
      (SELECT id FROM lims.users WHERE email = 'alice@example.org')
    )
) AS seed(name, sample_type, project_code, created_by)
WHERE NOT EXISTS (
  SELECT 1
  FROM lims.samples s
  WHERE s.name = seed.name
    AND COALESCE(s.project_code, '') = COALESCE(seed.project_code, '')
);

-- migrate:down
DELETE FROM lims.samples WHERE name IN ('PBMC Batch 001', 'Serum Tube A');
DELETE FROM lims.user_roles WHERE role_name IN ('app_admin', 'app_operator', 'app_researcher');
DELETE FROM lims.users WHERE email IN ('admin@example.org', 'alice@example.org');
DELETE FROM lims.roles WHERE role_name IN ('app_admin', 'app_operator', 'app_researcher', 'app_external', 'app_automation');

REVOKE SELECT ON lims.audit_log FROM app_operator;
REVOKE SELECT ON lims.audit_log FROM app_admin;

REVOKE INSERT, UPDATE ON lims.samples FROM app_automation;
REVOKE INSERT, UPDATE, DELETE ON lims.samples FROM app_admin;
REVOKE INSERT, UPDATE, DELETE ON lims.samples FROM app_operator;
REVOKE SELECT ON lims.samples FROM app_auth;

REVOKE INSERT, UPDATE, DELETE ON lims.user_roles FROM app_admin;
REVOKE SELECT ON lims.user_roles FROM app_auth;

REVOKE INSERT, DELETE ON lims.users FROM app_admin;
REVOKE UPDATE ON lims.users FROM app_operator;
REVOKE SELECT, UPDATE ON lims.users FROM app_auth;

REVOKE INSERT, UPDATE, DELETE ON lims.roles FROM app_admin;
REVOKE SELECT ON lims.roles FROM app_auth;

REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA lims FROM app_admin, app_operator, app_automation, dev;

DROP POLICY IF EXISTS p_samples_update_automation ON lims.samples;
DROP POLICY IF EXISTS p_samples_insert_automation ON lims.samples;
DROP POLICY IF EXISTS p_samples_delete_admin ON lims.samples;
DROP POLICY IF EXISTS p_samples_update_admin ON lims.samples;
DROP POLICY IF EXISTS p_samples_insert_admin ON lims.samples;
DROP POLICY IF EXISTS p_samples_delete_ops ON lims.samples;
DROP POLICY IF EXISTS p_samples_update_ops ON lims.samples;
DROP POLICY IF EXISTS p_samples_insert_ops ON lims.samples;
DROP POLICY IF EXISTS p_samples_select_all ON lims.samples;
DROP POLICY IF EXISTS p_user_roles_self_select ON lims.user_roles;
DROP POLICY IF EXISTS p_user_roles_admin_all ON lims.user_roles;
DROP POLICY IF EXISTS p_users_self_update ON lims.users;
DROP POLICY IF EXISTS p_users_self_access ON lims.users;
DROP POLICY IF EXISTS p_users_operator_select ON lims.users;
DROP POLICY IF EXISTS p_users_admin_all ON lims.users;
DROP POLICY IF EXISTS p_roles_write_admin ON lims.roles;
DROP POLICY IF EXISTS p_roles_select_all ON lims.roles;

ALTER TABLE lims.samples DISABLE ROW LEVEL SECURITY;
ALTER TABLE lims.user_roles DISABLE ROW LEVEL SECURITY;
ALTER TABLE lims.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE lims.roles DISABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_audit_samples ON lims.samples;
DROP TRIGGER IF EXISTS trg_audit_user_roles ON lims.user_roles;
DROP TRIGGER IF EXISTS trg_audit_users ON lims.users;
DROP TRIGGER IF EXISTS trg_audit_roles ON lims.roles;
DROP TRIGGER IF EXISTS trg_touch_users ON lims.users;

DROP FUNCTION IF EXISTS lims.fn_audit();
DROP FUNCTION IF EXISTS lims.fn_touch_updated_at();
DROP FUNCTION IF EXISTS lims.pre_request(jsonb);
DROP FUNCTION IF EXISTS lims.has_role(text);
DROP FUNCTION IF EXISTS lims.current_actor();
DROP FUNCTION IF EXISTS lims.current_user_id();
DROP FUNCTION IF EXISTS lims.current_roles();
DROP FUNCTION IF EXISTS lims.current_claims();

DROP TABLE IF EXISTS lims.audit_log;
DROP TABLE IF EXISTS lims.samples;
DROP TABLE IF EXISTS lims.user_roles;
DROP TABLE IF EXISTS lims.users;
DROP TABLE IF EXISTS lims.roles;

REVOKE CREATE ON SCHEMA lims FROM dev;
REVOKE USAGE ON SCHEMA lims FROM dev;
REVOKE USAGE ON SCHEMA lims FROM app_auth;
REVOKE USAGE ON SCHEMA lims FROM web_anon;

DROP SCHEMA IF EXISTS lims CASCADE;

DROP EXTENSION IF EXISTS citext;
