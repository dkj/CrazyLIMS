-- migrate:up
-------------------------------------------------------------------------------
-- Harden scope helper functions (disable RLS inside logic)
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
SET row_security = off
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
    JOIN LATERAL (
      SELECT sri.child_role_name
      FROM app_security.scope_role_inheritance sri
      WHERE sri.parent_scope_type = st.scope_type
        AND sri.child_scope_type = child.scope_type
        AND sri.parent_role_name = st.role_name
        AND sri.is_active
    ) AS inherit ON TRUE
  )
  SELECT DISTINCT st.scope_id, st.role_name, st.source_scope_id, st.source_role_name
  FROM scope_tree st;
END;
$$;

CREATE OR REPLACE FUNCTION app_security.session_has_role(p_role text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  v_target text := lower(p_role);
  v_cfg text;
  v_active text;
  v_roles text[] := ARRAY[]::text[];
BEGIN
  IF v_target IS NULL OR v_target = '' THEN
    RETURN false;
  END IF;

  v_cfg := current_setting('app.roles', true);
  IF v_cfg IS NOT NULL AND v_cfg <> '' THEN
    v_roles := ARRAY(
      SELECT DISTINCT trim(both FROM val)
      FROM unnest(string_to_array(lower(v_cfg), ',')) AS val
      WHERE val IS NOT NULL AND trim(both FROM val) <> ''
    );
  END IF;

  BEGIN
    v_active := lower(current_setting('role', true));
  EXCEPTION
    WHEN undefined_object THEN
      v_active := NULL;
  END;

  IF v_active IS NOT NULL AND v_active <> '' AND v_active <> 'none' THEN
    IF NOT (v_active = ANY(v_roles)) THEN
      v_roles := array_append(v_roles, v_active);
    END IF;

    IF pg_has_role(v_active, v_target, 'member') THEN
      RETURN true;
    END IF;
  END IF;

  RETURN v_target = ANY(v_roles);
END;
$$;

GRANT EXECUTE ON FUNCTION app_security.session_has_role(text) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_security.has_role(p_role text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT app_security.session_has_role(p_role);
$$;

GRANT EXECUTE ON FUNCTION app_security.has_role(text) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_security.actor_has_scope(
  p_scope_id uuid,
  p_required_roles text[] DEFAULT NULL,
  p_actor_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_actor uuid := COALESCE(p_actor_id, app_security.current_actor_id());
  v_required text[] := app_security.coerce_roles(p_required_roles);
  v_needed boolean := array_length(v_required, 1) IS NOT NULL;
BEGIN
  IF p_scope_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_security.session_has_role('app_admin') THEN
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

GRANT EXECUTE ON FUNCTION app_security.actor_scope_roles(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;
GRANT EXECUTE ON FUNCTION app_security.actor_has_scope(uuid, text[], uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Access helper functions for the provenance domain
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_provenance.can_access_artefact(
  p_artefact_id uuid,
  p_required_roles text[] DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
BEGIN
  IF p_artefact_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_security.has_role('app_admin') THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM app_provenance.artefact_scopes s
    WHERE s.artefact_id = p_artefact_id
      AND app_security.actor_has_scope(s.scope_id, p_required_roles)
  );
END;
$$;

CREATE OR REPLACE FUNCTION app_provenance.can_access_process(
  p_process_instance_id uuid,
  p_required_roles text[] DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
BEGIN
  IF p_process_instance_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_security.has_role('app_admin') THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM app_provenance.process_scopes ps
    WHERE ps.process_instance_id = p_process_instance_id
      AND app_security.actor_has_scope(ps.scope_id, p_required_roles)
  );
END;
$$;

CREATE OR REPLACE FUNCTION app_provenance.can_access_storage_node(
  p_storage_node_id uuid,
  p_required_roles text[] DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_scope uuid;
BEGIN
  IF p_storage_node_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_security.session_has_role('app_admin') THEN
    RETURN true;
  END IF;

  SELECT scope_id
    INTO v_scope
    FROM app_provenance.storage_nodes
   WHERE storage_node_id = p_storage_node_id
     AND is_active;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_scope IS NULL THEN
    RETURN true;
  END IF;

  RETURN app_security.actor_has_scope(v_scope, p_required_roles);
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.can_access_artefact(uuid, text[]) TO app_auth, postgrest_authenticator, postgraphile_authenticator;
GRANT EXECUTE ON FUNCTION app_provenance.can_access_process(uuid, text[]) TO app_auth, postgrest_authenticator, postgraphile_authenticator;
GRANT EXECUTE ON FUNCTION app_provenance.can_access_storage_node(uuid, text[]) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Grants
-------------------------------------------------------------------------------

GRANT SELECT ON app_security.scopes TO app_auth;
GRANT SELECT ON app_security.scope_memberships TO app_auth;
GRANT SELECT ON app_security.scope_role_inheritance TO app_auth;

GRANT SELECT ON app_provenance.artefact_types TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.artefact_types TO app_admin;

GRANT SELECT ON app_provenance.artefact_traits TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.artefact_traits TO app_admin;

GRANT SELECT ON app_provenance.process_types TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.process_types TO app_admin;

GRANT SELECT ON app_provenance.artefacts TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.artefacts TO app_admin, app_operator, app_automation;

GRANT SELECT ON app_provenance.process_instances TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.process_instances TO app_admin, app_operator, app_automation;

GRANT SELECT ON app_provenance.process_io TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.process_io TO app_admin, app_operator, app_automation;

GRANT SELECT ON app_provenance.artefact_trait_values TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.artefact_trait_values TO app_admin, app_operator;

GRANT SELECT ON app_provenance.artefact_relationships TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.artefact_relationships TO app_admin, app_operator;

GRANT SELECT ON app_provenance.artefact_scopes TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.artefact_scopes TO app_admin, app_operator;

GRANT SELECT ON app_provenance.process_scopes TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.process_scopes TO app_admin, app_operator;

GRANT SELECT ON app_provenance.container_slot_definitions TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.container_slot_definitions TO app_admin;

GRANT SELECT ON app_provenance.container_slots TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.container_slots TO app_admin, app_operator;

GRANT SELECT ON app_provenance.artefact_container_assignments TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.artefact_container_assignments TO app_admin, app_operator, app_automation;

GRANT SELECT ON app_provenance.storage_nodes TO app_auth;
GRANT INSERT, UPDATE, DELETE ON app_provenance.storage_nodes TO app_admin, app_operator;

GRANT SELECT ON app_provenance.artefact_storage_events TO app_auth;
GRANT INSERT ON app_provenance.artefact_storage_events TO app_admin, app_operator, app_automation;
GRANT UPDATE, DELETE ON app_provenance.artefact_storage_events TO app_admin;

-------------------------------------------------------------------------------
-- Row level security policies
-------------------------------------------------------------------------------

ALTER TABLE app_security.scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.scope_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.scope_role_inheritance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS scope_memberships_operator_read ON app_security.scope_memberships;
DROP POLICY IF EXISTS scope_memberships_admin_manage ON app_security.scope_memberships;
DROP POLICY IF EXISTS scopes_operator_read ON app_security.scopes;
DROP POLICY IF EXISTS scopes_admin_manage ON app_security.scopes;
DROP POLICY IF EXISTS scope_role_inheritance_admin_manage ON app_security.scope_role_inheritance;

CREATE POLICY scopes_read_access ON app_security.scopes
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_security.actor_has_scope(scope_id)
  );

CREATE POLICY scope_memberships_read_access ON app_security.scope_memberships
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR user_id = app_security.current_actor_id()
    OR app_security.actor_has_scope(scope_id)
  );

CREATE POLICY scope_role_inheritance_read_access ON app_security.scope_role_inheritance
  FOR SELECT
  USING (app_security.has_role('app_admin') OR app_security.has_role('app_operator'));

CREATE POLICY scope_memberships_admin_manage ON app_security.scope_memberships
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

CREATE POLICY scopes_admin_manage ON app_security.scopes
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

CREATE POLICY scope_role_inheritance_admin_manage ON app_security.scope_role_inheritance
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

ALTER TABLE app_security.scopes FORCE ROW LEVEL SECURITY;
ALTER TABLE app_security.scope_memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE app_security.scope_role_inheritance FORCE ROW LEVEL SECURITY;

ALTER TABLE app_provenance.artefact_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.artefact_types FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS artefact_types_admin_manage ON app_provenance.artefact_types;
DROP POLICY IF EXISTS artefact_types_read ON app_provenance.artefact_types;

CREATE POLICY artefact_types_read ON app_provenance.artefact_types
  FOR SELECT
  USING (true);

CREATE POLICY artefact_types_admin_manage ON app_provenance.artefact_types
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

ALTER TABLE app_provenance.artefact_traits ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.artefact_traits FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS artefact_traits_admin_manage ON app_provenance.artefact_traits;
DROP POLICY IF EXISTS artefact_traits_read ON app_provenance.artefact_traits;

CREATE POLICY artefact_traits_read ON app_provenance.artefact_traits
  FOR SELECT
  USING (true);

CREATE POLICY artefact_traits_admin_manage ON app_provenance.artefact_traits
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

ALTER TABLE app_provenance.process_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.process_types FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS process_types_admin_manage ON app_provenance.process_types;
DROP POLICY IF EXISTS process_types_read ON app_provenance.process_types;

CREATE POLICY process_types_read ON app_provenance.process_types
  FOR SELECT
  USING (true);

CREATE POLICY process_types_admin_manage ON app_provenance.process_types
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

ALTER TABLE app_provenance.artefacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.artefacts FORCE ROW LEVEL SECURITY;

CREATE POLICY artefacts_select ON app_provenance.artefacts
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(artefact_id)
  );

CREATE POLICY artefacts_insert ON app_provenance.artefacts
  FOR INSERT
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_security.has_role('app_operator')
    OR app_security.has_role('app_automation')
  );

CREATE POLICY artefacts_update ON app_provenance.artefacts
  FOR UPDATE
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(artefact_id, ARRAY['app_operator','app_automation','app_researcher'])
  )
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(artefact_id, ARRAY['app_operator','app_automation','app_researcher'])
  );

