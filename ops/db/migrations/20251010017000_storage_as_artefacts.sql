-- migrate:up
-------------------------------------------------------------------------------
-- Generalise storage into provenance graph (artefacts + relationships)
--
-- - Represent storage locations as artefacts (type_keys: storage_facility,
--   storage_unit, storage_sublocation, storage_virtual, storage_external)
-- - Use artefact_relationships (relationship_type = 'located_in') to model
--   both the storage hierarchy and current location of artefacts/labware
-- - Replace storage helpers/views to operate on the graph
-- - Drop explicit storage tables/events
-------------------------------------------------------------------------------

-- avoid altering session search_path to keep dbmate happy

-- 1) Ensure storage artefact types exist (kind 'other' so labware views ignore)
INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata)
VALUES
  ('storage_facility',   'Storage Facility',   'other', 'Top-level physical facility',   jsonb_build_object('storage_level','facility')),
  ('storage_unit',       'Storage Unit',       'other', 'Building, room or lab unit',    jsonb_build_object('storage_level','unit')),
  ('storage_sublocation','Storage Sublocation','other', 'Rack, freezer, shelf, drawer', jsonb_build_object('storage_level','sublocation')),
  ('storage_virtual',    'Storage Virtual',    'other', 'Virtual storage location',      jsonb_build_object('storage_level','virtual')),
  ('storage_external',   'Storage External',   'other', 'External partner storage',      jsonb_build_object('storage_level','external'))
ON CONFLICT (type_key) DO NOTHING;

-- 2) Map existing storage_nodes to storage artefacts
DO $$
DECLARE
  v_facility uuid := (SELECT artefact_type_id FROM app_provenance.artefact_types WHERE type_key = 'storage_facility');
  v_unit uuid     := (SELECT artefact_type_id FROM app_provenance.artefact_types WHERE type_key = 'storage_unit');
  v_sub uuid      := (SELECT artefact_type_id FROM app_provenance.artefact_types WHERE type_key = 'storage_sublocation');
  v_virt uuid     := (SELECT artefact_type_id FROM app_provenance.artefact_types WHERE type_key = 'storage_virtual');
  v_ext uuid      := (SELECT artefact_type_id FROM app_provenance.artefact_types WHERE type_key = 'storage_external');
BEGIN
  -- Create a temp mapping table for this migration
  CREATE TEMP TABLE IF NOT EXISTS tmp_storage_node_map (
    storage_node_id uuid PRIMARY KEY,
    artefact_id uuid NOT NULL
  ) ON COMMIT DROP;

  WITH ins AS (
    INSERT INTO app_provenance.artefacts (
      artefact_type_id, name, external_identifier, description, status, is_virtual, metadata
    )
    SELECT
      CASE sn.node_type
        WHEN 'facility'   THEN v_facility
        WHEN 'unit'       THEN v_unit
        WHEN 'sublocation' THEN v_sub
        WHEN 'virtual'    THEN v_virt
        ELSE v_ext
      END AS artefact_type_id,
      sn.display_name AS name,
      sn.node_key     AS external_identifier,
      sn.description,
      CASE WHEN sn.is_active THEN 'active' ELSE 'retired' END AS status,
      false AS is_virtual,
      coalesce(sn.metadata, '{}'::jsonb)
        || jsonb_build_object(
             'storage', true,
             'storage_level', sn.node_type,
             'barcode', sn.barcode,
             'environment', coalesce(sn.environment, '{}'::jsonb)
           ) AS metadata
    FROM app_provenance.storage_nodes sn
    RETURNING artefact_id, external_identifier
  )
  INSERT INTO tmp_storage_node_map (storage_node_id, artefact_id)
  SELECT sn.storage_node_id, i.artefact_id
  FROM app_provenance.storage_nodes sn
  JOIN ins i ON i.external_identifier = sn.node_key;

  -- Storage hierarchy relationships (storage -> storage)
  INSERT INTO app_provenance.artefact_relationships (
    parent_artefact_id, child_artefact_id, relationship_type, metadata
  )
  SELECT
    parent_map.artefact_id,
    child_map.artefact_id,
    'located_in',
    jsonb_build_object('source','migrate_storage_nodes')
  FROM app_provenance.storage_nodes child
  JOIN tmp_storage_node_map child_map ON child_map.storage_node_id = child.storage_node_id
  JOIN tmp_storage_node_map parent_map ON parent_map.storage_node_id = child.parent_storage_node_id
  ON CONFLICT DO NOTHING;

  -- Attach storage artefacts to their original scope
  INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata)
  SELECT map.artefact_id, sn.scope_id, 'facility', jsonb_build_object('source','migrate_storage_nodes')
  FROM app_provenance.storage_nodes sn
  JOIN tmp_storage_node_map map ON map.storage_node_id = sn.storage_node_id
  WHERE sn.scope_id IS NOT NULL
  ON CONFLICT DO NOTHING;

  -- Current artefact locations from latest storage events (if any)
  WITH latest_event AS (
    SELECT DISTINCT ON (ase.artefact_id)
      ase.artefact_id,
      ase.event_type,
      ase.occurred_at,
      ase.to_storage_node_id
    FROM app_provenance.artefact_storage_events ase
    ORDER BY ase.artefact_id, ase.occurred_at DESC
  )
  INSERT INTO app_provenance.artefact_relationships (
    parent_artefact_id, child_artefact_id, relationship_type, metadata
  )
  SELECT
    map.artefact_id AS parent_artefact_id,
    le.artefact_id  AS child_artefact_id,
    'located_in'    AS relationship_type,
    jsonb_build_object('source','migrate_storage_events','last_event_type', le.event_type, 'last_event_at', le.occurred_at)
  FROM latest_event le
  JOIN tmp_storage_node_map map ON map.storage_node_id = le.to_storage_node_id
  WHERE le.to_storage_node_id IS NOT NULL
    AND le.event_type NOT IN ('check_out','disposed')
  ON CONFLICT DO NOTHING;
