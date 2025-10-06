-- migrate:up

-------------------------------------------------------------------------------
-- Shared helper
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION lims.storage_location_path(p_sublocation_id uuid)
RETURNS text
LANGUAGE sql
STABLE
AS $$
WITH RECURSIVE sublocation_chain AS (
  SELECT
    ss.id,
    ss.name,
    ss.parent_sublocation_id,
    ss.unit_id,
    1 AS depth
  FROM lims.storage_sublocations ss
  WHERE ss.id = p_sublocation_id
  UNION ALL
  SELECT
    parent.id,
    parent.name,
    parent.parent_sublocation_id,
    parent.unit_id,
    child.depth + 1
  FROM lims.storage_sublocations parent
  JOIN sublocation_chain child ON child.parent_sublocation_id = parent.id
),
ordered_sublocations AS (
  SELECT name
  FROM sublocation_chain
  ORDER BY depth DESC
),
unit_info AS (
  SELECT su.id, su.name, su.facility_id
  FROM lims.storage_units su
  WHERE su.id = (
    SELECT unit_id
    FROM sublocation_chain
    ORDER BY depth DESC
    LIMIT 1
  )
),
facility_info AS (
  SELECT sf.id, sf.name
  FROM lims.storage_facilities sf
  WHERE sf.id = (
    SELECT facility_id
    FROM unit_info
    LIMIT 1
  )
)
SELECT CASE
  WHEN p_sublocation_id IS NULL THEN NULL
  ELSE trim(
    BOTH ' → '
    FROM concat_ws(
      ' → ',
      (SELECT name FROM facility_info),
      (SELECT name FROM unit_info),
      (
        SELECT string_agg(name, ' → ')
        FROM ordered_sublocations
      )
    )
  )
END;
$$;

