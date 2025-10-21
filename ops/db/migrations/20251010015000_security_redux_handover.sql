-- migrate:up
SET client_min_messages TO WARNING;

WITH existing AS (
  SELECT trait_id
  FROM app_provenance.artefact_traits
  WHERE trait_key = 'transfer_state'
)
INSERT INTO app_provenance.artefact_traits (
  trait_key,
  display_name,
  description,
  data_type,
  allowed_values,
  default_value,
  metadata
)
SELECT
  'transfer_state',
  'Transfer State',
  'Tracks research⇄ops handover lifecycle',
  'enum',
  '["pending","transferred","returned"]'::jsonb,
  '"pending"'::jsonb,
  jsonb_build_object('seed','security-redux')
WHERE NOT EXISTS (SELECT 1 FROM existing);

CREATE OR REPLACE FUNCTION app_provenance.can_access_artefact(
  p_artefact_id uuid,
  p_required_roles text[] DEFAULT NULL::text[]
) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
AS $$
DECLARE
  v_has boolean;
BEGIN
  IF p_artefact_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_security.has_role('app_admin') THEN
    RETURN true;
  END IF;

  SELECT TRUE
    INTO v_has
    FROM app_provenance.artefact_scopes s
   WHERE s.artefact_id = p_artefact_id
     AND app_security.actor_has_scope(s.scope_id, p_required_roles)
   LIMIT 1;

  IF COALESCE(v_has, false) THEN
    RETURN true;
  END IF;

  WITH RECURSIVE related AS (
    SELECT p_artefact_id AS artefact_id
    UNION
    SELECT rel.parent_artefact_id
    FROM app_provenance.artefact_relationships rel
    JOIN related r
      ON rel.child_artefact_id = r.artefact_id
    WHERE rel.relationship_type = ANY (
      ARRAY[
        'derived_from',
        'produced_output',
        'handover_duplicate',
        'returned_output',
        'workflow:automation',
        'normalized_from',
        'pooled_input',
        'virtual_source'
      ]
    )
  )
  SELECT TRUE
    INTO v_has
    FROM related r
    JOIN app_provenance.artefact_scopes s
      ON s.artefact_id = r.artefact_id
   WHERE r.artefact_id <> p_artefact_id
     AND app_security.actor_has_scope(s.scope_id, p_required_roles)
   LIMIT 1;

  RETURN COALESCE(v_has, false);
END;
$$;

CREATE OR REPLACE FUNCTION app_provenance.project_handover_metadata(
  p_metadata jsonb,
  p_whitelist text[]
) RETURNS jsonb
    LANGUAGE sql
    IMMUTABLE
    SET search_path TO 'pg_catalog', 'public'
AS $$
  SELECT
    CASE
      WHEN p_metadata IS NULL THEN '{}'::jsonb
      WHEN p_whitelist IS NULL OR array_length(p_whitelist, 1) IS NULL THEN '{}'::jsonb
      ELSE COALESCE(
        (
          SELECT jsonb_object_agg(key, value)
          FROM jsonb_each(p_metadata)
          WHERE key = ANY(p_whitelist)
        ),
        '{}'::jsonb
      )
    END;
$$;

CREATE OR REPLACE FUNCTION app_provenance.set_transfer_state(
  p_artefact_id uuid,
  p_state text,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
AS $$
DECLARE
  v_trait_id uuid;
  v_allowed jsonb;
  v_state text := lower(coalesce(p_state, ''));
  v_actor uuid;
BEGIN
  IF p_artefact_id IS NULL THEN
    RAISE EXCEPTION 'Artefact id is required for transfer state';
  END IF;

  SELECT trait_id, allowed_values
    INTO v_trait_id, v_allowed
    FROM app_provenance.artefact_traits
   WHERE trait_key = 'transfer_state';

  IF v_trait_id IS NULL THEN
    RAISE EXCEPTION 'transfer_state trait not configured';
  END IF;

  IF v_state = '' THEN
    RAISE EXCEPTION 'Transfer state cannot be blank';
  END IF;

  IF v_allowed IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM jsonb_array_elements_text(v_allowed) AS elem(val)
       WHERE elem.val = v_state
     ) THEN
    RAISE EXCEPTION 'Transfer state "%" is not allowed', p_state;
  END IF;

  v_actor := app_security.current_actor_id();

  INSERT INTO app_provenance.artefact_trait_values (
    artefact_id,
    trait_id,
    value,
    recorded_by,
    metadata
  ) VALUES (
    p_artefact_id,
    v_trait_id,
    to_jsonb(v_state),
    v_actor,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('source', 'app_provenance.set_transfer_state')
  );
END;
$$;

CREATE OR REPLACE FUNCTION app_provenance.apply_whitelisted_updates(
  p_src_artefact_id uuid,
  p_dst_artefact_id uuid,
  p_fields text[]
) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security'
    SET row_security TO 'off'
AS $$
DECLARE
  v_fragment jsonb := '{}'::jsonb;
  v_actor uuid := app_security.current_actor_id();
