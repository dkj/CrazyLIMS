-- migrate:up
-- RPC to set or clear an artefact's storage location using 'located_in' edges

CREATE OR REPLACE FUNCTION app_provenance.sp_set_location(
  p_move jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_payload jsonb := coalesce(p_move, '{}'::jsonb);
  v_actor uuid := app_security.current_actor_id();
  v_child uuid;
  v_to uuid;
  v_expected uuid;
  v_reason text;
  v_meta jsonb;
  v_current uuid;
  v_rel_id uuid;
  v_storage_kind text;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_payload) <> 'object' THEN
    RAISE EXCEPTION 'Location payload must be object';
  END IF;

  v_child := NULLIF(v_payload->>'artefact_id','')::uuid;
  v_to := NULLIF(v_payload->>'to_storage_id','')::uuid;
  v_expected := NULLIF(v_payload->>'expected_from_storage_id','')::uuid;
  v_reason := NULLIF(v_payload->>'reason','');
  v_meta := coalesce(v_payload->'metadata', '{}'::jsonb);

  IF v_child IS NULL THEN
    RAISE EXCEPTION 'artefact_id required';
  END IF;

  IF NOT (app_security.session_has_role('app_admin') OR app_security.session_has_role('app_operator') OR app_security.session_has_role('app_automation')) THEN
     RAISE EXCEPTION 'insufficient privileges for set_location' USING ERRCODE='42501';
  END IF;

  SELECT r.parent_artefact_id INTO v_current
  FROM app_provenance.artefact_relationships r
  WHERE r.child_artefact_id = v_child AND r.relationship_type='located_in'
  ORDER BY r.created_at DESC NULLS LAST
  LIMIT 1;

  IF v_expected IS NOT NULL AND v_expected <> v_current THEN
     RAISE EXCEPTION 'expected from % does not match current %', v_expected, v_current USING ERRCODE='P0001';
  END IF;

  -- remove existing location
  DELETE FROM app_provenance.artefact_relationships
  WHERE child_artefact_id = v_child AND relationship_type='located_in';

  -- clear location if no target provided
  IF v_to IS NULL THEN
    RETURN NULL;
  END IF;

  -- verify target is storage artefact and accessible
  SELECT at.kind INTO v_storage_kind
  FROM app_provenance.artefacts a
  JOIN app_provenance.artefact_types at ON at.artefact_type_id = a.artefact_type_id
  WHERE a.artefact_id = v_to;

  IF v_storage_kind IS NULL OR v_storage_kind <> 'storage' THEN
    RAISE EXCEPTION 'target is not a storage artefact: %', v_to USING ERRCODE='P0001';
  END IF;

  IF NOT app_provenance.can_access_storage_node(v_to, ARRAY['app_operator','app_automation']) AND NOT app_security.session_has_role('app_admin') THEN
     RAISE EXCEPTION 'cannot access storage %', v_to USING ERRCODE='42501';
  END IF;

  INSERT INTO app_provenance.artefact_relationships (parent_artefact_id, child_artefact_id, relationship_type, process_instance_id, metadata)
  VALUES (v_to, v_child, 'located_in', NULL, v_meta || jsonb_build_object('reason', v_reason, 'source', 'sp_set_location', 'actor', v_actor))
  RETURNING relationship_id INTO v_rel_id;

  RETURN v_rel_id;
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_set_location(jsonb)
  TO app_auth,
     postgrest_authenticator,
     postgraphile_authenticator,
     app_operator,
     app_admin,
     app_automation;

-- migrate:down
REVOKE EXECUTE ON FUNCTION app_provenance.sp_set_location(jsonb)
  FROM app_auth,
       postgrest_authenticator,
       postgraphile_authenticator,
       app_operator,
       app_admin,
       app_automation;
DROP FUNCTION IF EXISTS app_provenance.sp_set_location(jsonb);