CREATE POLICY artefacts_delete ON app_provenance.artefacts
  FOR DELETE
  USING (app_security.has_role('app_admin'));

ALTER TABLE app_provenance.process_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.process_instances FORCE ROW LEVEL SECURITY;

CREATE POLICY process_instances_select ON app_provenance.process_instances
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_process(process_instance_id)
  );

CREATE POLICY process_instances_insert ON app_provenance.process_instances
  FOR INSERT
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_security.has_role('app_operator')
    OR app_security.has_role('app_automation')
  );

CREATE POLICY process_instances_update ON app_provenance.process_instances
  FOR UPDATE
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator','app_automation','app_researcher'])
  )
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator','app_automation','app_researcher'])
  );

CREATE POLICY process_instances_delete ON app_provenance.process_instances
  FOR DELETE
  USING (app_security.has_role('app_admin'));

ALTER TABLE app_provenance.process_io ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.process_io FORCE ROW LEVEL SECURITY;

CREATE POLICY process_io_select ON app_provenance.process_io
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_process(process_instance_id)
    OR app_provenance.can_access_artefact(artefact_id)
  );

CREATE POLICY process_io_write ON app_provenance.process_io
  FOR INSERT
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator','app_automation'])
  );

CREATE POLICY process_io_update ON app_provenance.process_io
  FOR UPDATE
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator','app_automation'])
  )
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator','app_automation'])
  );

