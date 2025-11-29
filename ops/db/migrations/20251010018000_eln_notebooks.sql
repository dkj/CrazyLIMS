-- migrate:up
CREATE SCHEMA IF NOT EXISTS app_eln AUTHORIZATION postgres;

GRANT USAGE ON SCHEMA app_eln TO app_auth, dev, postgrest_authenticator, postgraphile_authenticator;
GRANT CREATE ON SCHEMA app_eln TO dev;

-------------------------------------------------------------------------------
-- Core tables
-------------------------------------------------------------------------------

CREATE TABLE app_eln.notebook_entries (
  entry_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_key        text UNIQUE,
  title            text NOT NULL,
  description      text,
  primary_scope_id uuid NOT NULL REFERENCES app_security.scopes(scope_id) ON DELETE RESTRICT,
  status           text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','submitted','locked')),
  metadata         jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  submitted_at     timestamptz,
  submitted_by     uuid REFERENCES app_core.users(id),
  locked_at        timestamptz,
  locked_by        uuid REFERENCES app_core.users(id),
  created_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by       uuid NOT NULL DEFAULT app_security.current_actor_id() REFERENCES app_core.users(id),
  updated_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_by       uuid NOT NULL DEFAULT app_security.current_actor_id() REFERENCES app_core.users(id),
  CHECK (trim(both FROM title) <> ''),
  CHECK (entry_key IS NULL OR entry_key = lower(entry_key))
);

CREATE INDEX idx_notebook_entries_scope ON app_eln.notebook_entries(primary_scope_id);

CREATE TABLE app_eln.notebook_entry_scopes (
  entry_id     uuid NOT NULL REFERENCES app_eln.notebook_entries(entry_id) ON DELETE CASCADE,
  scope_id     uuid NOT NULL REFERENCES app_security.scopes(scope_id) ON DELETE CASCADE,
  relationship text NOT NULL DEFAULT 'primary' CHECK (relationship IN ('primary','supplementary','witness','reference')),
  assigned_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  assigned_by  uuid NOT NULL DEFAULT app_security.current_actor_id() REFERENCES app_core.users(id),
  metadata     jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  PRIMARY KEY (entry_id, scope_id, relationship)
);

CREATE INDEX idx_notebook_entry_scopes_scope ON app_eln.notebook_entry_scopes(scope_id);

CREATE TABLE app_eln.notebook_entry_versions (
  version_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id        uuid NOT NULL REFERENCES app_eln.notebook_entries(entry_id) ON DELETE CASCADE,
  version_number  integer NOT NULL CHECK (version_number > 0),
  notebook_json   jsonb NOT NULL CHECK (jsonb_typeof(notebook_json) IN ('object','array')),
  checksum        text NOT NULL,
  note            text,
  metadata        jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by      uuid NOT NULL DEFAULT app_security.current_actor_id() REFERENCES app_core.users(id),
  UNIQUE (entry_id, version_number)
);

CREATE INDEX idx_notebook_entry_versions_entry ON app_eln.notebook_entry_versions(entry_id, version_number DESC);

-------------------------------------------------------------------------------
-- Helper functions
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_eln.canonical_json_digest(p_json jsonb)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT encode(digest(p_json::text, 'sha256'), 'hex');
$$;

CREATE OR REPLACE FUNCTION app_eln.can_access_entry(
  p_entry_id uuid,
  p_required_roles text[] DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_eln, app_security, app_core
SET row_security = off
AS $$
BEGIN
  IF p_entry_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_security.has_role('app_admin') THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM app_eln.notebook_entry_scopes s
    WHERE s.entry_id = p_entry_id
      AND app_security.actor_has_scope(s.scope_id, p_required_roles)
  );
END;
$$;