BEGIN
  IF p_fields IS NULL OR array_length(p_fields, 1) IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(jsonb_object_agg(key, value), '{}'::jsonb)
    INTO v_fragment
    FROM jsonb_each(coalesce((SELECT metadata FROM app_provenance.artefacts WHERE artefact_id = p_src_artefact_id), '{}'::jsonb))
   WHERE key = ANY(p_fields);

  UPDATE app_provenance.artefacts
     SET metadata   = coalesce(metadata, '{}'::jsonb) || v_fragment,
         updated_at = clock_timestamp(),
         updated_by = v_actor
   WHERE artefact_id = p_dst_artefact_id;

  UPDATE app_provenance.artefact_relationships
     SET metadata = coalesce(metadata, '{}'::jsonb)
                    || jsonb_build_object(
                         'last_propagated_at', clock_timestamp(),
                         'last_propagated_by', v_actor
                       )
   WHERE parent_artefact_id = p_src_artefact_id
     AND child_artefact_id = p_dst_artefact_id
     AND relationship_type = 'handover_duplicate';
END;
$$;

CREATE OR REPLACE FUNCTION app_provenance.propagate_handover_corrections(
  p_src_artefact_id uuid
) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security'
    SET row_security TO 'off'
AS $$
DECLARE
  v_fields text[];
  rel record;
BEGIN
  FOR rel IN
    SELECT child_artefact_id, metadata
    FROM app_provenance.artefact_relationships
    WHERE parent_artefact_id = p_src_artefact_id
      AND relationship_type = 'handover_duplicate'
  LOOP
    SELECT COALESCE(array_agg(val), ARRAY[]::text[])
      INTO v_fields
      FROM jsonb_array_elements_text(coalesce(rel.metadata -> 'propagation_whitelist', '[]'::jsonb)) AS elem(val);

    IF array_length(v_fields, 1) IS NOT NULL THEN
      PERFORM app_provenance.apply_whitelisted_updates(
        p_src_artefact_id,
        rel.child_artefact_id,
        v_fields
      );
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION app_provenance.can_update_handover_metadata(
  p_artefact_id uuid
) RETURNS boolean
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
           JOIN app_security.scopes sc
             ON sc.scope_id = s.scope_id
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
    JOIN app_provenance.artefact_traits t
      ON t.trait_id = tv.trait_id
   WHERE tv.artefact_id = p_artefact_id
     AND t.trait_key = 'transfer_state'
   ORDER BY tv.effective_at DESC
   LIMIT 1;

  RETURN NOT COALESCE(v_is_returned, false);
END;
$$;

CREATE OR REPLACE FUNCTION app_provenance.sp_handover_to_ops(
  p_research_scope_id uuid,
  p_ops_scope_key text,
  p_artefact_ids uuid[],
  p_field_whitelist text[] DEFAULT '{}'
) RETURNS uuid
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

CREATE OR REPLACE FUNCTION app_provenance.sp_return_from_ops(
  p_ops_artefact_id uuid,
  p_research_scope_ids uuid[]
) RETURNS void
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

CREATE OR REPLACE FUNCTION app_provenance.tg_propagate_handover()
RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public', 'app_provenance'
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.artefact_id IS NOT NULL
     AND NEW.metadata IS DISTINCT FROM OLD.metadata
     AND EXISTS (
           SELECT 1
           FROM app_provenance.artefact_relationships rel
           WHERE rel.parent_artefact_id = NEW.artefact_id
             AND rel.relationship_type = 'handover_duplicate'
         ) THEN
    PERFORM app_provenance.propagate_handover_corrections(NEW.artefact_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_propagate_handover ON app_provenance.artefacts;
CREATE TRIGGER trg_propagate_handover
AFTER UPDATE OF metadata ON app_provenance.artefacts
FOR EACH ROW
EXECUTE FUNCTION app_provenance.tg_propagate_handover();

-- migrate:down
DROP TRIGGER IF EXISTS trg_propagate_handover ON app_provenance.artefacts;

DROP FUNCTION IF EXISTS app_provenance.tg_propagate_handover();
DROP FUNCTION IF EXISTS app_provenance.sp_return_from_ops(uuid, uuid[]);
DROP FUNCTION IF EXISTS app_provenance.sp_handover_to_ops(uuid, text, uuid[], text[]);
DROP FUNCTION IF EXISTS app_provenance.can_update_handover_metadata(uuid);
DROP FUNCTION IF EXISTS app_provenance.propagate_handover_corrections(uuid);
DROP FUNCTION IF EXISTS app_provenance.apply_whitelisted_updates(uuid, uuid, text[]);
DROP FUNCTION IF EXISTS app_provenance.set_transfer_state(uuid, text, jsonb);
DROP FUNCTION IF EXISTS app_provenance.project_handover_metadata(jsonb, text[]);

CREATE OR REPLACE FUNCTION app_provenance.can_access_artefact(
  p_artefact_id uuid,
  p_required_roles text[] DEFAULT NULL::text[]
) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
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

WITH trait_ids AS (
  SELECT trait_id
  FROM app_provenance.artefact_traits
  WHERE trait_key = 'transfer_state'
)
DELETE FROM app_provenance.artefact_trait_values
WHERE trait_id IN (SELECT trait_id FROM trait_ids);

DELETE FROM app_provenance.artefact_traits
WHERE trait_key = 'transfer_state';