CREATE POLICY process_io_delete ON app_provenance.process_io
  FOR DELETE
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator'])
  );

ALTER TABLE app_provenance.artefact_trait_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.artefact_trait_values FORCE ROW LEVEL SECURITY;

CREATE POLICY artefact_trait_values_select ON app_provenance.artefact_trait_values
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(artefact_id)
  );

CREATE POLICY artefact_trait_values_modify ON app_provenance.artefact_trait_values
  FOR ALL
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(artefact_id, ARRAY['app_operator'])
  )
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(artefact_id, ARRAY['app_operator'])
  );

ALTER TABLE app_provenance.artefact_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.artefact_relationships FORCE ROW LEVEL SECURITY;

CREATE POLICY artefact_relationships_select ON app_provenance.artefact_relationships
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(parent_artefact_id)
    OR app_provenance.can_access_artefact(child_artefact_id)
  );

CREATE POLICY artefact_relationships_modify ON app_provenance.artefact_relationships
  FOR ALL
  USING (
    app_security.has_role('app_admin')
    OR (
      app_provenance.can_access_artefact(parent_artefact_id, ARRAY['app_operator'])
      AND app_provenance.can_access_artefact(child_artefact_id, ARRAY['app_operator'])
    )
  )
  WITH CHECK (
    app_security.has_role('app_admin')
    OR (
      app_provenance.can_access_artefact(parent_artefact_id, ARRAY['app_operator'])
      AND app_provenance.can_access_artefact(child_artefact_id, ARRAY['app_operator'])
    )
  );

