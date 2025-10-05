-- migrate:up

-------------------------------------------------------------------------------
-- Helper predicates for project-scoped access
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION lims.can_access_sample(p_sample_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
BEGIN
  IF p_sample_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.samples s
    WHERE s.id = p_sample_id
      AND lims.can_access_project(s.project_id)
  );
END;
$$;

ALTER FUNCTION lims.can_access_sample(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.can_access_sample(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.can_access_labware(p_labware_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
BEGIN
  IF p_labware_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.samples s
    WHERE s.current_labware_id = p_labware_id
      AND lims.can_access_project(s.project_id)
  )
  OR EXISTS (
    SELECT 1
    FROM lims.sample_labware_assignments sla
    JOIN lims.samples s ON s.id = sla.sample_id
    WHERE sla.labware_id = p_labware_id
      AND sla.released_at IS NULL
      AND lims.can_access_project(s.project_id)
  );
END;
$$;

ALTER FUNCTION lims.can_access_labware(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.can_access_labware(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.can_access_inventory_item(p_inventory_item_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
BEGIN
  IF p_inventory_item_id IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN lims.has_role('app_admin') OR lims.has_role('app_operator');
END;
$$;

ALTER FUNCTION lims.can_access_inventory_item(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.can_access_inventory_item(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.can_access_storage_sublocation(p_sublocation_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
BEGIN
  IF p_sublocation_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.labware lw
    WHERE lw.current_storage_sublocation_id = p_sublocation_id
      AND lims.can_access_labware(lw.id)
  );
END;
$$;

ALTER FUNCTION lims.can_access_storage_sublocation(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.can_access_storage_sublocation(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.can_access_storage_unit(p_unit_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
BEGIN
  IF p_unit_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.storage_sublocations ss
    WHERE ss.unit_id = p_unit_id
      AND lims.can_access_storage_sublocation(ss.id)
  );
END;
$$;

ALTER FUNCTION lims.can_access_storage_unit(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.can_access_storage_unit(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.can_access_storage_facility(p_facility_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
BEGIN
  IF p_facility_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.storage_units su
    WHERE su.facility_id = p_facility_id
      AND lims.can_access_storage_unit(su.id)
  );
END;
$$;

ALTER FUNCTION lims.can_access_storage_facility(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.can_access_storage_facility(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Policy adjustments for project-scoped visibility
-------------------------------------------------------------------------------

DROP POLICY IF EXISTS p_labware_select_researcher ON lims.labware;
CREATE POLICY p_labware_select_researcher
ON lims.labware
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR lims.can_access_labware(id)
);

DROP POLICY IF EXISTS p_labware_positions_select_researcher ON lims.labware_positions;
CREATE POLICY p_labware_positions_select_researcher
ON lims.labware_positions
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR lims.can_access_labware(labware_id)
);

DROP POLICY IF EXISTS p_sample_derivations_select_researcher ON lims.sample_derivations;
CREATE POLICY p_sample_derivations_select_researcher
ON lims.sample_derivations
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR lims.can_access_sample(parent_sample_id)
  OR lims.can_access_sample(child_sample_id)
);

DROP POLICY IF EXISTS p_custody_events_select_researcher ON lims.custody_events;
CREATE POLICY p_custody_events_select_researcher
ON lims.custody_events
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR lims.can_access_sample(sample_id)
);

DROP POLICY IF EXISTS p_sample_labware_assign_select_researcher ON lims.sample_labware_assignments;
CREATE POLICY p_sample_labware_assign_select_researcher
ON lims.sample_labware_assignments
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR lims.can_access_sample(sample_id)
);

DROP POLICY IF EXISTS p_labware_location_history_select_researcher ON lims.labware_location_history;
CREATE POLICY p_labware_location_history_select_researcher
ON lims.labware_location_history
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR lims.can_access_labware(labware_id)
);

DROP POLICY IF EXISTS p_inventory_items_select_researcher ON lims.inventory_items;
DROP POLICY IF EXISTS p_inventory_transactions_select_researcher ON lims.inventory_transactions;

CREATE POLICY p_inventory_items_select_ops
ON lims.inventory_items
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
);

CREATE POLICY p_inventory_transactions_select_ops
ON lims.inventory_transactions
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
);

DROP POLICY IF EXISTS p_storage_facilities_select_auth ON lims.storage_facilities;
CREATE POLICY p_storage_facilities_select_auth
ON lims.storage_facilities
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR lims.can_access_storage_facility(id)
);

DROP POLICY IF EXISTS p_storage_units_select_auth ON lims.storage_units;
CREATE POLICY p_storage_units_select_auth
ON lims.storage_units
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR lims.can_access_storage_unit(id)
);

DROP POLICY IF EXISTS p_storage_sublocations_select_auth ON lims.storage_sublocations;
CREATE POLICY p_storage_sublocations_select_auth
ON lims.storage_sublocations
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR lims.can_access_storage_sublocation(id)
);

-------------------------------------------------------------------------------
-- Tighten privileges for inventory tables
-------------------------------------------------------------------------------

REVOKE SELECT ON lims.inventory_items FROM app_auth;
REVOKE SELECT ON lims.inventory_transactions FROM app_auth;
GRANT SELECT ON lims.inventory_items TO app_admin, app_operator;
GRANT SELECT ON lims.inventory_transactions TO app_admin, app_operator;

-- migrate:down

GRANT SELECT ON lims.inventory_items TO app_auth;
GRANT SELECT ON lims.inventory_transactions TO app_auth;
REVOKE SELECT ON lims.inventory_items FROM app_admin, app_operator;
REVOKE SELECT ON lims.inventory_transactions FROM app_admin, app_operator;

DROP POLICY IF EXISTS p_storage_sublocations_select_auth ON lims.storage_sublocations;
CREATE POLICY p_storage_sublocations_select_auth
ON lims.storage_sublocations
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_storage_units_select_auth ON lims.storage_units;
CREATE POLICY p_storage_units_select_auth
ON lims.storage_units
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_storage_facilities_select_auth ON lims.storage_facilities;
CREATE POLICY p_storage_facilities_select_auth
ON lims.storage_facilities
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_inventory_transactions_select_ops ON lims.inventory_transactions;
CREATE POLICY p_inventory_transactions_select_researcher
ON lims.inventory_transactions
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_inventory_items_select_ops ON lims.inventory_items;
CREATE POLICY p_inventory_items_select_researcher
ON lims.inventory_items
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_labware_location_history_select_researcher ON lims.labware_location_history;
CREATE POLICY p_labware_location_history_select_researcher
ON lims.labware_location_history
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_sample_labware_assign_select_researcher ON lims.sample_labware_assignments;
CREATE POLICY p_sample_labware_assign_select_researcher
ON lims.sample_labware_assignments
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_custody_events_select_researcher ON lims.custody_events;
CREATE POLICY p_custody_events_select_researcher
ON lims.custody_events
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_sample_derivations_select_researcher ON lims.sample_derivations;
CREATE POLICY p_sample_derivations_select_researcher
ON lims.sample_derivations
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_labware_positions_select_researcher ON lims.labware_positions;
CREATE POLICY p_labware_positions_select_researcher
ON lims.labware_positions
FOR SELECT
TO app_auth
USING (TRUE);

DROP POLICY IF EXISTS p_labware_select_researcher ON lims.labware;
CREATE POLICY p_labware_select_researcher
ON lims.labware
FOR SELECT
TO app_auth
USING (TRUE);

DROP FUNCTION IF EXISTS lims.can_access_storage_facility(uuid);
DROP FUNCTION IF EXISTS lims.can_access_storage_unit(uuid);
DROP FUNCTION IF EXISTS lims.can_access_storage_sublocation(uuid);
DROP FUNCTION IF EXISTS lims.can_access_inventory_item(uuid);
DROP FUNCTION IF EXISTS lims.can_access_labware(uuid);
DROP FUNCTION IF EXISTS lims.can_access_sample(uuid);
