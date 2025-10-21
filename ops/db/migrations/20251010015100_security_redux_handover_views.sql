-- migrate:up
SET client_min_messages TO WARNING;

UPDATE app_provenance.artefact_relationships
   SET metadata = coalesce(metadata, '{}'::jsonb)
                  || jsonb_build_object(
                       'propagation_whitelist',
                       coalesce(metadata -> 'propagation_whitelist', '[]'::jsonb)
                     )
 WHERE relationship_type = 'handover_duplicate'
   AND (metadata -> 'propagation_whitelist') IS NULL;

CREATE VIEW app_core.v_handover_overview AS
WITH latest_state AS (
  SELECT DISTINCT ON (tv.artefact_id)
         tv.artefact_id,
         trim(both '"' FROM tv.value::text) AS transfer_state,
         tv.effective_at
    FROM app_provenance.artefact_trait_values tv
    JOIN app_provenance.artefact_traits t
      ON t.trait_id = tv.trait_id
   WHERE t.trait_key = 'transfer_state'
   ORDER BY tv.artefact_id, tv.effective_at DESC
), ops_scopes AS (
  SELECT ascope.artefact_id,
         array_agg(DISTINCT sc.scope_key ORDER BY sc.scope_key) AS scope_keys
    FROM app_provenance.artefact_scopes ascope
    JOIN app_security.scopes sc
      ON sc.scope_id = ascope.scope_id
   WHERE sc.scope_type = 'ops'
   GROUP BY ascope.artefact_id
), research_scopes AS (
  SELECT ascope.artefact_id,
         array_agg(DISTINCT sc.scope_key ORDER BY sc.scope_key) AS scope_keys
    FROM app_provenance.artefact_scopes ascope
    JOIN app_security.scopes sc
      ON sc.scope_id = ascope.scope_id
   WHERE sc.scope_type IN ('project','dataset','subproject')
   GROUP BY ascope.artefact_id
)
SELECT
  rel.parent_artefact_id AS research_artefact_id,
  parent.name            AS research_artefact_name,
  research_scopes.scope_keys AS research_scope_keys,
  rel.child_artefact_id  AS ops_artefact_id,
  child.name             AS ops_artefact_name,
  ops_scopes.scope_keys  AS ops_scope_keys,
  ls_parent.transfer_state AS research_transfer_state,
  ls_child.transfer_state  AS ops_transfer_state,
  (
    SELECT array_agg(elem ORDER BY elem)
    FROM jsonb_array_elements_text(coalesce(rel.metadata -> 'propagation_whitelist', '[]'::jsonb)) AS elem
  ) AS propagation_whitelist,
  (rel.metadata ->> 'handover_at')::timestamptz  AS handover_at,
  (rel.metadata ->> 'returned_at')::timestamptz  AS returned_at,
  (rel.metadata ->> 'handover_by')::uuid         AS handover_by,
  (rel.metadata ->> 'returned_by')::uuid         AS returned_by
FROM app_provenance.artefact_relationships rel
JOIN app_provenance.artefacts parent
  ON parent.artefact_id = rel.parent_artefact_id
JOIN app_provenance.artefacts child
  ON child.artefact_id = rel.child_artefact_id
LEFT JOIN latest_state ls_parent
  ON ls_parent.artefact_id = parent.artefact_id
LEFT JOIN latest_state ls_child
  ON ls_child.artefact_id = child.artefact_id
LEFT JOIN ops_scopes
  ON ops_scopes.artefact_id = child.artefact_id
LEFT JOIN research_scopes
  ON research_scopes.artefact_id = parent.artefact_id
WHERE rel.relationship_type = 'handover_duplicate';

COMMENT ON VIEW app_core.v_handover_overview IS
  'Summarises handover duplicates, scope memberships, transfer state, and propagation metadata for UI consumption.';

-- migrate:down
DROP VIEW IF EXISTS app_core.v_handover_overview;