END $$;

-------------------------------------------------------------------------------
-- 3) Replace helpers and views to operate on storage-as-artefacts
-------------------------------------------------------------------------------

-- can_access_storage_node now expects a storage artefact id
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
BEGIN
  IF p_storage_node_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_security.session_has_role('app_admin') THEN
    RETURN true;
  END IF;

  -- If no explicit scope is linked to the storage artefact, allow read
  IF NOT EXISTS (
    SELECT 1 FROM app_provenance.artefact_scopes s WHERE s.artefact_id = p_storage_node_id
  ) THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM app_provenance.artefact_scopes s
    WHERE s.artefact_id = p_storage_node_id
      AND app_security.actor_has_scope(s.scope_id, p_required_roles)
  );
END;
$$;

-- Current location view derived from 'located_in' relationships
CREATE OR REPLACE VIEW app_provenance.v_artefact_current_location AS
SELECT
  rel.child_artefact_id AS artefact_id,
  rel.parent_artefact_id AS storage_node_id,
  parent.name AS storage_display_name,
  coalesce(parent.metadata->>'storage_level','sublocation') AS node_type,
  (SELECT s.scope_id
     FROM app_provenance.artefact_scopes s
    WHERE s.artefact_id = parent.artefact_id
    ORDER BY CASE s.relationship WHEN 'primary' THEN 0 ELSE 1 END, s.assigned_at DESC
    LIMIT 1) AS scope_id,
  COALESCE(parent.metadata->'environment', '{}'::jsonb) AS environment,
  NULL::text AS last_event_type,
  NULL::timestamptz AS last_event_at
FROM app_provenance.artefact_relationships rel
JOIN app_provenance.artefacts parent ON parent.artefact_id = rel.parent_artefact_id
WHERE rel.relationship_type = 'located_in';