ALTER TABLE app_provenance.artefact_scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.artefact_scopes FORCE ROW LEVEL SECURITY;

CREATE POLICY artefact_scopes_select ON app_provenance.artefact_scopes
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(artefact_id)
  );

CREATE POLICY artefact_scopes_modify ON app_provenance.artefact_scopes
  FOR ALL
  USING (
    app_security.has_role('app_admin')
    OR app_security.has_role('app_operator')
  )
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_security.has_role('app_operator')
  );

ALTER TABLE app_provenance.process_scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.process_scopes FORCE ROW LEVEL SECURITY;

CREATE POLICY process_scopes_select ON app_provenance.process_scopes
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_process(process_instance_id)
  );

CREATE POLICY process_scopes_modify ON app_provenance.process_scopes
  FOR ALL
  USING (
    app_security.has_role('app_admin')
    OR app_security.has_role('app_operator')
  )
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_security.has_role('app_operator')
  );

ALTER TABLE app_provenance.container_slot_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.container_slot_definitions FORCE ROW LEVEL SECURITY;

CREATE POLICY container_slot_definitions_read ON app_provenance.container_slot_definitions
  FOR SELECT
  USING (true);

CREATE POLICY container_slot_definitions_manage ON app_provenance.container_slot_definitions
  FOR ALL
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

ALTER TABLE app_provenance.container_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.container_slots FORCE ROW LEVEL SECURITY;

CREATE POLICY container_slots_select ON app_provenance.container_slots
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(container_artefact_id)
  );

CREATE POLICY container_slots_modify ON app_provenance.container_slots
  FOR ALL
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(container_artefact_id, ARRAY['app_operator'])
  )
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(container_artefact_id, ARRAY['app_operator'])
  );

ALTER TABLE app_provenance.artefact_container_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.artefact_container_assignments FORCE ROW LEVEL SECURITY;

CREATE POLICY artefact_container_assignments_select ON app_provenance.artefact_container_assignments
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(artefact_id)
    OR app_provenance.can_access_artefact(container_artefact_id)
  );

CREATE POLICY artefact_container_assignments_modify ON app_provenance.artefact_container_assignments
  FOR ALL
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(container_artefact_id, ARRAY['app_operator','app_automation'])
  )
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(container_artefact_id, ARRAY['app_operator','app_automation'])
  );

ALTER TABLE app_provenance.storage_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.storage_nodes FORCE ROW LEVEL SECURITY;

CREATE POLICY storage_nodes_select ON app_provenance.storage_nodes
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_storage_node(storage_node_id)
  );

