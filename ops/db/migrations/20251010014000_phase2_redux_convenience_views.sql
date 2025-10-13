-- migrate:up
CREATE OR REPLACE FUNCTION app_provenance.storage_path(p_storage_node_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance
SET row_security = on
AS $$
DECLARE
  result text;
BEGIN
  IF p_storage_node_id IS NULL THEN
    RETURN NULL;
  END IF;

  WITH RECURSIVE path_nodes AS (
    SELECT
      sn.storage_node_id,
      sn.display_name,
      sn.parent_storage_node_id,
      1 AS depth
    FROM app_provenance.storage_nodes sn
    WHERE sn.storage_node_id = p_storage_node_id

    UNION ALL

    SELECT
      parent.storage_node_id,
      parent.display_name,
      parent.parent_storage_node_id,
      path_nodes.depth + 1
    FROM app_provenance.storage_nodes parent
    JOIN path_nodes
      ON path_nodes.parent_storage_node_id = parent.storage_node_id
  )
  SELECT string_agg(display_name, ' / ' ORDER BY depth DESC)
  INTO result
  FROM path_nodes;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.storage_path(uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Sample overview
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW app_core.v_sample_overview AS
SELECT
  sample.artefact_id AS id,
  sample.name,
  sample_type.type_key AS sample_type_code,
  sample.status AS sample_status,
  pi.started_at AS collected_at,
  project_scope.scope_id AS project_id,
  project_scope.scope_key AS project_code,
  project_scope.display_name AS project_name,
  lab_assoc.labware_id AS current_labware_id,
  lab_assoc.labware_barcode AS current_labware_barcode,
  lab_assoc.labware_name AS current_labware_name,
  COALESCE(lab_assoc.storage_path, app_provenance.storage_path(sample_loc.storage_node_id)) AS storage_path,
  derivatives.derivatives
FROM app_provenance.artefacts sample
JOIN app_provenance.artefact_types sample_type
  ON sample_type.artefact_type_id = sample.artefact_type_id
LEFT JOIN app_provenance.process_instances pi
  ON pi.process_instance_id = sample.origin_process_instance_id
LEFT JOIN app_provenance.v_artefact_current_location sample_loc
  ON sample_loc.artefact_id = sample.artefact_id
LEFT JOIN LATERAL (
  WITH RECURSIVE ascend AS (
    SELECT
      s.scope_id,
      s.scope_key,
      s.display_name,
      s.scope_type,
      s.parent_scope_id,
      0 AS depth
    FROM app_provenance.artefact_scopes sc
    JOIN app_security.scopes s
      ON s.scope_id = sc.scope_id
    WHERE sc.artefact_id = sample.artefact_id

    UNION ALL

    SELECT
      parent.scope_id,
      parent.scope_key,
      parent.display_name,
      parent.scope_type,
      parent.parent_scope_id,
      ascend.depth + 1
    FROM app_security.scopes parent
    JOIN ascend
      ON ascend.parent_scope_id = parent.scope_id
  )
  SELECT scope_id, scope_key, display_name
  FROM ascend
  WHERE scope_type = 'project'
  ORDER BY depth
  LIMIT 1
) AS project_scope ON TRUE
LEFT JOIN LATERAL (
  SELECT
    lab.artefact_id AS labware_id,
    lab.name AS labware_name,
    COALESCE(lab.metadata->>'barcode', lab.external_identifier) AS labware_barcode,
    app_provenance.storage_path(loc.storage_node_id) AS storage_path
  FROM app_provenance.artefacts lab
  LEFT JOIN app_provenance.v_artefact_current_location loc
    ON loc.artefact_id = lab.artefact_id
  WHERE lab.artefact_id = sample.container_artefact_id
  LIMIT 1
) AS lab_assoc ON TRUE
LEFT JOIN LATERAL (
  SELECT jsonb_agg(
           jsonb_build_object(
             'artefact_id', child.artefact_id,
             'name', child.name,
             'relationship_type', rel.relationship_type
           )
           ORDER BY child.name
         ) AS derivatives
  FROM app_provenance.artefact_relationships rel
  JOIN app_provenance.artefacts child
    ON child.artefact_id = rel.child_artefact_id
  JOIN app_provenance.artefact_types child_type
    ON child_type.artefact_type_id = child.artefact_type_id
  WHERE rel.parent_artefact_id = sample.artefact_id
    AND child_type.kind = 'material'
    AND app_provenance.can_access_artefact(child.artefact_id)
) AS derivatives ON TRUE
WHERE sample_type.kind = 'material'
  AND app_provenance.can_access_artefact(sample.artefact_id);

GRANT SELECT ON app_core.v_sample_overview TO app_auth;

-------------------------------------------------------------------------------
-- Labware contents
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW app_core.v_labware_contents AS
SELECT
  lab.artefact_id AS labware_id,
  COALESCE(lab.metadata->>'barcode', lab.external_identifier) AS barcode,
  lab.name AS display_name,
  lab.status,
  COALESCE(slot.display_name, slot.slot_name) AS position_label,
  sample.artefact_id AS sample_id,
  sample.name AS sample_name,
  sample.status AS sample_status,
  sample.quantity AS volume,
  sample.quantity_unit AS volume_unit,
  loc.storage_node_id AS current_storage_sublocation_id,
  app_provenance.storage_path(loc.storage_node_id) AS storage_path
FROM app_provenance.artefacts lab
JOIN app_provenance.artefact_types lab_type
  ON lab_type.artefact_type_id = lab.artefact_type_id
LEFT JOIN app_provenance.container_slots slot
  ON slot.container_artefact_id = lab.artefact_id
LEFT JOIN app_provenance.artefacts sample
  ON sample.container_slot_id = slot.container_slot_id
 AND sample.container_artefact_id = lab.artefact_id
LEFT JOIN app_provenance.v_artefact_current_location loc
  ON loc.artefact_id = lab.artefact_id
WHERE lab_type.kind = 'container'
  AND app_provenance.can_access_artefact(lab.artefact_id);

GRANT SELECT ON app_core.v_labware_contents TO app_auth;

-------------------------------------------------------------------------------
-- Labware inventory summary
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW app_core.v_labware_inventory AS
WITH labware_samples AS (
  SELECT
    a.container_artefact_id AS labware_id,
    a.artefact_id AS sample_id
  FROM app_provenance.artefacts a
  WHERE a.container_artefact_id IS NOT NULL
)
SELECT
  lab.artefact_id AS labware_id,
  COALESCE(lab.metadata->>'barcode', lab.external_identifier) AS barcode,
  lab.name AS display_name,
  lab.status,
  lab_type.type_key AS labware_type,
  loc.storage_node_id AS current_storage_sublocation_id,
  app_provenance.storage_path(loc.storage_node_id) AS storage_path,
  COUNT(DISTINCT ls.sample_id) AS active_sample_count,
  CASE
    WHEN COUNT(ls.sample_id) = 0 THEN NULL
    ELSE jsonb_agg(
      DISTINCT jsonb_build_object(
        'sample_id', sample.artefact_id,
        'sample_name', sample.name,
        'sample_status', sample.status
      )
    )
  END AS active_samples
FROM app_provenance.artefacts lab
JOIN app_provenance.artefact_types lab_type
  ON lab_type.artefact_type_id = lab.artefact_type_id
LEFT JOIN labware_samples ls
  ON ls.labware_id = lab.artefact_id
LEFT JOIN app_provenance.artefacts sample
  ON sample.artefact_id = ls.sample_id
LEFT JOIN app_provenance.v_artefact_current_location loc
  ON loc.artefact_id = lab.artefact_id
WHERE lab_type.kind = 'container'
  AND app_provenance.can_access_artefact(lab.artefact_id)
GROUP BY
  lab.artefact_id,
  lab.metadata,
  lab.external_identifier,
  lab.name,
  lab.status,
  lab_type.type_key,
  loc.storage_node_id;

GRANT SELECT ON app_core.v_labware_inventory TO app_auth;

-------------------------------------------------------------------------------
-- Inventory status (reagents / consumables)
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW app_core.v_inventory_status AS
SELECT
  reagent.artefact_id AS id,
  reagent.name,
  COALESCE(reagent.metadata->>'barcode', reagent.external_identifier) AS barcode,
  COALESCE(reagent.quantity, 0::numeric) AS quantity,
  reagent.quantity_unit AS unit,
  CASE
    WHEN reagent.metadata ? 'minimum_quantity'
      AND (reagent.metadata->>'minimum_quantity') ~ '^-?[0-9]+(\\.[0-9]+)?$'
    THEN (reagent.metadata->>'minimum_quantity')::numeric
    ELSE NULL
  END AS minimum_quantity,
  CASE
    WHEN reagent.quantity IS NULL THEN false
    WHEN reagent.metadata ? 'minimum_quantity'
      AND (reagent.metadata->>'minimum_quantity') ~ '^-?[0-9]+(\\.[0-9]+)?$'
    THEN reagent.quantity < (reagent.metadata->>'minimum_quantity')::numeric
    ELSE false
  END AS below_threshold,
  CASE
    WHEN reagent.metadata ? 'expires_at' THEN (reagent.metadata->>'expires_at')::timestamptz
    ELSE NULL
  END AS expires_at,
  loc.storage_node_id AS storage_sublocation_id,
  app_provenance.storage_path(loc.storage_node_id) AS storage_path
FROM app_provenance.artefacts reagent
JOIN app_provenance.artefact_types reagent_type
  ON reagent_type.artefact_type_id = reagent.artefact_type_id
LEFT JOIN app_provenance.v_artefact_current_location loc
  ON loc.artefact_id = reagent.artefact_id
WHERE reagent_type.kind = 'reagent'
  AND app_provenance.can_access_artefact(reagent.artefact_id);

GRANT SELECT ON app_core.v_inventory_status TO app_auth;

-------------------------------------------------------------------------------
-- Sample lineage
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW app_core.v_sample_lineage AS
SELECT
  parent.artefact_id AS parent_sample_id,
  parent.name AS parent_sample_name,
  parent_type.type_key AS parent_sample_type_code,
  parent_project.scope_id AS parent_project_id,
  lab_parent.labware_id AS parent_labware_id,
  lab_parent.labware_barcode AS parent_labware_barcode,
  lab_parent.labware_name AS parent_labware_name,
  lab_parent.storage_path AS parent_storage_path,
  child.artefact_id AS child_sample_id,
  child.name AS child_sample_name,
  child_type.type_key AS child_sample_type_code,
  child_project.scope_id AS child_project_id,
  lab_child.labware_id AS child_labware_id,
  lab_child.labware_barcode AS child_labware_barcode,
  lab_child.labware_name AS child_labware_name,
  lab_child.storage_path AS child_storage_path,
  rel.relationship_type AS method,
  pi.completed_at AS created_at,
  pi.executed_by::text AS created_by
FROM app_provenance.artefact_relationships rel
JOIN app_provenance.artefacts parent
  ON parent.artefact_id = rel.parent_artefact_id
JOIN app_provenance.artefact_types parent_type
  ON parent_type.artefact_type_id = parent.artefact_type_id
JOIN app_provenance.artefacts child
  ON child.artefact_id = rel.child_artefact_id
JOIN app_provenance.artefact_types child_type
  ON child_type.artefact_type_id = child.artefact_type_id
LEFT JOIN app_provenance.process_instances pi
  ON pi.process_instance_id = rel.process_instance_id
LEFT JOIN LATERAL (
  SELECT
    s.scope_id
  FROM app_provenance.artefact_scopes sc
  JOIN app_security.scopes s
    ON s.scope_id = sc.scope_id
  WHERE sc.artefact_id = parent.artefact_id
    AND s.scope_type = 'project'
  ORDER BY
    CASE sc.relationship WHEN 'primary' THEN 0 ELSE 1 END,
    sc.assigned_at DESC
  LIMIT 1
) AS parent_project ON TRUE
LEFT JOIN LATERAL (
  SELECT
    s.scope_id
  FROM app_provenance.artefact_scopes sc
  JOIN app_security.scopes s
    ON s.scope_id = sc.scope_id
  WHERE sc.artefact_id = child.artefact_id
    AND s.scope_type = 'project'
  ORDER BY
    CASE sc.relationship WHEN 'primary' THEN 0 ELSE 1 END,
    sc.assigned_at DESC
  LIMIT 1
) AS child_project ON TRUE
LEFT JOIN LATERAL (
  SELECT
    lab.artefact_id AS labware_id,
    COALESCE(lab.metadata->>'barcode', lab.external_identifier) AS labware_barcode,
    lab.name AS labware_name,
    app_provenance.storage_path(loc.storage_node_id) AS storage_path
  FROM app_provenance.artefacts lab
  LEFT JOIN app_provenance.v_artefact_current_location loc
    ON loc.artefact_id = lab.artefact_id
  WHERE lab.artefact_id = parent.container_artefact_id
  LIMIT 1
) AS lab_parent ON TRUE
LEFT JOIN LATERAL (
  SELECT
    lab.artefact_id AS labware_id,
    COALESCE(lab.metadata->>'barcode', lab.external_identifier) AS labware_barcode,
    lab.name AS labware_name,
    app_provenance.storage_path(loc.storage_node_id) AS storage_path
  FROM app_provenance.artefacts lab
  LEFT JOIN app_provenance.v_artefact_current_location loc
    ON loc.artefact_id = lab.artefact_id
  WHERE lab.artefact_id = child.container_artefact_id
  LIMIT 1
) AS lab_child ON TRUE
WHERE parent_type.kind = 'material'
  AND child_type.kind = 'material'
  AND app_provenance.can_access_artefact(parent.artefact_id)
  AND app_provenance.can_access_artefact(child.artefact_id);

GRANT SELECT ON app_core.v_sample_lineage TO app_auth;

-------------------------------------------------------------------------------
-- Project access overview
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW app_core.v_project_access_overview AS
WITH actor_project_roles AS (
  SELECT
    project.scope_id AS project_id,
    project.scope_key,
    project.display_name,
    project.depth
  FROM app_security.actor_scope_roles(app_security.current_actor_id()) ar
  JOIN LATERAL (
    WITH RECURSIVE ascend AS (
      SELECT
        s.scope_id,
        s.parent_scope_id,
        s.scope_type,
        s.scope_key,
        s.display_name,
        0 AS depth
      FROM app_security.scopes s
      WHERE s.scope_id = ar.scope_id

      UNION ALL

      SELECT
        parent.scope_id,
        parent.parent_scope_id,
        parent.scope_type,
        parent.scope_key,
        parent.display_name,
        ascend.depth + 1
      FROM app_security.scopes parent
      JOIN ascend
        ON ascend.parent_scope_id = parent.scope_id
    )
    SELECT scope_id, scope_key, display_name, depth
    FROM ascend
    WHERE scope_type = 'project'
    ORDER BY depth
    LIMIT 1
  ) AS project(scope_id, scope_key, display_name, depth) ON TRUE
)
, project_aggregates AS (
  SELECT
    project_id,
    MIN(scope_key) AS scope_key,
    MIN(display_name) AS display_name,
    BOOL_OR(depth = 0) AS has_direct_membership
  FROM actor_project_roles
  GROUP BY project_id
)
, sample_assignments AS (
  SELECT
    sample.artefact_id,
    sc.scope_id
  FROM app_provenance.artefact_scopes sc
  JOIN app_provenance.artefacts sample
    ON sample.artefact_id = sc.artefact_id
  JOIN app_provenance.artefact_types st
    ON st.artefact_type_id = sample.artefact_type_id
  WHERE st.kind = 'material'
    AND app_provenance.can_access_artefact(sample.artefact_id)
)
, sample_projects AS (
  SELECT DISTINCT
    sa.artefact_id,
    project.scope_id AS project_id
  FROM sample_assignments sa
  JOIN LATERAL (
    WITH RECURSIVE ascend AS (
      SELECT
        s.scope_id,
        s.parent_scope_id,
        s.scope_type,
        0 AS depth
      FROM app_security.scopes s
      WHERE s.scope_id = sa.scope_id

      UNION ALL

      SELECT
        parent.scope_id,
        parent.parent_scope_id,
        parent.scope_type,
        ascend.depth + 1
      FROM app_security.scopes parent
      JOIN ascend
        ON ascend.parent_scope_id = parent.scope_id
    )
    SELECT scope_id
    FROM ascend
    WHERE scope_type = 'project'
    ORDER BY depth
    LIMIT 1
  ) AS project(scope_id) ON TRUE
)
, sample_counts AS (
  SELECT project_id, COUNT(DISTINCT artefact_id) AS sample_count
  FROM sample_projects
  GROUP BY project_id
)
, labware_assignments AS (
  SELECT DISTINCT
    lab.artefact_id AS labware_id,
    sc.scope_id
  FROM app_provenance.artefacts sample
  JOIN app_provenance.artefact_types st
    ON st.artefact_type_id = sample.artefact_type_id
  JOIN app_provenance.artefacts lab
    ON lab.artefact_id = sample.container_artefact_id
  JOIN app_provenance.artefact_types lt
    ON lt.artefact_type_id = lab.artefact_type_id
  JOIN app_provenance.artefact_scopes sc
    ON sc.artefact_id = sample.artefact_id
  WHERE lt.kind = 'container'
    AND sample.container_artefact_id IS NOT NULL
    AND app_provenance.can_access_artefact(lab.artefact_id)
)
, labware_projects AS (
  SELECT DISTINCT
    la.labware_id,
    project.scope_id AS project_id
  FROM labware_assignments la
  JOIN LATERAL (
    WITH RECURSIVE ascend AS (
      SELECT
        s.scope_id,
        s.parent_scope_id,
        s.scope_type,
        0 AS depth
      FROM app_security.scopes s
      WHERE s.scope_id = la.scope_id

      UNION ALL

      SELECT
        parent.scope_id,
        parent.parent_scope_id,
        parent.scope_type,
        ascend.depth + 1
      FROM app_security.scopes parent
      JOIN ascend
        ON ascend.parent_scope_id = parent.scope_id
    )
    SELECT scope_id
    FROM ascend
    WHERE scope_type = 'project'
    ORDER BY depth
    LIMIT 1
  ) AS project(scope_id) ON TRUE
)
, labware_counts AS (
  SELECT project_id, COUNT(DISTINCT labware_id) AS labware_count
  FROM labware_projects
  GROUP BY project_id
)
, accessible_projects AS (
  SELECT project_id FROM project_aggregates
  UNION
  SELECT project_id FROM sample_counts
  UNION
  SELECT project_id FROM labware_counts
)
SELECT
  ap.project_id AS id,
  split_part(sc.scope_key, ':', 2) AS project_code,
  sc.display_name AS name,
  COALESCE(NULLIF(sc.description, ''), 'Project scope') AS description,
  COALESCE(agg.project_id IS NOT NULL, app_security.has_role('app_admin')) AS is_member,
  CASE
    WHEN agg.has_direct_membership THEN 'direct'
    WHEN agg.project_id IS NOT NULL THEN 'inherited'
    ELSE 'implicit'
  END AS access_via,
  COALESCE(samples.sample_count, 0) AS sample_count,
  COALESCE(labware.labware_count, 0) AS active_labware_count
FROM accessible_projects ap
JOIN app_security.scopes sc
  ON sc.scope_id = ap.project_id
LEFT JOIN project_aggregates agg
  ON agg.project_id = ap.project_id
LEFT JOIN sample_counts samples
  ON samples.project_id = ap.project_id
LEFT JOIN labware_counts labware
  ON labware.project_id = ap.project_id;

GRANT SELECT ON app_core.v_project_access_overview TO app_auth;

-------------------------------------------------------------------------------
-- Storage tree (facility / unit / sublocation)
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW app_core.v_storage_tree AS
SELECT
  facility.storage_node_id AS facility_id,
  facility.display_name AS facility_name,
  unit.storage_node_id AS unit_id,
  unit.display_name AS unit_name,
  node.node_type AS storage_type,
  CASE WHEN node.node_type = 'sublocation' THEN node.storage_node_id ELSE NULL END AS sublocation_id,
  CASE WHEN node.node_type = 'sublocation' THEN node.display_name ELSE NULL END AS sublocation_name,
  CASE WHEN node.node_type = 'sublocation' THEN node.parent_storage_node_id ELSE NULL END AS parent_sublocation_id,
  NULL::integer AS capacity,
  app_provenance.storage_path(node.storage_node_id) AS storage_path,
  COALESCE(metrics.labware_count, 0) AS labware_count,
  COALESCE(metrics.sample_count, 0) AS sample_count
FROM app_provenance.storage_nodes node
LEFT JOIN LATERAL (
  WITH RECURSIVE descend AS (
    SELECT node.storage_node_id
    UNION ALL
    SELECT child.storage_node_id
    FROM app_provenance.storage_nodes child
    JOIN descend ON child.parent_storage_node_id = descend.storage_node_id
  )
  SELECT
    COUNT(DISTINCT CASE WHEN at.kind = 'container' THEN loc.artefact_id END) AS labware_count,
    COUNT(DISTINCT CASE WHEN at.kind = 'material' THEN loc.artefact_id END) AS sample_count
  FROM descend d
  JOIN app_provenance.v_artefact_current_location loc
    ON loc.storage_node_id = d.storage_node_id
  JOIN app_provenance.artefacts art
    ON art.artefact_id = loc.artefact_id
  JOIN app_provenance.artefact_types at
    ON at.artefact_type_id = art.artefact_type_id
  WHERE app_provenance.can_access_artefact(art.artefact_id)
) AS metrics ON TRUE
LEFT JOIN LATERAL (
  WITH RECURSIVE ascend AS (
    SELECT node.storage_node_id, node.parent_storage_node_id, node.display_name, node.scope_id, node.node_type
    UNION ALL
    SELECT parent.storage_node_id, parent.parent_storage_node_id, parent.display_name, parent.scope_id, parent.node_type
    FROM app_provenance.storage_nodes parent
    JOIN ascend child ON child.parent_storage_node_id = parent.storage_node_id
  )
  SELECT storage_node_id, display_name, scope_id
  FROM ascend
  WHERE node_type = 'facility'
  ORDER BY CASE WHEN storage_node_id = node.storage_node_id THEN 0 ELSE 1 END
  LIMIT 1
) AS facility(storage_node_id, display_name, scope_id) ON TRUE
LEFT JOIN LATERAL (
  WITH RECURSIVE ascend AS (
    SELECT node.storage_node_id, node.parent_storage_node_id, node.display_name, node.node_type
    UNION ALL
    SELECT parent.storage_node_id, parent.parent_storage_node_id, parent.display_name, parent.node_type
    FROM app_provenance.storage_nodes parent
    JOIN ascend child ON child.parent_storage_node_id = parent.storage_node_id
  )
  SELECT storage_node_id, display_name
  FROM ascend
  WHERE node_type = 'unit'
  ORDER BY CASE WHEN storage_node_id = node.storage_node_id THEN 0 ELSE 1 END
  LIMIT 1
) AS unit(storage_node_id, display_name) ON TRUE
WHERE (metrics.labware_count IS NOT NULL OR metrics.sample_count IS NOT NULL)
   OR app_provenance.can_access_storage_node(node.storage_node_id);

GRANT SELECT ON app_core.v_storage_tree TO app_auth;

-- migrate:down
REVOKE SELECT ON app_core.v_storage_tree FROM app_auth;
REVOKE SELECT ON app_core.v_project_access_overview FROM app_auth;
REVOKE SELECT ON app_core.v_sample_lineage FROM app_auth;
REVOKE SELECT ON app_core.v_inventory_status FROM app_auth;
REVOKE SELECT ON app_core.v_labware_inventory FROM app_auth;
REVOKE SELECT ON app_core.v_labware_contents FROM app_auth;
REVOKE SELECT ON app_core.v_sample_overview FROM app_auth;

DROP VIEW IF EXISTS app_core.v_storage_tree;
DROP VIEW IF EXISTS app_core.v_project_access_overview;
DROP VIEW IF EXISTS app_core.v_sample_lineage;
DROP VIEW IF EXISTS app_core.v_inventory_status;
DROP VIEW IF EXISTS app_core.v_labware_inventory;
DROP VIEW IF EXISTS app_core.v_labware_contents;
DROP VIEW IF EXISTS app_core.v_sample_overview;

REVOKE EXECUTE ON FUNCTION app_provenance.storage_path(uuid) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
DROP FUNCTION IF EXISTS app_provenance.storage_path(uuid);