-- Path helper: ascend 'located_in' to build a human-readable path
CREATE OR REPLACE FUNCTION app_provenance.storage_path(p_storage_node_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SET search_path = pg_catalog, public, app_provenance
AS $$
WITH RECURSIVE ascend AS (
  SELECT a.artefact_id, a.name, 1 AS depth
  FROM app_provenance.artefacts a
  WHERE a.artefact_id = p_storage_node_id
  UNION ALL
  SELECT parent.artefact_id, parent.name, depth + 1
  FROM app_provenance.artefact_relationships r
  JOIN app_provenance.artefacts parent ON parent.artefact_id = r.parent_artefact_id
  JOIN ascend child ON child.artefact_id = r.child_artefact_id
  WHERE r.relationship_type = 'located_in'
)
SELECT string_agg(name, ' / ' ORDER BY depth DESC) FROM ascend;
$$;

-------------------------------------------------------------------------------
-- Storage tree over storage artefact hierarchy
-------------------------------------------------------------------------------
CREATE OR REPLACE VIEW app_core.v_storage_tree AS
WITH storage_nodes AS (
  SELECT a.artefact_id AS node_id, a.name AS display_name, at.type_key,
         coalesce(a.metadata->>'storage_level','sublocation') AS node_type
  FROM app_provenance.artefacts a
  JOIN app_provenance.artefact_types at ON at.artefact_type_id = a.artefact_type_id
  WHERE at.type_key IN ('storage_facility','storage_unit','storage_sublocation','storage_virtual','storage_external')
)
SELECT
  facility.node_id AS facility_id,
  facility.display_name AS facility_name,
  unit.node_id AS unit_id,
  unit.display_name AS unit_name,
  node.node_type AS storage_type,
  CASE WHEN node.node_type = 'sublocation' THEN node.node_id ELSE NULL END AS sublocation_id,
  CASE WHEN node.node_type = 'sublocation' THEN node.display_name ELSE NULL END AS sublocation_name,
  CASE WHEN node.node_type = 'sublocation' THEN (
    SELECT r.parent_artefact_id
    FROM app_provenance.artefact_relationships r
    WHERE r.child_artefact_id = node.node_id AND r.relationship_type='located_in'
    LIMIT 1
  ) ELSE NULL END AS parent_sublocation_id,
  NULL::integer AS capacity,
  app_provenance.storage_path(node.node_id) AS storage_path,
  COALESCE(metrics.labware_count, 0) AS labware_count,
  COALESCE(metrics.sample_count, 0) AS sample_count
FROM storage_nodes node
LEFT JOIN LATERAL (
  -- Count artefacts currently located anywhere under this node
  WITH RECURSIVE descend(node_id) AS (
    SELECT node.node_id
    UNION ALL
    SELECT r.child_artefact_id
    FROM app_provenance.artefact_relationships r
    JOIN storage_nodes s ON s.node_id = r.child_artefact_id
    JOIN descend d ON d.node_id = r.parent_artefact_id
    WHERE r.relationship_type='located_in'
  )
  SELECT
    COUNT(DISTINCT CASE WHEN at.kind = 'container' THEN loc.artefact_id END) AS labware_count,
    COUNT(DISTINCT CASE WHEN at.kind = 'material' THEN loc.artefact_id END) AS sample_count
  FROM descend d
  JOIN app_provenance.v_artefact_current_location loc ON loc.storage_node_id = d.node_id
  JOIN app_provenance.artefacts art ON art.artefact_id = loc.artefact_id
  JOIN app_provenance.artefact_types at ON at.artefact_type_id = art.artefact_type_id
  WHERE app_provenance.can_access_artefact(art.artefact_id)
) AS metrics ON TRUE
LEFT JOIN LATERAL (
  -- Nearest facility ancestor
  WITH RECURSIVE ascend(node_id, node_type, display_name) AS (
    SELECT node.node_id, node.node_type, node.display_name
    UNION ALL
    SELECT s.node_id, s.node_type, s.display_name
    FROM app_provenance.artefact_relationships r
    JOIN storage_nodes s ON s.node_id = r.parent_artefact_id
    JOIN ascend a ON a.node_id = r.child_artefact_id
    WHERE r.relationship_type='located_in'
  )
  SELECT node_id, display_name
  FROM ascend
  WHERE node_type = 'facility'
  ORDER BY CASE WHEN node_id = node.node_id THEN 0 ELSE 1 END
  LIMIT 1
) AS facility(node_id, display_name) ON TRUE
LEFT JOIN LATERAL (
  -- Nearest unit ancestor
  WITH RECURSIVE ascend(node_id, node_type, display_name) AS (
    SELECT node.node_id, node.node_type, node.display_name
    UNION ALL
    SELECT s.node_id, s.node_type, s.display_name
    FROM app_provenance.artefact_relationships r
    JOIN storage_nodes s ON s.node_id = r.parent_artefact_id
    JOIN ascend a ON a.node_id = r.child_artefact_id
    WHERE r.relationship_type='located_in'
  )
  SELECT node_id, display_name
  FROM ascend
  WHERE node_type = 'unit'
  ORDER BY CASE WHEN node_id = node.node_id THEN 0 ELSE 1 END
  LIMIT 1
) AS unit(node_id, display_name) ON TRUE
WHERE (metrics.labware_count IS NOT NULL OR metrics.sample_count IS NOT NULL)
   OR app_provenance.can_access_storage_node(node.node_id);

GRANT SELECT ON app_core.v_storage_tree TO app_auth;

-------------------------------------------------------------------------------
-- 4) Drop now-redundant storage tables and helpers that used them
-------------------------------------------------------------------------------

-- Replace view first so dependent objects are updated, then drop tables
DROP FUNCTION IF EXISTS app_provenance.sp_record_storage_event(jsonb);

DROP TABLE IF EXISTS app_provenance.artefact_storage_events;
DROP TABLE IF EXISTS app_provenance.storage_nodes;

-- migrate:down
DO $$ BEGIN
  RAISE EXCEPTION 'Irreversible migration: storage-as-artefacts refactor';
END $$;