CREATE POLICY storage_nodes_modify ON app_provenance.storage_nodes
  FOR ALL
  USING (app_security.has_role('app_admin') OR app_security.has_role('app_operator'))
  WITH CHECK (app_security.has_role('app_admin') OR app_security.has_role('app_operator'));

ALTER TABLE app_provenance.artefact_storage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_provenance.artefact_storage_events FORCE ROW LEVEL SECURITY;

CREATE POLICY artefact_storage_events_select ON app_provenance.artefact_storage_events
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(artefact_id)
  );

CREATE POLICY artefact_storage_events_insert ON app_provenance.artefact_storage_events
  FOR INSERT
  WITH CHECK (
    app_security.has_role('app_admin')
    OR app_provenance.can_access_artefact(artefact_id, ARRAY['app_operator','app_automation'])
  );

CREATE POLICY artefact_storage_events_update ON app_provenance.artefact_storage_events
  FOR UPDATE
  USING (app_security.has_role('app_admin'))
  WITH CHECK (app_security.has_role('app_admin'));

CREATE POLICY artefact_storage_events_delete ON app_provenance.artefact_storage_events
  FOR DELETE
  USING (app_security.has_role('app_admin'));

-------------------------------------------------------------------------------
-- Touch-updated-at triggers
-------------------------------------------------------------------------------

CREATE TRIGGER trg_touch_scopes
BEFORE UPDATE ON app_security.scopes
FOR EACH ROW
EXECUTE FUNCTION app_security.touch_updated_at();

CREATE TRIGGER trg_touch_scope_memberships
BEFORE UPDATE ON app_security.scope_memberships
FOR EACH ROW
EXECUTE FUNCTION app_security.touch_updated_at();

CREATE TRIGGER trg_touch_artefact_types
BEFORE UPDATE ON app_provenance.artefact_types
FOR EACH ROW
EXECUTE FUNCTION app_security.touch_updated_at();

CREATE TRIGGER trg_touch_artefact_traits
BEFORE UPDATE ON app_provenance.artefact_traits
FOR EACH ROW
EXECUTE FUNCTION app_security.touch_updated_at();

CREATE TRIGGER trg_touch_process_types
BEFORE UPDATE ON app_provenance.process_types
FOR EACH ROW
EXECUTE FUNCTION app_security.touch_updated_at();

CREATE TRIGGER trg_touch_process_instances
BEFORE UPDATE ON app_provenance.process_instances
FOR EACH ROW
EXECUTE FUNCTION app_security.touch_updated_at();

CREATE TRIGGER trg_touch_artefacts
BEFORE UPDATE ON app_provenance.artefacts
FOR EACH ROW
EXECUTE FUNCTION app_security.touch_updated_at();

CREATE TRIGGER trg_touch_storage_nodes
BEFORE UPDATE ON app_provenance.storage_nodes
FOR EACH ROW
EXECUTE FUNCTION app_security.touch_updated_at();

-------------------------------------------------------------------------------
-- Audit triggers
-------------------------------------------------------------------------------

CREATE TRIGGER trg_audit_scopes
AFTER INSERT OR UPDATE OR DELETE ON app_security.scopes
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_scope_memberships
AFTER INSERT OR UPDATE OR DELETE ON app_security.scope_memberships
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_scope_role_inheritance
AFTER INSERT OR UPDATE OR DELETE ON app_security.scope_role_inheritance
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_artefact_types
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.artefact_types
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_artefact_traits
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.artefact_traits
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_process_types
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.process_types
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_process_instances
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.process_instances
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_artefacts
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.artefacts
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_process_io
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.process_io
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_artefact_trait_values
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.artefact_trait_values
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_artefact_relationships
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.artefact_relationships
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_artefact_scopes
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.artefact_scopes
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_process_scopes
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.process_scopes
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_container_slot_definitions
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.container_slot_definitions
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_container_slots
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.container_slots
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_artefact_container_assignments
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.artefact_container_assignments
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_storage_nodes
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.storage_nodes
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_artefact_storage_events
AFTER INSERT OR UPDATE OR DELETE ON app_provenance.artefact_storage_events
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

