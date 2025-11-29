-- migrate:up
CREATE OR REPLACE VIEW app_core.v_notebook_entry_overview AS
SELECT *
FROM app_eln.v_notebook_entry_overview;

GRANT SELECT ON app_core.v_notebook_entry_overview TO app_auth;

CREATE OR REPLACE FUNCTION app_core.actor_accessible_scopes(
  p_scope_types text[] DEFAULT NULL
)
RETURNS TABLE (
  scope_id uuid,
  scope_key text,
  scope_type text,
  display_name text,
  role_name text,
  source_scope_id uuid,
  source_role_name text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
  SELECT *
  FROM app_security.actor_accessible_scopes(p_scope_types);
$$;

GRANT EXECUTE ON FUNCTION app_core.actor_accessible_scopes(text[]) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-- migrate:down
REVOKE EXECUTE ON FUNCTION app_core.actor_accessible_scopes(text[]) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;

DROP FUNCTION IF EXISTS app_core.actor_accessible_scopes(text[]);

DROP VIEW IF EXISTS app_core.v_notebook_entry_overview;
