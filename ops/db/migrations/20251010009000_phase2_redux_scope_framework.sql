-- migrate:up
CREATE TABLE app_security.scopes (
  scope_id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope_key          text NOT NULL UNIQUE CHECK (scope_key = lower(scope_key)),
  scope_type         text NOT NULL CHECK (scope_type = lower(scope_type)),
  display_name       text NOT NULL,
  description        text,
  parent_scope_id    uuid REFERENCES app_security.scopes(scope_id) ON DELETE CASCADE,
  metadata           jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  is_active          boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by         uuid REFERENCES app_core.users(id),
  updated_at         timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_by         uuid REFERENCES app_core.users(id),
  UNIQUE (parent_scope_id, display_name),
  CHECK (parent_scope_id IS NULL OR parent_scope_id <> scope_id)
);

CREATE INDEX idx_scopes_parent ON app_security.scopes(parent_scope_id);
CREATE INDEX idx_scopes_type ON app_security.scopes(scope_type);

CREATE TABLE app_security.scope_memberships (
  scope_membership_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope_id            uuid NOT NULL REFERENCES app_security.scopes(scope_id) ON DELETE CASCADE,
  user_id             uuid NOT NULL REFERENCES app_core.users(id) ON DELETE CASCADE,
  role_name           text NOT NULL REFERENCES app_core.roles(role_name),
  granted_by          uuid REFERENCES app_core.users(id),
  granted_at          timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at          timestamptz,
  is_active           boolean NOT NULL DEFAULT true,
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  UNIQUE (scope_id, user_id, role_name)
);

CREATE INDEX idx_scope_memberships_user ON app_security.scope_memberships(user_id);
CREATE INDEX idx_scope_memberships_scope ON app_security.scope_memberships(scope_id);