-- migrate:down
DROP TRIGGER IF EXISTS trg_audit_artefact_storage_events ON app_provenance.artefact_storage_events;
DROP TRIGGER IF EXISTS trg_audit_storage_nodes ON app_provenance.storage_nodes;
DROP TRIGGER IF EXISTS trg_audit_artefact_container_assignments ON app_provenance.artefact_container_assignments;
DROP TRIGGER IF EXISTS trg_audit_container_slots ON app_provenance.container_slots;
DROP TRIGGER IF EXISTS trg_audit_container_slot_definitions ON app_provenance.container_slot_definitions;
DROP TRIGGER IF EXISTS trg_audit_process_scopes ON app_provenance.process_scopes;
DROP TRIGGER IF EXISTS trg_audit_artefact_scopes ON app_provenance.artefact_scopes;
DROP TRIGGER IF EXISTS trg_audit_artefact_relationships ON app_provenance.artefact_relationships;
DROP TRIGGER IF EXISTS trg_audit_artefact_trait_values ON app_provenance.artefact_trait_values;
DROP TRIGGER IF EXISTS trg_audit_process_io ON app_provenance.process_io;
DROP TRIGGER IF EXISTS trg_audit_artefacts ON app_provenance.artefacts;
DROP TRIGGER IF EXISTS trg_audit_process_instances ON app_provenance.process_instances;
DROP TRIGGER IF EXISTS trg_audit_process_types ON app_provenance.process_types;
DROP TRIGGER IF EXISTS trg_audit_artefact_traits ON app_provenance.artefact_traits;
DROP TRIGGER IF EXISTS trg_audit_artefact_types ON app_provenance.artefact_types;
DROP TRIGGER IF EXISTS trg_audit_scope_role_inheritance ON app_security.scope_role_inheritance;
DROP TRIGGER IF EXISTS trg_audit_scope_memberships ON app_security.scope_memberships;
DROP TRIGGER IF EXISTS trg_audit_scopes ON app_security.scopes;

DROP TRIGGER IF EXISTS trg_touch_storage_nodes ON app_provenance.storage_nodes;
DROP TRIGGER IF EXISTS trg_touch_artefacts ON app_provenance.artefacts;
DROP TRIGGER IF EXISTS trg_touch_process_instances ON app_provenance.process_instances;
DROP TRIGGER IF EXISTS trg_touch_process_types ON app_provenance.process_types;
DROP TRIGGER IF EXISTS trg_touch_artefact_traits ON app_provenance.artefact_traits;
DROP TRIGGER IF EXISTS trg_touch_artefact_types ON app_provenance.artefact_types;
DROP TRIGGER IF EXISTS trg_touch_scope_memberships ON app_security.scope_memberships;
DROP TRIGGER IF EXISTS trg_touch_scopes ON app_security.scopes;

