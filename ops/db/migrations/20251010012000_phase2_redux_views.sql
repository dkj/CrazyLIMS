-- migrate:up
CREATE OR REPLACE VIEW app_provenance.v_artefact_current_location AS
WITH latest_event AS (
  SELECT DISTINCT ON (ase.artefact_id)
    ase.artefact_id,
    ase.event_type,
    ase.occurred_at,
    ase.to_storage_node_id,
    ase.from_storage_node_id,
    ase.metadata
  FROM app_provenance.artefact_storage_events ase
  ORDER BY ase.artefact_id, ase.occurred_at DESC
)
SELECT
  le.artefact_id,
  CASE
    WHEN le.event_type IN ('check_out','disposed') THEN NULL
    ELSE le.to_storage_node_id
  END AS storage_node_id,
  sn.display_name AS storage_display_name,
  sn.node_type,
  sn.scope_id,
  coalesce(sn.environment, '{}'::jsonb) AS environment,
  le.event_type AS last_event_type,
  le.occurred_at AS last_event_at
FROM latest_event le
LEFT JOIN app_provenance.storage_nodes sn
  ON sn.storage_node_id = le.to_storage_node_id;

CREATE OR REPLACE VIEW app_provenance.v_container_contents AS
SELECT
  cs.container_artefact_id,
  container.name AS container_name,
  container.status AS container_status,
  cs.container_slot_id,
  cs.slot_name,
  cs.display_name AS slot_display_name,
  cs.position,
  occupant.artefact_id,
  occupant.name AS artefact_name,
  occupant.status AS artefact_status,
  occupant.quantity,
  occupant.quantity_unit,
  occupant.created_at AS occupied_at,
  occupant.updated_at AS last_updated_at
FROM app_provenance.container_slots cs
JOIN app_provenance.artefacts container
  ON container.artefact_id = cs.container_artefact_id
LEFT JOIN app_provenance.artefacts occupant
  ON occupant.container_slot_id = cs.container_slot_id
 AND occupant.container_artefact_id = cs.container_artefact_id;

CREATE OR REPLACE VIEW app_provenance.v_accessible_artefacts AS
SELECT
  a.artefact_id,
  a.name,
  a.status,
  a.is_virtual,
  a.quantity,
  a.quantity_unit,
  at.type_key,
  at.display_name AS artefact_type,
  at.kind AS artefact_kind,
  primary_scope.scope_id AS primary_scope_id,
  s.display_name AS primary_scope_name,
  s.scope_type AS primary_scope_type,
  loc.storage_node_id,
  loc.storage_display_name,
  loc.node_type AS storage_node_type,
  loc.last_event_type,
  loc.last_event_at
FROM app_provenance.artefacts a
JOIN app_provenance.artefact_types at
  ON at.artefact_type_id = a.artefact_type_id
LEFT JOIN LATERAL (
  SELECT sc.scope_id
  FROM app_provenance.artefact_scopes sc
  WHERE sc.artefact_id = a.artefact_id
  ORDER BY
    CASE sc.relationship
      WHEN 'primary' THEN 0
      ELSE 1
    END,
    sc.assigned_at DESC
  LIMIT 1
) AS primary_scope ON TRUE
LEFT JOIN app_security.scopes s
  ON s.scope_id = primary_scope.scope_id
LEFT JOIN app_provenance.v_artefact_current_location loc
  ON loc.artefact_id = a.artefact_id
WHERE app_provenance.can_access_artefact(a.artefact_id);

GRANT SELECT ON app_provenance.v_artefact_current_location TO app_auth;
GRANT SELECT ON app_provenance.v_container_contents TO app_auth;
GRANT SELECT ON app_provenance.v_accessible_artefacts TO app_auth;

-- migrate:down
REVOKE SELECT ON app_provenance.v_accessible_artefacts FROM app_auth;
REVOKE SELECT ON app_provenance.v_container_contents FROM app_auth;
REVOKE SELECT ON app_provenance.v_artefact_current_location FROM app_auth;

DROP VIEW IF EXISTS app_provenance.v_accessible_artefacts;
DROP VIEW IF EXISTS app_provenance.v_container_contents;
DROP VIEW IF EXISTS app_provenance.v_artefact_current_location;