CREATE TABLE app_security.scope_role_inheritance (
  parent_scope_type text NOT NULL,
  child_scope_type  text NOT NULL,
  parent_role_name  text NOT NULL REFERENCES app_core.roles(role_name),
  child_role_name   text NOT NULL REFERENCES app_core.roles(role_name),
  is_active         boolean NOT NULL DEFAULT true,
  PRIMARY KEY (parent_scope_type, child_scope_type, parent_role_name, child_role_name),
  CHECK (parent_scope_type = lower(parent_scope_type)),
  CHECK (child_scope_type = lower(child_scope_type))
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app_security.scopes TO app_admin;
GRANT SELECT ON app_security.scopes TO app_operator;

GRANT SELECT, INSERT, UPDATE, DELETE ON app_security.scope_memberships TO app_admin;
GRANT SELECT ON app_security.scope_memberships TO app_operator;

GRANT SELECT, INSERT, UPDATE, DELETE ON app_security.scope_role_inheritance TO app_admin;

ALTER TABLE app_security.scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.scopes FORCE ROW LEVEL SECURITY;

ALTER TABLE app_security.scope_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.scope_memberships FORCE ROW LEVEL SECURITY;

ALTER TABLE app_security.scope_role_inheritance ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.scope_role_inheritance FORCE ROW LEVEL SECURITY;

CREATE POLICY scopes_admin_manage ON app_security.scopes
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

CREATE POLICY scopes_operator_read ON app_security.scopes
  FOR SELECT
  TO app_operator
  USING (app_security.has_role('app_operator'));

CREATE POLICY scope_memberships_admin_manage ON app_security.scope_memberships
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

CREATE POLICY scope_memberships_operator_read ON app_security.scope_memberships
  FOR SELECT
  TO app_operator
  USING (app_security.has_role('app_operator'));

CREATE POLICY scope_role_inheritance_admin_manage ON app_security.scope_role_inheritance
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

-------------------------------------------------------------------------------
-- Helper functions for scope resolution
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_security.actor_scope_roles(p_actor_id uuid DEFAULT NULL)
RETURNS TABLE (
  scope_id uuid,
  role_name text,
  source_scope_id uuid,
  source_role_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  v_actor uuid := COALESCE(p_actor_id, app_security.current_actor_id());
BEGIN
  IF v_actor IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH RECURSIVE scope_tree AS (
    SELECT
      sm.scope_id,
      sm.role_name,
      sm.scope_id AS source_scope_id,
      sm.role_name AS source_role_name,
      s.scope_type,
      s.parent_scope_id
    FROM app_security.scope_memberships sm
    JOIN app_security.scopes s
      ON s.scope_id = sm.scope_id
    WHERE sm.user_id = v_actor
      AND sm.is_active
      AND (sm.expires_at IS NULL OR sm.expires_at > clock_timestamp())
      AND s.is_active

    UNION ALL

    SELECT
      child.scope_id,
      COALESCE(inherit.child_role_name, st.role_name) AS role_name,
      st.source_scope_id,
      st.source_role_name,
      child.scope_type,
      child.parent_scope_id
    FROM scope_tree st
    JOIN app_security.scopes child
      ON child.parent_scope_id = st.scope_id
     AND child.is_active
    LEFT JOIN LATERAL (
      SELECT sri.child_role_name
      FROM app_security.scope_role_inheritance sri
      WHERE sri.parent_scope_type = st.scope_type
        AND sri.child_scope_type = child.scope_type
        AND sri.parent_role_name = st.role_name
        AND sri.is_active
    ) AS inherit ON TRUE
  )
  SELECT DISTINCT scope_id, role_name, source_scope_id, source_role_name
  FROM scope_tree;
END;
$$;

GRANT EXECUTE ON FUNCTION app_security.actor_scope_roles(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_security.actor_has_scope(
  p_scope_id uuid,
  p_required_roles text[] DEFAULT NULL,
  p_actor_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  v_actor uuid := COALESCE(p_actor_id, app_security.current_actor_id());
  v_required text[] := app_security.coerce_roles(p_required_roles);
  v_needed boolean := array_length(v_required, 1) IS NOT NULL;
BEGIN
  IF p_scope_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_security.has_role('app_admin') THEN
    RETURN true;
  END IF;

  IF v_actor IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM app_security.actor_scope_roles(v_actor) AS sr
    WHERE sr.scope_id = p_scope_id
      AND (
        NOT v_needed
        OR sr.role_name = ANY(v_required)
      )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_security.actor_has_scope(uuid, text[], uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-- migrate:down
REVOKE EXECUTE ON FUNCTION app_security.actor_has_scope(uuid, text[], uuid) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_security.actor_scope_roles(uuid) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;

DROP FUNCTION IF EXISTS app_security.actor_has_scope(uuid, text[], uuid);
DROP FUNCTION IF EXISTS app_security.actor_scope_roles(uuid);

DROP POLICY IF EXISTS scope_role_inheritance_admin_manage ON app_security.scope_role_inheritance;
DROP POLICY IF EXISTS scope_memberships_operator_read ON app_security.scope_memberships;
DROP POLICY IF EXISTS scope_memberships_admin_manage ON app_security.scope_memberships;
DROP POLICY IF EXISTS scopes_operator_read ON app_security.scopes;
DROP POLICY IF EXISTS scopes_admin_manage ON app_security.scopes;

ALTER TABLE app_security.scope_role_inheritance DISABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.scope_memberships DISABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.scopes DISABLE ROW LEVEL SECURITY;

REVOKE SELECT, INSERT, UPDATE, DELETE ON app_security.scope_role_inheritance FROM app_admin;
REVOKE SELECT ON app_security.scope_memberships FROM app_operator;
REVOKE SELECT, INSERT, UPDATE, DELETE ON app_security.scope_memberships FROM app_admin;
REVOKE SELECT ON app_security.scopes FROM app_operator;
REVOKE SELECT, INSERT, UPDATE, DELETE ON app_security.scopes FROM app_admin;

DROP TABLE IF EXISTS app_security.scope_role_inheritance;
DROP TABLE IF EXISTS app_security.scope_memberships;
DROP TABLE IF EXISTS app_security.scopes;