CREATE OR REPLACE FUNCTION app_eln.can_edit_entry(
  p_entry_id uuid,
  p_required_roles text[] DEFAULT ARRAY['app_researcher','app_operator','app_admin']
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_eln, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_status text;
BEGIN
  IF p_entry_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT status
  INTO v_status
  FROM app_eln.notebook_entries
  WHERE entry_id = p_entry_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_status <> 'draft' AND NOT app_security.has_role('app_admin') THEN
    RETURN false;
  END IF;

  RETURN app_eln.can_access_entry(p_entry_id, p_required_roles);
END;
$$;

CREATE OR REPLACE FUNCTION app_security.actor_accessible_scopes(
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_filter text[];
BEGIN
  IF p_scope_types IS NOT NULL THEN
    v_filter := ARRAY(
      SELECT DISTINCT lower(trim(val))
      FROM unnest(p_scope_types) AS val
      WHERE val IS NOT NULL AND trim(val) <> ''
    );
  END IF;

  RETURN QUERY
  SELECT
    ar.scope_id,
    s.scope_key,
    s.scope_type,
    s.display_name,
    ar.role_name,
    ar.source_scope_id,
    ar.source_role_name
  FROM app_security.actor_scope_roles(app_security.current_actor_id()) ar
  JOIN app_security.scopes s
    ON s.scope_id = ar.scope_id
  WHERE s.is_active
    AND (
      v_filter IS NULL
      OR array_length(v_filter, 1) IS NULL
      OR s.scope_type = ANY(v_filter)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION app_eln.can_access_entry(uuid, text[]) TO app_auth, postgrest_authenticator, postgraphile_authenticator;
GRANT EXECUTE ON FUNCTION app_eln.can_edit_entry(uuid, text[]) TO app_auth, postgrest_authenticator, postgraphile_authenticator;
GRANT EXECUTE ON FUNCTION app_security.actor_accessible_scopes(text[]) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Trigger helpers
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_eln.tg_enforce_entry_status()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public, app_eln, app_security, app_core
AS $$
DECLARE
  v_actor uuid := app_security.current_actor_id();
  v_is_admin boolean := app_security.has_role('app_admin');
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status IS NULL THEN
      NEW.status := 'draft';
    ELSIF NEW.status <> 'draft' THEN
      RAISE EXCEPTION 'New notebook entries must start in draft status'
        USING ERRCODE = 'check_violation';
    END IF;

    NEW.created_by := COALESCE(NEW.created_by, v_actor);
    NEW.updated_by := COALESCE(NEW.updated_by, v_actor);
    RETURN NEW;
  END IF;

  IF OLD.status = 'locked' AND NEW.status = 'locked' THEN
    RAISE EXCEPTION 'Notebook entry % is locked and cannot be modified', OLD.entry_id
      USING ERRCODE = '55000';
  END IF;

  IF OLD.status = 'locked' AND NEW.status <> 'locked' THEN
    IF NOT v_is_admin THEN
      RAISE EXCEPTION 'Only administrators may alter locked notebook entries'
        USING ERRCODE = '42501';
    END IF;
    NEW.locked_at := NULL;
    NEW.locked_by := NULL;
  END IF;

  IF NEW.status = 'locked' AND OLD.status <> 'submitted' THEN
    RAISE EXCEPTION 'Notebook entry must be submitted before it can be locked'
      USING ERRCODE = 'check_violation';
  END IF;

  IF OLD.status = 'submitted' AND NEW.status = 'submitted' THEN
    RAISE EXCEPTION 'Submitted notebook entry cannot be modified without a status change'
      USING ERRCODE = '55000';
  END IF;

  IF NEW.status = 'submitted' AND OLD.status = 'draft' THEN
    NEW.submitted_at := clock_timestamp();
    NEW.submitted_by := COALESCE(NEW.submitted_by, v_actor);
  ELSIF OLD.status = 'submitted' AND NEW.status = 'draft' THEN
    IF NOT v_is_admin THEN
      RAISE EXCEPTION 'Only administrators may revert submissions back to draft'
        USING ERRCODE = '42501';
    END IF;
    NEW.submitted_at := NULL;
    NEW.submitted_by := NULL;
    NEW.locked_at := NULL;
    NEW.locked_by := NULL;
  END IF;

  IF NEW.status = 'locked' AND OLD.status = 'submitted' THEN
    NEW.locked_at := clock_timestamp();
    NEW.locked_by := COALESCE(NEW.locked_by, v_actor);
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION app_eln.tg_touch_notebook_entry()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public, app_eln, app_security
AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  NEW.updated_by := COALESCE(app_security.current_actor_id(), NEW.updated_by);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION app_eln.tg_ensure_primary_scope()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_eln, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_actor uuid := COALESCE(app_security.current_actor_id(), NEW.created_by);
BEGIN
  INSERT INTO app_eln.notebook_entry_scopes (entry_id, scope_id, relationship, assigned_by)
  VALUES (NEW.entry_id, NEW.primary_scope_id, 'primary', v_actor)
  ON CONFLICT (entry_id, scope_id, relationship) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION app_eln.tg_prepare_notebook_version()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public, app_eln, app_security, app_core
AS $$
DECLARE
  v_next integer;
  v_status text;
  v_actor uuid := app_security.current_actor_id();
BEGIN
  IF NEW.entry_id IS NULL THEN
    RAISE EXCEPTION 'Notebook version must reference an entry'
      USING ERRCODE = 'not_null_violation';
  END IF;

  SELECT status
  INTO v_status
  FROM app_eln.notebook_entries
  WHERE entry_id = NEW.entry_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Notebook entry % does not exist', NEW.entry_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  IF v_status IN ('submitted','locked') AND NOT app_security.has_role('app_admin') THEN
    RAISE EXCEPTION 'Notebook entry % is % and cannot be modified', NEW.entry_id, v_status
      USING ERRCODE = '55000';
  END IF;

  IF NEW.version_number IS NULL OR NEW.version_number <= 0 THEN
    SELECT COALESCE(MAX(version_number), 0) + 1
    INTO v_next
    FROM app_eln.notebook_entry_versions
    WHERE entry_id = NEW.entry_id;

    NEW.version_number := v_next;
  END IF;

  NEW.created_by := COALESCE(NEW.created_by, v_actor);
  NEW.checksum := app_eln.canonical_json_digest(NEW.notebook_json);

  RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------
-- Grants and RLS
-------------------------------------------------------------------------------

GRANT SELECT ON app_eln.notebook_entries TO app_auth;
GRANT INSERT, UPDATE ON app_eln.notebook_entries TO app_admin, app_operator, app_researcher;
GRANT DELETE ON app_eln.notebook_entries TO app_admin;

GRANT SELECT ON app_eln.notebook_entry_versions TO app_auth;
GRANT INSERT ON app_eln.notebook_entry_versions TO app_admin, app_operator, app_researcher;
GRANT DELETE ON app_eln.notebook_entry_versions TO app_admin;

GRANT SELECT ON app_eln.notebook_entry_scopes TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_eln.notebook_entry_scopes TO app_admin;

ALTER TABLE app_eln.notebook_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_eln.notebook_entries FORCE ROW LEVEL SECURITY;

CREATE POLICY notebook_entries_select ON app_eln.notebook_entries
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_eln.can_access_entry(entry_id)
  );

CREATE POLICY notebook_entries_insert ON app_eln.notebook_entries
  FOR INSERT
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_security.actor_has_scope(primary_scope_id, ARRAY['app_researcher','app_operator','app_admin'])
  );

CREATE POLICY notebook_entries_update ON app_eln.notebook_entries
  FOR UPDATE
  USING (
    app_security.has_role('app_admin')
    OR app_eln.can_access_entry(entry_id, ARRAY['app_researcher','app_operator','app_admin'])
  )
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_eln.can_access_entry(entry_id, ARRAY['app_researcher','app_operator','app_admin'])
  );