ALTER FUNCTION lims.storage_location_path(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.storage_location_path(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Views powering provenance and location exploration
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW lims.v_sample_lineage
WITH (security_invoker = true)
AS
SELECT
  sd.parent_sample_id,
  parent_sample.name AS parent_sample_name,
  parent_sample.sample_type_code AS parent_sample_type_code,
  parent_sample.project_id AS parent_project_id,
  parent_sample.current_labware_id AS parent_labware_id,
  parent_labware.barcode AS parent_labware_barcode,
  parent_labware.display_name AS parent_labware_name,
  lims.storage_location_path(parent_labware.current_storage_sublocation_id) AS parent_storage_path,
  sd.child_sample_id,
  child_sample.name AS child_sample_name,
  child_sample.sample_type_code AS child_sample_type_code,
  child_sample.project_id AS child_project_id,
  child_sample.current_labware_id AS child_labware_id,
  child_labware.barcode AS child_labware_barcode,
  child_labware.display_name AS child_labware_name,
  lims.storage_location_path(child_labware.current_storage_sublocation_id) AS child_storage_path,
  sd.method,
  sd.created_at,
  sd.created_by
FROM lims.sample_derivations sd
JOIN lims.samples parent_sample ON parent_sample.id = sd.parent_sample_id
JOIN lims.samples child_sample ON child_sample.id = sd.child_sample_id
LEFT JOIN lims.labware parent_labware ON parent_labware.id = parent_sample.current_labware_id
LEFT JOIN lims.labware child_labware ON child_labware.id = child_sample.current_labware_id;

GRANT SELECT ON lims.v_sample_lineage TO app_auth;

CREATE OR REPLACE VIEW lims.v_sample_labware_history
WITH (security_invoker = true)
AS
SELECT
  sla.sample_id,
  s.name AS sample_name,
  sla.labware_id,
  lw.barcode AS labware_barcode,
  lw.display_name AS labware_name,
  sla.labware_position_id,
  lp.position_label,
  sla.assigned_at,
  sla.released_at,
  lw.current_storage_sublocation_id,
  lims.storage_location_path(lw.current_storage_sublocation_id) AS current_storage_path
FROM lims.sample_labware_assignments sla
JOIN lims.samples s ON s.id = sla.sample_id
JOIN lims.labware lw ON lw.id = sla.labware_id
LEFT JOIN lims.labware_positions lp ON lp.id = sla.labware_position_id;

GRANT SELECT ON lims.v_sample_labware_history TO app_auth;

CREATE OR REPLACE VIEW lims.v_labware_inventory
WITH (security_invoker = true)
AS
SELECT
  lw.id AS labware_id,
  lw.barcode,
  lw.display_name,
  lw.status,
  lt.name AS labware_type,
  lw.current_storage_sublocation_id,
  lims.storage_location_path(lw.current_storage_sublocation_id) AS storage_path,
  COALESCE(active_samples.sample_count, 0) AS active_sample_count,
  COALESCE(active_samples.samples, '[]'::jsonb) AS active_samples
FROM lims.labware lw
LEFT JOIN lims.labware_types lt ON lt.id = lw.labware_type_id
LEFT JOIN LATERAL (
  SELECT
    COUNT(DISTINCT sla.sample_id) AS sample_count,
    jsonb_agg(
      DISTINCT jsonb_build_object(
        'sample_id', s.id,
        'sample_name', s.name,
        'sample_status', s.sample_status
      )
    ) FILTER (WHERE sla.sample_id IS NOT NULL) AS samples
  FROM lims.sample_labware_assignments sla
  JOIN lims.samples s ON s.id = sla.sample_id
  WHERE sla.labware_id = lw.id
    AND sla.released_at IS NULL
) active_samples ON TRUE;

GRANT SELECT ON lims.v_labware_inventory TO app_auth;

CREATE OR REPLACE VIEW lims.v_storage_tree
WITH (security_invoker = true)
AS
SELECT
  sf.id AS facility_id,
  sf.name AS facility_name,
  su.id AS unit_id,
  su.name AS unit_name,
  su.storage_type,
  ss.id AS sublocation_id,
  ss.name AS sublocation_name,
  ss.parent_sublocation_id,
  ss.capacity,
  lims.storage_location_path(ss.id) AS storage_path,
  COALESCE(labware_stats.labware_count, 0) AS labware_count,
  COALESCE(labware_stats.sample_count, 0) AS sample_count
FROM lims.storage_facilities sf
JOIN lims.storage_units su ON su.facility_id = sf.id
LEFT JOIN lims.storage_sublocations ss ON ss.unit_id = su.id
LEFT JOIN LATERAL (
  SELECT
    COUNT(DISTINCT lw.id) AS labware_count,
    COUNT(DISTINCT sla.sample_id) FILTER (WHERE sla.released_at IS NULL) AS sample_count
  FROM lims.labware lw
  LEFT JOIN lims.sample_labware_assignments sla
    ON sla.labware_id = lw.id
  WHERE lw.current_storage_sublocation_id = ss.id
) labware_stats ON TRUE;

GRANT SELECT ON lims.v_storage_tree TO app_auth;

-------------------------------------------------------------------------------
-- Targeted RPC helpers for UI explorers
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION lims.get_sample_network(p_sample_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
WITH RECURSIVE target_sample AS (
  SELECT
    s.id,
    s.name,
    s.sample_type_code,
    s.sample_status,
    s.project_id,
    s.current_labware_id,
    lab.id AS labware_id,
    lab.barcode AS labware_barcode,
    lab.display_name AS labware_name,
    lims.storage_location_path(lab.current_storage_sublocation_id) AS storage_path
  FROM lims.samples s
  LEFT JOIN lims.labware lab ON lab.id = s.current_labware_id
  WHERE s.id = p_sample_id
),
ancestor_tree AS (
  SELECT
    sd.parent_sample_id AS sample_id,
    sd.child_sample_id,
    sd.method,
    1 AS depth
  FROM lims.sample_derivations sd
  WHERE sd.child_sample_id = p_sample_id
  UNION ALL
  SELECT
    sd.parent_sample_id,
    sd.child_sample_id,
    sd.method,
    at.depth + 1
  FROM lims.sample_derivations sd
  JOIN ancestor_tree at ON at.sample_id = sd.child_sample_id
),
ancestor_payload AS (
  SELECT
    at.sample_id,
    at.child_sample_id,
    at.method,
    at.depth,
    s.name,
    s.sample_type_code,
    s.sample_status,
    s.project_id,
    lab.id AS labware_id,
    lab.barcode AS labware_barcode,
    lab.display_name AS labware_name,
    lims.storage_location_path(lab.current_storage_sublocation_id) AS storage_path
  FROM ancestor_tree at
  JOIN lims.samples s ON s.id = at.sample_id
  LEFT JOIN lims.labware lab ON lab.id = s.current_labware_id
),
descendant_tree AS (
  SELECT
    sd.parent_sample_id,
    sd.child_sample_id AS sample_id,
    sd.method,
    1 AS depth
  FROM lims.sample_derivations sd
  WHERE sd.parent_sample_id = p_sample_id
  UNION ALL
  SELECT
    sd.parent_sample_id,
    sd.child_sample_id,
    sd.method,
    dt.depth + 1
  FROM lims.sample_derivations sd
  JOIN descendant_tree dt ON dt.sample_id = sd.parent_sample_id
),
descendant_payload AS (
  SELECT
    dt.sample_id,
    dt.parent_sample_id,
    dt.method,
    dt.depth,
    s.name,
    s.sample_type_code,
    s.sample_status,
    s.project_id,
    lab.id AS labware_id,
    lab.barcode AS labware_barcode,
    lab.display_name AS labware_name,
    lims.storage_location_path(lab.current_storage_sublocation_id) AS storage_path
  FROM descendant_tree dt
  JOIN lims.samples s ON s.id = dt.sample_id
  LEFT JOIN lims.labware lab ON lab.id = s.current_labware_id
)
SELECT jsonb_build_object(
  'sample', (SELECT to_jsonb(target_sample) FROM target_sample),
  'ancestors', COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'sample_id', ap.sample_id,
          'name', ap.name,
          'sample_type_code', ap.sample_type_code,
          'sample_status', ap.sample_status,
          'project_id', ap.project_id,
          'labware', jsonb_build_object(
            'labware_id', ap.labware_id,
            'barcode', ap.labware_barcode,
            'display_name', ap.labware_name,
            'storage_path', ap.storage_path
          ),
          'child_sample_id', ap.child_sample_id,
          'method', ap.method,
          'depth', ap.depth
        )
        ORDER BY ap.depth, ap.sample_id
      )
      FROM ancestor_payload ap
    ),
    '[]'::jsonb
  ),
  'descendants', COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'sample_id', dp.sample_id,
          'name', dp.name,
          'sample_type_code', dp.sample_type_code,
          'sample_status', dp.sample_status,
          'project_id', dp.project_id,
          'labware', jsonb_build_object(
            'labware_id', dp.labware_id,
            'barcode', dp.labware_barcode,
            'display_name', dp.labware_name,
            'storage_path', dp.storage_path
          ),
          'parent_sample_id', dp.parent_sample_id,
          'method', dp.method,
          'depth', dp.depth
        )
        ORDER BY dp.depth, dp.sample_id
      )
      FROM descendant_payload dp
    ),
    '[]'::jsonb
  )
)
FROM target_sample;
$$;