DROP POLICY IF EXISTS artefact_storage_events_delete ON app_provenance.artefact_storage_events;
DROP POLICY IF EXISTS artefact_storage_events_update ON app_provenance.artefact_storage_events;
DROP POLICY IF EXISTS artefact_storage_events_insert ON app_provenance.artefact_storage_events;
DROP POLICY IF EXISTS artefact_storage_events_select ON app_provenance.artefact_storage_events;
ALTER TABLE app_provenance.artefact_storage_events DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS storage_nodes_modify ON app_provenance.storage_nodes;
DROP POLICY IF EXISTS storage_nodes_select ON app_provenance.storage_nodes;
ALTER TABLE app_provenance.storage_nodes DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS artefact_container_assignments_modify ON app_provenance.artefact_container_assignments;
DROP POLICY IF EXISTS artefact_container_assignments_select ON app_provenance.artefact_container_assignments;
ALTER TABLE app_provenance.artefact_container_assignments DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS container_slots_modify ON app_provenance.container_slots;
DROP POLICY IF EXISTS container_slots_select ON app_provenance.container_slots;
ALTER TABLE app_provenance.container_slots DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS container_slot_definitions_manage ON app_provenance.container_slot_definitions;
DROP POLICY IF EXISTS container_slot_definitions_read ON app_provenance.container_slot_definitions;
ALTER TABLE app_provenance.container_slot_definitions DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS process_scopes_modify ON app_provenance.process_scopes;
DROP POLICY IF EXISTS process_scopes_select ON app_provenance.process_scopes;
ALTER TABLE app_provenance.process_scopes DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS artefact_scopes_modify ON app_provenance.artefact_scopes;
DROP POLICY IF EXISTS artefact_scopes_select ON app_provenance.artefact_scopes;
ALTER TABLE app_provenance.artefact_scopes DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS artefact_relationships_modify ON app_provenance.artefact_relationships;
DROP POLICY IF EXISTS artefact_relationships_select ON app_provenance.artefact_relationships;
ALTER TABLE app_provenance.artefact_relationships DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS artefact_trait_values_modify ON app_provenance.artefact_trait_values;
DROP POLICY IF EXISTS artefact_trait_values_select ON app_provenance.artefact_trait_values;
ALTER TABLE app_provenance.artefact_trait_values DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS process_io_delete ON app_provenance.process_io;
DROP POLICY IF EXISTS process_io_update ON app_provenance.process_io;
DROP POLICY IF EXISTS process_io_write ON app_provenance.process_io;
DROP POLICY IF EXISTS process_io_select ON app_provenance.process_io;
ALTER TABLE app_provenance.process_io DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS process_instances_delete ON app_provenance.process_instances;
DROP POLICY IF EXISTS process_instances_update ON app_provenance.process_instances;
DROP POLICY IF EXISTS process_instances_insert ON app_provenance.process_instances;
DROP POLICY IF EXISTS process_instances_select ON app_provenance.process_instances;
ALTER TABLE app_provenance.process_instances DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS artefacts_delete ON app_provenance.artefacts;
DROP POLICY IF EXISTS artefacts_update ON app_provenance.artefacts;
DROP POLICY IF EXISTS artefacts_insert ON app_provenance.artefacts;
DROP POLICY IF EXISTS artefacts_select ON app_provenance.artefacts;
ALTER TABLE app_provenance.artefacts DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS process_types_admin_manage ON app_provenance.process_types;
DROP POLICY IF EXISTS process_types_read ON app_provenance.process_types;
ALTER TABLE app_provenance.process_types DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS artefact_traits_admin_manage ON app_provenance.artefact_traits;
DROP POLICY IF EXISTS artefact_traits_read ON app_provenance.artefact_traits;
ALTER TABLE app_provenance.artefact_traits DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS artefact_types_admin_manage ON app_provenance.artefact_types;
DROP POLICY IF EXISTS artefact_types_read ON app_provenance.artefact_types;
ALTER TABLE app_provenance.artefact_types DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS scope_role_inheritance_admin_manage ON app_security.scope_role_inheritance;
DROP POLICY IF EXISTS scope_role_inheritance_read_access ON app_security.scope_role_inheritance;
ALTER TABLE app_security.scope_role_inheritance DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS scopes_admin_manage ON app_security.scopes;
DROP POLICY IF EXISTS scopes_read_access ON app_security.scopes;
ALTER TABLE app_security.scopes DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS scope_memberships_admin_manage ON app_security.scope_memberships;
DROP POLICY IF EXISTS scope_memberships_read_access ON app_security.scope_memberships;
ALTER TABLE app_security.scope_memberships DISABLE ROW LEVEL SECURITY;

REVOKE EXECUTE ON FUNCTION app_provenance.can_access_storage_node(uuid, text[]) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.can_access_process(uuid, text[]) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.can_access_artefact(uuid, text[]) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;