CREATE POLICY notebook_entries_delete ON app_eln.notebook_entries
  FOR DELETE
  USING (app_security.has_role('app_admin'));

ALTER TABLE app_eln.notebook_entry_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_eln.notebook_entry_versions FORCE ROW LEVEL SECURITY;

CREATE POLICY notebook_entry_versions_select ON app_eln.notebook_entry_versions
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_eln.can_access_entry(entry_id)
  );

CREATE POLICY notebook_entry_versions_insert ON app_eln.notebook_entry_versions
  FOR INSERT
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_eln.can_edit_entry(entry_id)
  );

CREATE POLICY notebook_entry_versions_delete ON app_eln.notebook_entry_versions
  FOR DELETE
  USING (app_security.has_role('app_admin'));

ALTER TABLE app_eln.notebook_entry_scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_eln.notebook_entry_scopes FORCE ROW LEVEL SECURITY;

CREATE POLICY notebook_entry_scopes_select ON app_eln.notebook_entry_scopes
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_eln.can_access_entry(entry_id)
  );

CREATE POLICY notebook_entry_scopes_modify ON app_eln.notebook_entry_scopes
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

-------------------------------------------------------------------------------
-- Views
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW app_eln.v_notebook_entry_overview AS
SELECT
  e.entry_id,
  e.entry_key,
  e.title,
  e.description,
  e.status,
  e.primary_scope_id,
  s.scope_key AS primary_scope_key,
  s.display_name AS primary_scope_name,
  e.metadata,
  e.submitted_at,
  e.submitted_by,
  e.locked_at,
  e.locked_by,
  e.created_at,
  e.created_by,
  e.updated_at,
  e.updated_by,
  latest.version_number AS latest_version,
  latest.created_at AS latest_version_created_at,
  latest.created_by AS latest_version_created_by