ALTER FUNCTION lims.get_sample_network(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.get_sample_network(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION lims.get_labware_contents(p_labware_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
SELECT to_jsonb(labware_payload)
FROM (
  SELECT
    lw.id,
    lw.barcode,
    lw.display_name,
    lw.status,
    lt.name AS labware_type,
    lw.current_storage_sublocation_id,
    lims.storage_location_path(lw.current_storage_sublocation_id) AS storage_path,
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'sample_id', s.id,
            'sample_name', s.name,
            'sample_status', s.sample_status,
            'position_label', lp.position_label,
            'assigned_at', sla.assigned_at,
            'released_at', sla.released_at
          )
          ORDER BY sla.assigned_at DESC
        )
        FROM lims.sample_labware_assignments sla
        JOIN lims.samples s ON s.id = sla.sample_id
        LEFT JOIN lims.labware_positions lp ON lp.id = sla.labware_position_id
        WHERE sla.labware_id = lw.id
      ),
      '[]'::jsonb
    ) AS samples
  FROM lims.labware lw
  LEFT JOIN lims.labware_types lt ON lt.id = lw.labware_type_id
  WHERE lw.id = p_labware_id
) labware_payload;
$$;

ALTER FUNCTION lims.get_labware_contents(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.get_labware_contents(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-- migrate:down

REVOKE EXECUTE ON FUNCTION lims.get_labware_contents(uuid) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION lims.get_sample_network(uuid) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE SELECT ON lims.v_storage_tree FROM app_auth;
REVOKE SELECT ON lims.v_labware_inventory FROM app_auth;
REVOKE SELECT ON lims.v_sample_labware_history FROM app_auth;
REVOKE SELECT ON lims.v_sample_lineage FROM app_auth;
REVOKE EXECUTE ON FUNCTION lims.storage_location_path(uuid) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;

DROP FUNCTION IF EXISTS lims.get_labware_contents(uuid);
DROP FUNCTION IF EXISTS lims.get_sample_network(uuid);
DROP VIEW IF EXISTS lims.v_storage_tree;
DROP VIEW IF EXISTS lims.v_labware_inventory;
DROP VIEW IF EXISTS lims.v_sample_labware_history;
DROP VIEW IF EXISTS lims.v_sample_lineage;
DROP FUNCTION IF EXISTS lims.storage_location_path(uuid);