DROP FUNCTION IF EXISTS app_provenance.can_access_storage_node(uuid, text[]);
DROP FUNCTION IF EXISTS app_provenance.can_access_process(uuid, text[]);
DROP FUNCTION IF EXISTS app_provenance.can_access_artefact(uuid, text[]);

DROP FUNCTION IF EXISTS app_security.session_has_role(text);

REVOKE EXECUTE ON FUNCTION app_security.actor_has_scope(uuid, text[], uuid) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_security.actor_scope_roles(uuid) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;

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
    JOIN LATERAL (
      SELECT sri.child_role_name
      FROM app_security.scope_role_inheritance sri
      WHERE sri.parent_scope_type = st.scope_type
        AND sri.child_scope_type = child.scope_type
        AND sri.parent_role_name = st.role_name
        AND sri.is_active
    ) AS inherit ON TRUE
  )
  SELECT DISTINCT st.scope_id, st.role_name, st.source_scope_id, st.source_role_name
  FROM scope_tree st;
END;
$$;

CREATE OR REPLACE FUNCTION app_security.has_role(p_role text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT lower(p_role) = ANY(app_security.current_roles());
$$;

GRANT EXECUTE ON FUNCTION app_security.has_role(text) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

GRANT EXECUTE ON FUNCTION app_security.actor_scope_roles(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;
GRANT EXECUTE ON FUNCTION app_security.actor_has_scope(uuid, text[], uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

REVOKE SELECT ON app_security.scope_role_inheritance FROM app_auth;
REVOKE SELECT ON app_security.scope_memberships FROM app_auth;
REVOKE SELECT ON app_security.scopes FROM app_auth;

REVOKE SELECT ON app_provenance.artefact_storage_events FROM app_auth;
REVOKE INSERT ON app_provenance.artefact_storage_events FROM app_admin, app_operator, app_automation;
REVOKE UPDATE, DELETE ON app_provenance.artefact_storage_events FROM app_admin;

REVOKE SELECT ON app_provenance.storage_nodes FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.storage_nodes FROM app_admin, app_operator;

REVOKE SELECT ON app_provenance.artefact_container_assignments FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.artefact_container_assignments FROM app_admin, app_operator, app_automation;

REVOKE SELECT ON app_provenance.container_slots FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.container_slots FROM app_admin, app_operator;

REVOKE SELECT ON app_provenance.container_slot_definitions FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.container_slot_definitions FROM app_admin;

REVOKE SELECT ON app_provenance.process_scopes FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.process_scopes FROM app_admin, app_operator;

REVOKE SELECT ON app_provenance.artefact_scopes FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.artefact_scopes FROM app_admin, app_operator;

REVOKE SELECT ON app_provenance.artefact_relationships FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.artefact_relationships FROM app_admin, app_operator;

REVOKE SELECT ON app_provenance.artefact_trait_values FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.artefact_trait_values FROM app_admin, app_operator;

REVOKE SELECT ON app_provenance.process_io FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.process_io FROM app_admin, app_operator, app_automation;

REVOKE SELECT ON app_provenance.process_instances FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.process_instances FROM app_admin, app_operator, app_automation;

REVOKE SELECT ON app_provenance.artefacts FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.artefacts FROM app_admin, app_operator, app_automation;

REVOKE SELECT ON app_provenance.process_types FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.process_types FROM app_admin;

REVOKE SELECT ON app_provenance.artefact_traits FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.artefact_traits FROM app_admin;

REVOKE SELECT ON app_provenance.artefact_types FROM app_auth;
REVOKE INSERT, UPDATE, DELETE ON app_provenance.artefact_types FROM app_admin;

REVOKE SELECT ON app_security.scope_role_inheritance FROM app_operator;

REVOKE SELECT ON app_security.scope_role_inheritance FROM app_auth;
REVOKE SELECT ON app_security.scope_memberships FROM app_auth;
REVOKE SELECT ON app_security.scopes FROM app_auth;

GRANT SELECT ON app_security.scope_memberships TO app_operator;
*** End Patch
