-- migrate:up

CREATE OR REPLACE FUNCTION app_provenance.transfer_allowed_roles(p_artefact_id uuid, p_relationship_type text DEFAULT 'handover_duplicate') RETURNS text[]
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security'
    SET row_security TO 'off'
AS $$
DECLARE
  v_roles text[];
  v_type text := COALESCE(NULLIF(p_relationship_type, ''), 'handover_duplicate');
BEGIN
  IF p_artefact_id IS NULL THEN
    RETURN ARRAY['app_operator','app_admin','app_automation'];
  END IF;

  SELECT ARRAY(
           SELECT DISTINCT lower(role_value)
           FROM jsonb_array_elements_text(coalesce(rel.metadata -> 'allowed_roles', '[]'::jsonb)) AS role(role_value)
         )
    INTO v_roles
    FROM app_provenance.artefact_relationships rel
   WHERE rel.child_artefact_id = p_artefact_id
     AND rel.relationship_type = v_type
   ORDER BY rel.created_at DESC
   LIMIT 1;

  IF array_length(v_roles, 1) IS NULL THEN
    RETURN ARRAY['app_operator','app_admin','app_automation'];
  END IF;

  RETURN app_security.coerce_roles(v_roles);
END;
$$;


CREATE OR REPLACE FUNCTION app_provenance.can_update_handover_metadata(p_artefact_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
AS $$
DECLARE
  v_allowed_roles text[];
  v_actor_roles text[];
  v_matches_role boolean;
  v_is_returned boolean;
BEGIN
  IF p_artefact_id IS NULL THEN
    RETURN false;
  END IF;

  v_allowed_roles := app_provenance.transfer_allowed_roles(p_artefact_id);

  IF NOT app_provenance.can_access_artefact(p_artefact_id, v_allowed_roles) THEN
    RETURN false;
  END IF;

  v_actor_roles := app_security.current_roles();
  v_matches_role := EXISTS (
    SELECT 1
    FROM unnest(v_allowed_roles) AS allowed(role_name)
    WHERE allowed.role_name = ANY(v_actor_roles)
  );

  IF NOT v_matches_role THEN
    RETURN false;
  END IF;

  SELECT (tv.value = to_jsonb('returned'::text))
    INTO v_is_returned
    FROM app_provenance.artefact_trait_values tv
    JOIN app_provenance.artefact_traits t
      ON t.trait_id = tv.trait_id
   WHERE tv.artefact_id = p_artefact_id
     AND t.trait_key = 'transfer_state'
   ORDER BY tv.effective_at DESC
   LIMIT 1;

  RETURN NOT COALESCE(v_is_returned, false);
END;
$$;


CREATE OR REPLACE FUNCTION app_provenance.sp_transfer_between_scopes(
  p_source_scope_id uuid,
  p_target_scope_key text,
  p_target_scope_type text,
  p_artefact_ids uuid[],
  p_field_whitelist text[] DEFAULT '{}'::text[],
  p_target_parent_scope_id uuid DEFAULT NULL,
  p_allowed_roles text[] DEFAULT ARRAY['app_operator','app_admin','app_automation'],
  p_relationship_type text DEFAULT 'handover_duplicate',
  p_scope_metadata jsonb DEFAULT '{}'::jsonb,
  p_relationship_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
AS $$
DECLARE
  v_target_scope_id uuid;
  v_src uuid;
  v_dst uuid;
  v_actor uuid := app_security.current_actor_id();
  v_metadata jsonb;
  v_whitelist text[] := COALESCE(p_field_whitelist, ARRAY[]::text[]);
  v_allowed text[] := app_security.coerce_roles(p_allowed_roles);
  v_relationship text := COALESCE(NULLIF(p_relationship_type, ''), 'handover_duplicate');
  v_scope_data jsonb := coalesce(p_scope_metadata, '{}'::jsonb);
  v_rel_metadata jsonb := coalesce(p_relationship_metadata, '{}'::jsonb);
BEGIN
  IF p_source_scope_id IS NULL THEN
    RAISE EXCEPTION 'Source scope id is required';
  END IF;

  IF p_target_scope_key IS NULL OR p_target_scope_key = '' THEN
    RAISE EXCEPTION 'Target scope key is required';
  END IF;

  IF p_target_scope_type IS NULL OR p_target_scope_type = '' THEN
    RAISE EXCEPTION 'Target scope type is required';
  END IF;

  IF NOT app_security.actor_has_scope(p_source_scope_id, ARRAY['app_admin','app_researcher','app_operator']) THEN
    RAISE EXCEPTION 'Current actor is not authorised for source scope %', p_source_scope_id;
  END IF;

  IF array_length(v_allowed, 1) IS NULL THEN
    v_allowed := ARRAY['app_admin'];
  END IF;

  SELECT scope_id
    INTO v_target_scope_id
    FROM app_security.scopes
   WHERE scope_key = p_target_scope_key
   FOR UPDATE;

  IF v_target_scope_id IS NULL THEN
    INSERT INTO app_security.scopes (
      scope_key,
      scope_type,
      display_name,
      parent_scope_id,
      metadata,
      created_by
    )
    VALUES (
      p_target_scope_key,
      lower(p_target_scope_type),
      replace(p_target_scope_key, ':', ' / '),
      COALESCE(p_target_parent_scope_id, p_source_scope_id),
      v_scope_data,
      v_actor
    )
    RETURNING scope_id INTO v_target_scope_id;
  ELSE
    IF v_scope_data <> '{}'::jsonb THEN
      UPDATE app_security.scopes
         SET metadata   = coalesce(metadata, '{}'::jsonb) || v_scope_data,
             updated_at = clock_timestamp(),
             updated_by = v_actor
       WHERE scope_id = v_target_scope_id;
    END IF;
  END IF;

  FOREACH v_src IN ARRAY COALESCE(p_artefact_ids, ARRAY[]::uuid[]) LOOP
    IF NOT app_provenance.can_access_artefact(v_src, ARRAY['app_admin','app_researcher']) THEN
      RAISE EXCEPTION 'Actor cannot transfer artefact %', v_src;
    END IF;

    SELECT app_provenance.project_handover_metadata(a.metadata, v_whitelist)
      INTO v_metadata
      FROM app_provenance.artefacts a
     WHERE a.artefact_id = v_src;

    v_metadata := coalesce(v_metadata, '{}'::jsonb)
                  || jsonb_build_object(
                       'source_artefact_id', v_src,
                       'handover_scope_key', p_target_scope_key,
                       'target_scope_id', v_target_scope_id,
                       'target_scope_type', lower(p_target_scope_type),
                       'propagation_whitelist', to_jsonb(v_whitelist),
                       'allowed_roles', to_jsonb(v_allowed)
                     );

    INSERT INTO app_provenance.artefacts (
      artefact_type_id,
      name,
      description,
      status,
      quantity,
      quantity_unit,
      metadata,
      origin_process_instance_id,
      container_artefact_id,
      container_slot_id,
      is_virtual
    )
    SELECT
      a.artefact_type_id,
      a.name,
      a.description,
      'active',
      NULL,
      NULL,
      v_metadata,
      NULL,
      NULL,
      NULL,
      false
    FROM app_provenance.artefacts a
    WHERE a.artefact_id = v_src
    RETURNING artefact_id INTO v_dst;

    INSERT INTO app_provenance.artefact_scopes (
      artefact_id,
      scope_id,
      relationship,
      assigned_by,
      metadata
    ) VALUES (
      v_dst,
      v_target_scope_id,
      'primary',
      v_actor,
      jsonb_build_object('source', 'app_provenance.sp_transfer_between_scopes')
    );

    INSERT INTO app_provenance.artefact_relationships (
      parent_artefact_id,
      child_artefact_id,
      relationship_type,
      metadata,
      created_by
    ) VALUES (
      v_src,
      v_dst,
      v_relationship,
      jsonb_build_object(
        'propagation_whitelist', to_jsonb(v_whitelist),
        'handover_at', clock_timestamp(),
        'handover_by', v_actor,
        'handover_scope_key', p_target_scope_key,
        'target_scope_id', v_target_scope_id,
        'target_scope_type', lower(p_target_scope_type),
        'allowed_roles', to_jsonb(v_allowed)
      ) || v_rel_metadata,
      v_actor
    );

    PERFORM app_provenance.set_transfer_state(
      v_src,
      'transferred',
      jsonb_build_object('scope', p_target_scope_key, 'source', 'app_provenance.sp_transfer_between_scopes')
    );

    PERFORM app_provenance.set_transfer_state(
      v_dst,
      'pending',
      jsonb_build_object('scope', p_target_scope_key, 'source', 'app_provenance.sp_transfer_between_scopes')
    );
  END LOOP;

  RETURN v_target_scope_id;
END;
$$;


CREATE OR REPLACE FUNCTION app_provenance.sp_handover_to_ops(p_research_scope_id uuid, p_ops_scope_key text, p_artefact_ids uuid[], p_field_whitelist text[] DEFAULT '{}'::text[]) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
AS $$
BEGIN
  RETURN app_provenance.sp_transfer_between_scopes(
    p_source_scope_id      => p_research_scope_id,
    p_target_scope_key     => p_ops_scope_key,
    p_target_scope_type    => 'ops',
    p_artefact_ids         => p_artefact_ids,
    p_field_whitelist      => p_field_whitelist,
    p_allowed_roles        => ARRAY['app_operator','app_admin','app_automation'],
    p_relationship_type    => 'handover_duplicate'
  );
END;
$$;


CREATE OR REPLACE FUNCTION app_provenance.sp_complete_transfer(p_target_artefact_id uuid, p_return_scope_ids uuid[] DEFAULT NULL, p_relationship_type text DEFAULT 'handover_duplicate', p_completion_state text DEFAULT 'returned', p_state_metadata jsonb DEFAULT '{}'::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
AS $$
DECLARE
  v_scope uuid;
  v_actor uuid := app_security.current_actor_id();
  v_roles text[];
  v_type text := COALESCE(NULLIF(p_relationship_type, ''), 'handover_duplicate');
  v_state text := COALESCE(NULLIF(p_completion_state, ''), 'returned');
  v_metadata jsonb := coalesce(p_state_metadata, '{}'::jsonb);
  v_has_scope boolean;
BEGIN
  IF p_target_artefact_id IS NULL THEN
    RAISE EXCEPTION 'Target artefact id is required';
  END IF;

  v_roles := app_provenance.transfer_allowed_roles(p_target_artefact_id, v_type);

  SELECT EXISTS (
           SELECT 1
           FROM app_provenance.artefact_scopes s
          WHERE s.artefact_id = p_target_artefact_id
            AND app_security.actor_has_scope(s.scope_id, v_roles)
         )
    INTO v_has_scope;

  IF NOT COALESCE(v_has_scope, false) AND NOT app_security.has_role('app_admin') THEN
    RAISE EXCEPTION 'Current actor is not authorised to complete transfer for artefact %', p_target_artefact_id;
  END IF;

  FOREACH v_scope IN ARRAY COALESCE(p_return_scope_ids, ARRAY[]::uuid[]) LOOP
    INSERT INTO app_provenance.artefact_scopes (
      artefact_id,
      scope_id,
      relationship,
      assigned_by,
      metadata
    )
    SELECT
      p_target_artefact_id,
      v_scope,
      'derived_from',
      v_actor,
      jsonb_build_object('source', 'app_provenance.sp_complete_transfer')
    WHERE NOT EXISTS (
      SELECT 1
      FROM app_provenance.artefact_scopes existing
      WHERE existing.artefact_id = p_target_artefact_id
        AND existing.scope_id = v_scope
    );
  END LOOP;

  UPDATE app_provenance.artefact_relationships
     SET metadata = coalesce(metadata, '{}'::jsonb)
                    || jsonb_build_object(
                         'returned_at', clock_timestamp(),
                         'returned_by', v_actor
                       )
   WHERE child_artefact_id = p_target_artefact_id
     AND relationship_type = v_type;

  IF NOT (v_metadata ? 'source') THEN
    v_metadata := v_metadata || jsonb_build_object('source', 'app_provenance.sp_complete_transfer');
  END IF;

  PERFORM app_provenance.set_transfer_state(
    p_target_artefact_id,
    v_state,
    v_metadata
  );
END;
$$;


CREATE OR REPLACE FUNCTION app_provenance.sp_return_from_ops(p_ops_artefact_id uuid, p_research_scope_ids uuid[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
AS $$
BEGIN
  PERFORM app_provenance.sp_complete_transfer(
    p_target_artefact_id => p_ops_artefact_id,
    p_return_scope_ids   => p_research_scope_ids,
    p_relationship_type  => 'handover_duplicate',
    p_completion_state   => 'returned',
    p_state_metadata     => jsonb_build_object('source', 'app_provenance.sp_return_from_ops')
  );
END;
$$;


CREATE OR REPLACE VIEW app_core.v_scope_transfer_overview AS
 WITH latest_state AS (
         SELECT DISTINCT ON (tv.artefact_id) tv.artefact_id,
            TRIM(BOTH '"'::text FROM (tv.value)::text) AS transfer_state,
            tv.effective_at
           FROM app_provenance.artefact_trait_values tv
           JOIN app_provenance.artefact_traits t
             ON t.trait_id = tv.trait_id
          WHERE t.trait_key = 'transfer_state'
          ORDER BY tv.artefact_id, tv.effective_at DESC
        ), scope_pairs AS (
         SELECT ascope.artefact_id,
            jsonb_build_object(
              'scope_id', sc.scope_id,
              'scope_key', sc.scope_key,
              'scope_type', sc.scope_type,
              'relationship', ascope.relationship
            ) AS scope_obj
           FROM app_provenance.artefact_scopes ascope
           JOIN app_security.scopes sc ON sc.scope_id = ascope.scope_id
        ), artefact_scopes AS (
         SELECT scope_pairs.artefact_id,
            jsonb_agg(scope_pairs.scope_obj ORDER BY scope_pairs.scope_obj ->> 'scope_key') AS scopes
           FROM scope_pairs
          GROUP BY scope_pairs.artefact_id
        ), relationship_roles AS (
         SELECT rel.relationship_id,
            rel.parent_artefact_id,
            rel.child_artefact_id,
            rel.relationship_type,
            ARRAY(
              SELECT DISTINCT lower(role_value)
              FROM jsonb_array_elements_text(coalesce(rel.metadata -> 'allowed_roles', '[]'::jsonb)) AS role(role_value)
            ) AS allowed_roles
           FROM app_provenance.artefact_relationships rel
          WHERE rel.metadata ? 'handover_at'
        )
 SELECT rel.parent_artefact_id AS source_artefact_id,
    parent.name AS source_artefact_name,
    src.scopes AS source_scopes,
    rel.child_artefact_id AS target_artefact_id,
    child.name AS target_artefact_name,
    tgt.scopes AS target_scopes,
    ls_parent.transfer_state AS source_transfer_state,
    ls_child.transfer_state AS target_transfer_state,
    ( SELECT array_agg(elem.value ORDER BY elem.value)
        FROM jsonb_array_elements_text(coalesce(rel.metadata -> 'propagation_whitelist', '[]'::jsonb)) elem(value)
    ) AS propagation_whitelist,
    COALESCE(rr.allowed_roles, ARRAY['app_operator','app_admin','app_automation']::text[]) AS allowed_roles,
    rel.relationship_type,
    ((rel.metadata ->> 'handover_at'))::timestamp with time zone AS handover_at,
    ((rel.metadata ->> 'returned_at'))::timestamp with time zone AS returned_at,
    ((rel.metadata ->> 'handover_by'))::uuid AS handover_by,
    ((rel.metadata ->> 'returned_by'))::uuid AS returned_by,
    rel.metadata AS relationship_metadata
   FROM app_provenance.artefact_relationships rel
   JOIN app_provenance.artefacts parent ON parent.artefact_id = rel.parent_artefact_id
   JOIN app_provenance.artefacts child ON child.artefact_id = rel.child_artefact_id
   LEFT JOIN latest_state ls_parent ON ls_parent.artefact_id = parent.artefact_id
   LEFT JOIN latest_state ls_child ON ls_child.artefact_id = child.artefact_id
   LEFT JOIN artefact_scopes src ON src.artefact_id = rel.parent_artefact_id
   LEFT JOIN artefact_scopes tgt ON tgt.artefact_id = rel.child_artefact_id
   LEFT JOIN relationship_roles rr ON rr.relationship_id = rel.relationship_id
  WHERE rel.metadata ? 'handover_at';

COMMENT ON VIEW app_core.v_scope_transfer_overview IS 'Generalised scope-to-scope transfer overview including scope metadata and allowed roles.';

GRANT SELECT ON app_core.v_scope_transfer_overview TO app_auth;

CREATE OR REPLACE VIEW app_core.v_handover_overview AS
 SELECT info.source_artefact_id AS research_artefact_id,
    info.source_artefact_name AS research_artefact_name,
    (
      SELECT COALESCE(array_agg(elem->>'scope_key' ORDER BY elem->>'scope_key'), ARRAY[]::text[])
      FROM jsonb_array_elements(coalesce(info.source_scopes, '[]'::jsonb)) elem
      WHERE elem->>'scope_type' IN ('project','dataset','subproject')
    ) AS research_scope_keys,
    info.target_artefact_id AS ops_artefact_id,
    info.target_artefact_name AS ops_artefact_name,
    (
      SELECT COALESCE(array_agg(elem->>'scope_key' ORDER BY elem->>'scope_key'), ARRAY[]::text[])
      FROM jsonb_array_elements(coalesce(info.target_scopes, '[]'::jsonb)) elem
      WHERE elem->>'scope_type' = 'ops'
    ) AS ops_scope_keys,
    info.source_transfer_state AS research_transfer_state,
    info.target_transfer_state AS ops_transfer_state,
    info.propagation_whitelist,
    info.handover_at,
    info.returned_at,
    info.handover_by,
    info.returned_by
   FROM app_core.v_scope_transfer_overview info
  WHERE info.relationship_type = 'handover_duplicate'
    AND EXISTS (
      SELECT 1
      FROM jsonb_array_elements(coalesce(info.target_scopes, '[]'::jsonb)) elem
      WHERE elem->>'scope_type' = 'ops'
    );

COMMENT ON VIEW app_core.v_handover_overview IS 'Summarises handover duplicates, scope memberships, transfer state, and propagation metadata for UI consumption.';

-- migrate:down

CREATE OR REPLACE VIEW app_core.v_handover_overview AS
 WITH latest_state AS (
         SELECT DISTINCT ON (tv.artefact_id) tv.artefact_id,
            TRIM(BOTH '"'::text FROM (tv.value)::text) AS transfer_state,
            tv.effective_at
           FROM app_provenance.artefact_trait_values tv
             JOIN app_provenance.artefact_traits t ON t.trait_id = tv.trait_id
          WHERE t.trait_key = 'transfer_state'
          ORDER BY tv.artefact_id, tv.effective_at DESC
        ), ops_scopes AS (
         SELECT ascope.artefact_id,
            array_agg(DISTINCT sc.scope_key ORDER BY sc.scope_key) AS scope_keys
           FROM app_provenance.artefact_scopes ascope
           JOIN app_security.scopes sc ON sc.scope_id = ascope.scope_id
          WHERE sc.scope_type = 'ops'
          GROUP BY ascope.artefact_id
        ), research_scopes AS (
         SELECT ascope.artefact_id,
            array_agg(DISTINCT sc.scope_key ORDER BY sc.scope_key) AS scope_keys
           FROM app_provenance.artefact_scopes ascope
           JOIN app_security.scopes sc ON sc.scope_id = ascope.scope_id
          WHERE sc.scope_type = ANY (ARRAY['project','dataset','subproject'])
          GROUP BY ascope.artefact_id
        )
 SELECT rel.parent_artefact_id AS research_artefact_id,
    parent.name AS research_artefact_name,
    research_scopes.scope_keys AS research_scope_keys,
    rel.child_artefact_id AS ops_artefact_id,
    child.name AS ops_artefact_name,
    ops_scopes.scope_keys AS ops_scope_keys,
    ls_parent.transfer_state AS research_transfer_state,
    ls_child.transfer_state AS ops_transfer_state,
    ( SELECT array_agg(elem.value ORDER BY elem.value)
        FROM jsonb_array_elements_text(coalesce(rel.metadata -> 'propagation_whitelist', '[]'::jsonb)) elem(value)
    ) AS propagation_whitelist,
    ((rel.metadata ->> 'handover_at'))::timestamp with time zone AS handover_at,
    ((rel.metadata ->> 'returned_at'))::timestamp with time zone AS returned_at,
    ((rel.metadata ->> 'handover_by'))::uuid AS handover_by,
    ((rel.metadata ->> 'returned_by'))::uuid AS returned_by
   FROM app_provenance.artefact_relationships rel
   JOIN app_provenance.artefacts parent ON parent.artefact_id = rel.parent_artefact_id
   JOIN app_provenance.artefacts child ON child.artefact_id = rel.child_artefact_id
   LEFT JOIN latest_state ls_parent ON ls_parent.artefact_id = parent.artefact_id
   LEFT JOIN latest_state ls_child ON ls_child.artefact_id = child.artefact_id
   LEFT JOIN ops_scopes ON ops_scopes.artefact_id = child.artefact_id
   LEFT JOIN research_scopes ON research_scopes.artefact_id = parent.artefact_id
  WHERE rel.relationship_type = 'handover_duplicate';

COMMENT ON VIEW app_core.v_handover_overview IS 'Summarises handover duplicates, scope memberships, transfer state, and propagation metadata for UI consumption.';

REVOKE SELECT ON app_core.v_scope_transfer_overview FROM app_auth;

DROP VIEW IF EXISTS app_core.v_scope_transfer_overview;

DROP FUNCTION IF EXISTS app_provenance.sp_return_from_ops(uuid, uuid[]);
DROP FUNCTION IF EXISTS app_provenance.sp_complete_transfer(uuid, uuid[], text, text, jsonb);
DROP FUNCTION IF EXISTS app_provenance.sp_transfer_between_scopes(uuid, text, text, uuid[], text[], uuid, text[], text, jsonb, jsonb);
DROP FUNCTION IF EXISTS app_provenance.transfer_allowed_roles(uuid, text);

CREATE OR REPLACE FUNCTION app_provenance.sp_handover_to_ops(p_research_scope_id uuid, p_ops_scope_key text, p_artefact_ids uuid[], p_field_whitelist text[] DEFAULT '{}'::text[]) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
AS $$
DECLARE
  v_ops_scope_id uuid;
  v_src uuid;
  v_dst uuid;
  v_actor uuid := app_security.current_actor_id();
  v_metadata jsonb;
  v_whitelist text[] := COALESCE(p_field_whitelist, ARRAY[]::text[]);
BEGIN
  IF p_research_scope_id IS NULL THEN
    RAISE EXCEPTION 'Research scope id is required';
  END IF;

  IF p_ops_scope_key IS NULL OR p_ops_scope_key = '' THEN
    RAISE EXCEPTION 'Ops scope key is required';
  END IF;

  IF NOT app_security.actor_has_scope(p_research_scope_id, ARRAY['app_admin','app_researcher','app_operator']) THEN
    RAISE EXCEPTION 'Current actor is not authorised for research scope %', p_research_scope_id;
  END IF;

  SELECT scope_id
    INTO v_ops_scope_id
    FROM app_security.scopes
   WHERE scope_key = p_ops_scope_key
   FOR UPDATE;

  IF v_ops_scope_id IS NULL THEN
    INSERT INTO app_security.scopes (
      scope_key,
      scope_type,
      display_name,
      parent_scope_id,
      metadata,
      created_by
    )
    VALUES (
      p_ops_scope_key,
      'ops',
      replace(p_ops_scope_key, ':', ' / '),
      p_research_scope_id,
      jsonb_build_object('seed', 'security-redux'),
      v_actor
    )
    RETURNING scope_id INTO v_ops_scope_id;
  END IF;

  FOREACH v_src IN ARRAY COALESCE(p_artefact_ids, ARRAY[]::uuid[]) LOOP
    IF NOT app_provenance.can_access_artefact(v_src, ARRAY['app_admin','app_researcher']) THEN
      RAISE EXCEPTION 'Actor cannot transfer artefact %', v_src;
    END IF;

    SELECT app_provenance.project_handover_metadata(a.metadata, v_whitelist)
      INTO v_metadata
      FROM app_provenance.artefacts a
     WHERE a.artefact_id = v_src;

    v_metadata := coalesce(v_metadata, '{}'::jsonb)
                  || jsonb_build_object(
                       'source_artefact_id', v_src,
                       'handover_scope_key', p_ops_scope_key,
                       'propagation_whitelist', to_jsonb(v_whitelist)
                     );

    INSERT INTO app_provenance.artefacts (
      artefact_type_id,
      name,
      description,
      status,
      quantity,
      quantity_unit,
      metadata,
      origin_process_instance_id,
      container_artefact_id,
      container_slot_id,
      is_virtual
    )
    SELECT
      a.artefact_type_id,
      a.name,
      a.description,
      'active',
      NULL,
      NULL,
      v_metadata,
      NULL,
      NULL,
      NULL,
      false
    FROM app_provenance.artefacts a
    WHERE a.artefact_id = v_src
    RETURNING artefact_id INTO v_dst;

    INSERT INTO app_provenance.artefact_scopes (
      artefact_id,
      scope_id,
      relationship,
      assigned_by,
      metadata
    ) VALUES (
      v_dst,
      v_ops_scope_id,
      'primary',
      v_actor,
      jsonb_build_object('source', 'app_provenance.sp_handover_to_ops')
    );

    INSERT INTO app_provenance.artefact_relationships (
      parent_artefact_id,
      child_artefact_id,
      relationship_type,
      metadata,
      created_by
    ) VALUES (
      v_src,
      v_dst,
      'handover_duplicate',
      jsonb_build_object(
        'propagation_whitelist', to_jsonb(v_whitelist),
        'handover_at', clock_timestamp(),
        'handover_by', v_actor
      ),
      v_actor
    );

    PERFORM app_provenance.set_transfer_state(
      v_src,
      'transferred',
      jsonb_build_object('scope', p_ops_scope_key)
    );

    PERFORM app_provenance.set_transfer_state(
      v_dst,
      'pending',
      jsonb_build_object('scope', p_ops_scope_key)
    );
  END LOOP;

  RETURN v_ops_scope_id;
END;
$$;


CREATE OR REPLACE FUNCTION app_provenance.sp_return_from_ops(p_ops_artefact_id uuid, p_research_scope_ids uuid[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
AS $$
DECLARE
  v_scope uuid;
  v_actor uuid := app_security.current_actor_id();
BEGIN
  IF p_ops_artefact_id IS NULL THEN
    RAISE EXCEPTION 'Ops artefact id is required';
  END IF;

  IF NOT app_provenance.can_access_artefact(p_ops_artefact_id, ARRAY['app_operator','app_admin','app_researcher']) THEN
    RAISE EXCEPTION 'Actor cannot access ops artefact %', p_ops_artefact_id;
  END IF;

  FOREACH v_scope IN ARRAY COALESCE(p_research_scope_ids, ARRAY[]::uuid[]) LOOP
    INSERT INTO app_provenance.artefact_scopes (
      artefact_id,
      scope_id,
      relationship,
      assigned_by,
      metadata
    )
    SELECT
      p_ops_artefact_id,
      v_scope,
      'derived_from',
      v_actor,
      jsonb_build_object('source', 'app_provenance.sp_return_from_ops')
    WHERE NOT EXISTS (
      SELECT 1
      FROM app_provenance.artefact_scopes existing
      WHERE existing.artefact_id = p_ops_artefact_id
        AND existing.scope_id = v_scope
    );
  END LOOP;

  UPDATE app_provenance.artefact_relationships
     SET metadata = coalesce(metadata, '{}'::jsonb)
                    || jsonb_build_object(
                         'returned_at', clock_timestamp(),
                         'returned_by', v_actor
                       )
   WHERE child_artefact_id = p_ops_artefact_id
     AND relationship_type = 'handover_duplicate';

  PERFORM app_provenance.set_transfer_state(
    p_ops_artefact_id,
    'returned',
    jsonb_build_object('source', 'app_provenance.sp_return_from_ops')
  );
END;
$$;


CREATE OR REPLACE FUNCTION app_provenance.can_update_handover_metadata(p_artefact_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
AS $$
DECLARE
  v_in_ops boolean;
  v_is_returned boolean;
BEGIN
  IF NOT app_provenance.can_access_artefact(p_artefact_id, ARRAY['app_operator','app_admin','app_automation']) THEN
    RETURN false;
  END IF;

  SELECT EXISTS (
           SELECT 1
           FROM app_provenance.artefact_scopes s
           JOIN app_security.scopes sc ON sc.scope_id = s.scope_id
          WHERE s.artefact_id = p_artefact_id
            AND sc.scope_type = 'ops'
            AND sc.is_active
         )
    INTO v_in_ops;

  IF NOT COALESCE(v_in_ops, false) THEN
    RETURN false;
  END IF;

  SELECT (tv.value = to_jsonb('returned'::text))
    INTO v_is_returned
    FROM app_provenance.artefact_trait_values tv
    JOIN app_provenance.artefact_traits t ON t.trait_id = tv.trait_id
   WHERE tv.artefact_id = p_artefact_id
     AND t.trait_key = 'transfer_state'
   ORDER BY tv.effective_at DESC
   LIMIT 1;

  RETURN NOT COALESCE(v_is_returned, false);
END;
$$;