FROM app_eln.notebook_entries e
LEFT JOIN app_security.scopes s
  ON s.scope_id = e.primary_scope_id
LEFT JOIN LATERAL (
  SELECT v.version_number, v.created_at, v.created_by
  FROM app_eln.notebook_entry_versions v
  WHERE v.entry_id = e.entry_id
  ORDER BY v.version_number DESC
  LIMIT 1
) AS latest ON TRUE;

GRANT SELECT ON app_eln.v_notebook_entry_overview TO app_auth;

-------------------------------------------------------------------------------
-- Triggers
-------------------------------------------------------------------------------

CREATE TRIGGER trg_enforce_notebook_entry_status
BEFORE INSERT OR UPDATE ON app_eln.notebook_entries
FOR EACH ROW
EXECUTE FUNCTION app_eln.tg_enforce_entry_status();

CREATE TRIGGER trg_touch_notebook_entries
BEFORE UPDATE ON app_eln.notebook_entries
FOR EACH ROW
EXECUTE FUNCTION app_eln.tg_touch_notebook_entry();

CREATE TRIGGER trg_assign_primary_scope
AFTER INSERT ON app_eln.notebook_entries
FOR EACH ROW
EXECUTE FUNCTION app_eln.tg_ensure_primary_scope();

CREATE TRIGGER trg_prepare_notebook_version
BEFORE INSERT ON app_eln.notebook_entry_versions
FOR EACH ROW
EXECUTE FUNCTION app_eln.tg_prepare_notebook_version();

CREATE TRIGGER trg_audit_notebook_entries
AFTER INSERT OR UPDATE OR DELETE ON app_eln.notebook_entries
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_notebook_entry_versions
AFTER INSERT OR UPDATE OR DELETE ON app_eln.notebook_entry_versions
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_notebook_entry_scopes
AFTER INSERT OR UPDATE OR DELETE ON app_eln.notebook_entry_scopes
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

-- migrate:down
DROP TRIGGER IF EXISTS trg_audit_notebook_entry_scopes ON app_eln.notebook_entry_scopes;
DROP TRIGGER IF EXISTS trg_audit_notebook_entry_versions ON app_eln.notebook_entry_versions;
DROP TRIGGER IF EXISTS trg_audit_notebook_entries ON app_eln.notebook_entries;
DROP TRIGGER IF EXISTS trg_prepare_notebook_version ON app_eln.notebook_entry_versions;
DROP TRIGGER IF EXISTS trg_assign_primary_scope ON app_eln.notebook_entries;
DROP TRIGGER IF EXISTS trg_touch_notebook_entries ON app_eln.notebook_entries;
DROP TRIGGER IF EXISTS trg_enforce_notebook_entry_status ON app_eln.notebook_entries;

DROP VIEW IF EXISTS app_eln.v_notebook_entry_overview;

REVOKE EXECUTE ON FUNCTION app_security.actor_accessible_scopes(text[]) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_eln.can_edit_entry(uuid, text[]) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_eln.can_access_entry(uuid, text[]) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;

DROP FUNCTION IF EXISTS app_eln.tg_prepare_notebook_version();
DROP FUNCTION IF EXISTS app_eln.tg_ensure_primary_scope();
DROP FUNCTION IF EXISTS app_eln.tg_touch_notebook_entry();
DROP FUNCTION IF EXISTS app_eln.tg_enforce_entry_status();

DROP FUNCTION IF EXISTS app_security.actor_accessible_scopes(text[]);
DROP FUNCTION IF EXISTS app_eln.can_edit_entry(uuid, text[]);
DROP FUNCTION IF EXISTS app_eln.can_access_entry(uuid, text[]);
DROP FUNCTION IF EXISTS app_eln.canonical_json_digest(jsonb);

DROP TABLE IF EXISTS app_eln.notebook_entry_versions;
DROP TABLE IF EXISTS app_eln.notebook_entry_scopes;
DROP TABLE IF EXISTS app_eln.notebook_entries;

DROP SCHEMA IF EXISTS app_eln CASCADE;
