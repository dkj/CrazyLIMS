\restrict jYWeOf8VunMdUKfASs5z5n0l4ZKHGiX0sgpOZfep9DiZnyLckFH2euYaAE4dEe0

-- Dumped from database version 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: app_core; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_core;


--
-- Name: app_eln; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_eln;


--
-- Name: app_provenance; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_provenance;


--
-- Name: app_security; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_security;


--
-- Name: postgraphile_watch; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA postgraphile_watch;


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: actor_accessible_scopes(text[]); Type: FUNCTION; Schema: app_core; Owner: -
--

CREATE FUNCTION app_core.actor_accessible_scopes(p_scope_types text[] DEFAULT NULL::text[]) RETURNS TABLE(scope_id uuid, scope_key text, scope_type text, display_name text, role_name text, source_scope_id uuid, source_role_name text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    AS $$
  SELECT *
  FROM app_security.actor_accessible_scopes(p_scope_types);
$$;


--
-- Name: can_access_entry(uuid, text[]); Type: FUNCTION; Schema: app_eln; Owner: -
--

CREATE FUNCTION app_eln.can_access_entry(p_entry_id uuid, p_required_roles text[] DEFAULT NULL::text[]) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_eln', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
BEGIN
  IF p_entry_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_security.has_role('app_admin') THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM app_eln.notebook_entry_scopes s
    WHERE s.entry_id = p_entry_id
      AND app_security.actor_has_scope(s.scope_id, p_required_roles)
  );
END;
$$;


--
-- Name: can_edit_entry(uuid, text[]); Type: FUNCTION; Schema: app_eln; Owner: -
--

CREATE FUNCTION app_eln.can_edit_entry(p_entry_id uuid, p_required_roles text[] DEFAULT ARRAY['app_researcher'::text, 'app_operator'::text, 'app_admin'::text]) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_eln', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_status text;
BEGIN
  IF p_entry_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT status
  INTO v_status
  FROM app_eln.notebook_entries
  WHERE entry_id = p_entry_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_status <> 'draft' AND NOT app_security.has_role('app_admin') THEN
    RETURN false;
  END IF;

  RETURN app_eln.can_access_entry(p_entry_id, p_required_roles);
END;
$$;


--
-- Name: canonical_json_digest(jsonb); Type: FUNCTION; Schema: app_eln; Owner: -
--

CREATE FUNCTION app_eln.canonical_json_digest(p_json jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT encode(digest(p_json::text, 'sha256'), 'hex');
$$;


--
-- Name: tg_enforce_entry_status(); Type: FUNCTION; Schema: app_eln; Owner: -
--

CREATE FUNCTION app_eln.tg_enforce_entry_status() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public', 'app_eln', 'app_security', 'app_core'
    AS $$
DECLARE
  v_actor uuid := app_security.current_actor_id();
  v_is_admin boolean := app_security.has_role('app_admin');
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status IS NULL THEN
      NEW.status := 'draft';
    ELSIF NEW.status <> 'draft' THEN
      RAISE EXCEPTION 'New notebook entries must start in draft status'
        USING ERRCODE = 'check_violation';
    END IF;

    NEW.created_by := COALESCE(NEW.created_by, v_actor);
    NEW.updated_by := COALESCE(NEW.updated_by, v_actor);
    RETURN NEW;
  END IF;

  IF OLD.status = 'locked' AND NEW.status = 'locked' THEN
    RAISE EXCEPTION 'Notebook entry % is locked and cannot be modified', OLD.entry_id
      USING ERRCODE = '55000';
  END IF;

  IF OLD.status = 'locked' AND NEW.status <> 'locked' THEN
    IF NOT v_is_admin THEN
      RAISE EXCEPTION 'Only administrators may alter locked notebook entries'
        USING ERRCODE = '42501';
    END IF;
    NEW.locked_at := NULL;
    NEW.locked_by := NULL;
  END IF;

  IF NEW.status = 'locked' AND OLD.status <> 'submitted' THEN
    RAISE EXCEPTION 'Notebook entry must be submitted before it can be locked'
      USING ERRCODE = 'check_violation';
  END IF;

  IF OLD.status = 'submitted' AND NEW.status = 'submitted' THEN
    RAISE EXCEPTION 'Submitted notebook entry cannot be modified without a status change'
      USING ERRCODE = '55000';
  END IF;

  IF NEW.status = 'submitted' AND OLD.status = 'draft' THEN
    NEW.submitted_at := clock_timestamp();
    NEW.submitted_by := COALESCE(NEW.submitted_by, v_actor);
  ELSIF OLD.status = 'submitted' AND NEW.status = 'draft' THEN
    IF NOT v_is_admin THEN
      RAISE EXCEPTION 'Only administrators may revert submissions back to draft'
        USING ERRCODE = '42501';
    END IF;
    NEW.submitted_at := NULL;
    NEW.submitted_by := NULL;
    NEW.locked_at := NULL;
    NEW.locked_by := NULL;
  END IF;

  IF NEW.status = 'locked' AND OLD.status = 'submitted' THEN
    NEW.locked_at := clock_timestamp();
    NEW.locked_by := COALESCE(NEW.locked_by, v_actor);
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: tg_ensure_primary_scope(); Type: FUNCTION; Schema: app_eln; Owner: -
--

CREATE FUNCTION app_eln.tg_ensure_primary_scope() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_eln', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_actor uuid := COALESCE(app_security.current_actor_id(), NEW.created_by);
BEGIN
  INSERT INTO app_eln.notebook_entry_scopes (entry_id, scope_id, relationship, assigned_by)
  VALUES (NEW.entry_id, NEW.primary_scope_id, 'primary', v_actor)
  ON CONFLICT (entry_id, scope_id, relationship) DO NOTHING;
  RETURN NEW;
END;
$$;


--
-- Name: tg_prepare_notebook_version(); Type: FUNCTION; Schema: app_eln; Owner: -
--

CREATE FUNCTION app_eln.tg_prepare_notebook_version() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public', 'app_eln', 'app_security', 'app_core'
    AS $$
DECLARE
  v_next integer;
  v_status text;
  v_actor uuid := app_security.current_actor_id();
BEGIN
  IF NEW.entry_id IS NULL THEN
    RAISE EXCEPTION 'Notebook version must reference an entry'
      USING ERRCODE = 'not_null_violation';
  END IF;

  SELECT status
  INTO v_status
  FROM app_eln.notebook_entries
  WHERE entry_id = NEW.entry_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Notebook entry % does not exist', NEW.entry_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  IF v_status IN ('submitted','locked') AND NOT app_security.has_role('app_admin') THEN
    RAISE EXCEPTION 'Notebook entry % is % and cannot be modified', NEW.entry_id, v_status
      USING ERRCODE = '55000';
  END IF;

  IF NEW.version_number IS NULL OR NEW.version_number <= 0 THEN
    SELECT COALESCE(MAX(version_number), 0) + 1
    INTO v_next
    FROM app_eln.notebook_entry_versions
    WHERE entry_id = NEW.entry_id;

    NEW.version_number := v_next;
  END IF;

  NEW.created_by := COALESCE(NEW.created_by, v_actor);
  NEW.checksum := app_eln.canonical_json_digest(NEW.notebook_json);

  RETURN NEW;
END;
$$;


--
-- Name: tg_touch_notebook_entry(); Type: FUNCTION; Schema: app_eln; Owner: -
--

CREATE FUNCTION app_eln.tg_touch_notebook_entry() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public', 'app_eln', 'app_security'
    AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  NEW.updated_by := COALESCE(app_security.current_actor_id(), NEW.updated_by);
  RETURN NEW;
END;
$$;


--
-- Name: apply_whitelisted_updates(uuid, uuid, text[]); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.apply_whitelisted_updates(p_src_artefact_id uuid, p_dst_artefact_id uuid, p_fields text[]) RETURNS void
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


--
-- Name: can_access_artefact(uuid, text[]); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.can_access_artefact(p_artefact_id uuid, p_required_roles text[] DEFAULT NULL::text[]) RETURNS boolean
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


--
-- Name: can_access_process(uuid, text[]); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.can_access_process(p_process_instance_id uuid, p_required_roles text[] DEFAULT NULL::text[]) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
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


--
-- Name: can_access_storage_node(uuid, text[]); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.can_access_storage_node(p_storage_node_id uuid, p_required_roles text[] DEFAULT NULL::text[]) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
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


--
-- Name: can_update_handover_metadata(uuid); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.can_update_handover_metadata(p_artefact_id uuid) RETURNS boolean
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


--
-- Name: get_artefact_type_id(text); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.get_artefact_type_id(p_type_key text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_type_key IS NULL OR trim(p_type_key) = '' THEN
    RETURN NULL;
  END IF;

  SELECT artefact_type_id
    INTO v_id
    FROM app_provenance.artefact_types
   WHERE type_key = lower(p_type_key)
     AND is_active
   LIMIT 1;

  RETURN v_id;
END;
$$;


--
-- Name: get_process_type_id(text); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.get_process_type_id(p_type_key text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_type_key IS NULL OR trim(p_type_key) = '' THEN
    RETURN NULL;
  END IF;

  SELECT process_type_id
    INTO v_id
    FROM app_provenance.process_types
   WHERE type_key = lower(p_type_key)
     AND is_active
   LIMIT 1;

  RETURN v_id;
END;
$$;


--
-- Name: project_handover_metadata(jsonb, text[]); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.project_handover_metadata(p_metadata jsonb, p_whitelist text[]) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
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


--
-- Name: propagate_handover_corrections(uuid); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.propagate_handover_corrections(p_src_artefact_id uuid) RETURNS void
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


--
-- Name: set_transfer_state(uuid, text, jsonb); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.set_transfer_state(p_artefact_id uuid, p_state text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS void
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


--
-- Name: sp_apply_reagent_in_place(uuid, uuid, jsonb); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_apply_reagent_in_place(p_target_slot_id uuid, p_reagent_artefact_id uuid, p_output jsonb DEFAULT '{}'::jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_current uuid;
  v_output jsonb := coalesce(p_output, '{}'::jsonb);
  v_metadata jsonb := coalesce(v_output->'metadata', '{}'::jsonb);
  v_new uuid;
  v_relationship_type text := coalesce(v_output->>'relationship_type','derived_from');
BEGIN
  PERFORM app_security.require_transaction_context();

  SELECT artefact_id INTO v_current
    FROM app_provenance.artefacts
   WHERE container_slot_id = p_target_slot_id
     AND status IN ('active','reserved')
   ORDER BY updated_at DESC
   LIMIT 1;

  IF v_current IS NULL THEN
    RAISE EXCEPTION 'No active artefact in slot %', p_target_slot_id;
  END IF;

  v_new := app_provenance.sp_load_material_into_slot(
    p_target_slot_id,
    jsonb_build_object(
      'name', coalesce(v_output->>'name', 'Reagent treated sample'),
      'artefact_type_key', coalesce(v_output->>'artefact_type_key','material_sample'),
      'status', coalesce(v_output->>'status','active'),
      'metadata', v_metadata
    ),
    v_current,
    v_relationship_type
  );

  UPDATE app_provenance.artefacts
     SET status = 'consumed',
         updated_at = clock_timestamp()
   WHERE artefact_id = v_current;

  PERFORM app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', coalesce(v_output->>'process_type_key','process_reagent_application'),
      'name', coalesce(v_output->>'process_name','Reagent application'),
      'inputs', jsonb_build_array(
        jsonb_build_object('artefact_id', v_current, 'direction', 'input', 'io_role', 'treated_material', 'is_primary', true),
        jsonb_build_object('artefact_id', p_reagent_artefact_id, 'direction', 'input', 'io_role', 'reagent', 'is_primary', false)
      ),
      'outputs', jsonb_build_array(
        jsonb_build_object('artefact_id', v_new, 'direction', 'output', 'io_role', 'treated_output', 'is_primary', true)
      ),
      'relationships', jsonb_build_array(
        jsonb_build_object('parent_id', v_current, 'child_id', v_new, 'relationship_type', v_relationship_type)
      )
    )
  );

  RETURN v_new;
END;
$$;


--
-- Name: sp_complete_transfer(uuid, uuid[], text, text, jsonb); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_complete_transfer(p_target_artefact_id uuid, p_return_scope_ids uuid[] DEFAULT NULL::uuid[], p_relationship_type text DEFAULT 'handover_duplicate'::text, p_completion_state text DEFAULT 'returned'::text, p_state_metadata jsonb DEFAULT '{}'::jsonb) RETURNS void
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


--
-- Name: sp_demultiplex_outputs(uuid, jsonb, jsonb); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_demultiplex_outputs(p_pool_artefact_id uuid, p_run_metadata jsonb, p_contributors jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_contrib jsonb := coalesce(p_contributors, '[]'::jsonb);
  v_entry jsonb;
  v_outputs jsonb := '[]'::jsonb;
  v_relationships jsonb := '[]'::jsonb;
  v_new uuid;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_contrib) <> 'array' THEN
    RAISE EXCEPTION 'Contributor map must be array';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_contrib)
  LOOP
    IF jsonb_typeof(v_entry) <> 'object' THEN
      RAISE EXCEPTION 'Contributor entry must be object';
    END IF;

    v_new := app_provenance.sp_load_material_into_slot(
      NULLIF(v_entry->>'slot_id','')::uuid,
      jsonb_build_object(
        'name', coalesce(v_entry->>'name', 'Demultiplexed output'),
        'artefact_type_key', coalesce(v_entry->>'artefact_type_key', 'data_product_sequence'),
        'metadata', coalesce(v_entry->'metadata', '{}'::jsonb)
      ),
      p_pool_artefact_id,
      'produced_output'
    );

    v_outputs := v_outputs || jsonb_build_array(jsonb_build_object('artefact_id', v_new, 'direction', 'output', 'io_role', 'demultiplexed_output'));
    v_relationships := v_relationships || jsonb_build_array(jsonb_build_object('parent_id', p_pool_artefact_id, 'child_id', v_new, 'relationship_type', 'produced_output'));
  END LOOP;

  RETURN app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', 'process_demultiplex',
      'name', 'Demultiplex outputs',
      'metadata', coalesce(p_run_metadata, '{}'::jsonb),
      'inputs', jsonb_build_array(jsonb_build_object('artefact_id', p_pool_artefact_id, 'direction', 'input', 'io_role', 'pool', 'is_primary', true)),
      'outputs', v_outputs,
      'relationships', v_relationships
    )
  );
END;
$$;


--
-- Name: sp_fragment_plate(uuid, uuid, uuid, jsonb); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_fragment_plate(p_source_plate_id uuid, p_reagent_artefact_id uuid, p_destination_plate_id uuid, p_mapping jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_map jsonb := coalesce(p_mapping, '[]'::jsonb);
  v_entry jsonb;
  v_source_slot_id uuid;
  v_dest_slot_id uuid;
  v_source_art uuid;
  v_new uuid;
  v_inputs jsonb := '[]'::jsonb;
  v_outputs jsonb := '[]'::jsonb;
  v_relationships jsonb := '[]'::jsonb;
  v_seen uuid[] := ARRAY[]::uuid[];
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_map) <> 'array' THEN
    RAISE EXCEPTION 'Mapping must be array';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_map)
  LOOP
    IF jsonb_typeof(v_entry) <> 'object' THEN
      RAISE EXCEPTION 'Mapping entry must be object';
    END IF;

    SELECT container_slot_id INTO v_source_slot_id
      FROM app_provenance.container_slots
     WHERE container_artefact_id = p_source_plate_id
       AND slot_name = v_entry->>'source_slot'
     LIMIT 1;

    SELECT container_slot_id INTO v_dest_slot_id
      FROM app_provenance.container_slots
     WHERE container_artefact_id = p_destination_plate_id
       AND slot_name = v_entry->>'dest_slot'
     LIMIT 1;

    IF v_source_slot_id IS NULL OR v_dest_slot_id IS NULL THEN
      RAISE EXCEPTION 'Invalid source/destination slot in mapping entry %', v_entry::text;
    END IF;

    SELECT artefact_id INTO v_source_art
      FROM app_provenance.artefacts
     WHERE container_slot_id = v_source_slot_id
     ORDER BY updated_at DESC
     LIMIT 1;

    IF v_source_art IS NULL THEN
      RAISE EXCEPTION 'No artefact found in source slot %', v_entry->>'source_slot';
    END IF;

    v_new := app_provenance.sp_load_material_into_slot(
      v_dest_slot_id,
      jsonb_build_object(
        'name', coalesce(v_entry->>'output_name', format('Fragment %s', v_entry->>'dest_slot')),
        'artefact_type_key', coalesce(v_entry->>'artefact_type_key', 'material_sample'),
        'metadata', coalesce(v_entry->'metadata', '{}'::jsonb)
      ),
      v_source_art,
      coalesce(v_entry->>'relationship_type','derived_from')
    );

    v_outputs := v_outputs
      || jsonb_build_array(
           jsonb_build_object(
             'artefact_id', v_new,
             'direction', 'output',
             'io_role', 'fragment_output'
           )
         );
    v_relationships := v_relationships || jsonb_build_array(jsonb_build_object('parent_id', v_source_art, 'child_id', v_new, 'relationship_type', coalesce(v_entry->>'relationship_type','derived_from')));

    IF NOT (v_source_art = ANY(v_seen)) THEN
      v_inputs := v_inputs || jsonb_build_array(jsonb_build_object('artefact_id', v_source_art, 'direction', 'input', 'io_role', 'source_fragment', 'is_primary', true));
      v_seen := array_append(v_seen, v_source_art);
    END IF;
  END LOOP;

  IF p_reagent_artefact_id IS NOT NULL THEN
    v_inputs := v_inputs || jsonb_build_array(jsonb_build_object('artefact_id', p_reagent_artefact_id, 'direction', 'input', 'io_role', 'reagent', 'is_primary', false));
  END IF;

  RETURN app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', 'process_fragment_plate',
      'name', 'Plate fragmentation',
      'inputs', v_inputs,
      'outputs', v_outputs,
      'relationships', v_relationships,
      'status', 'completed'
    )
  );
END;
$$;


--
-- Name: sp_handover_to_ops(uuid, text, uuid[], text[]); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_handover_to_ops(p_research_scope_id uuid, p_ops_scope_key text, p_artefact_ids uuid[], p_field_whitelist text[] DEFAULT '{}'::text[]) RETURNS uuid
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


--
-- Name: sp_index_libraries(uuid, jsonb, uuid); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_index_libraries(p_source_plate_id uuid, p_index_manifest jsonb, p_destination_plate_id uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_manifest jsonb := coalesce(p_index_manifest, '[]'::jsonb);
  v_entry jsonb;
  v_source_slot uuid;
  v_dest_slot uuid;
  v_source uuid;
  v_new uuid;
  v_inputs jsonb := '[]'::jsonb;
  v_outputs jsonb := '[]'::jsonb;
  v_relationships jsonb := '[]'::jsonb;
  v_seen uuid[] := ARRAY[]::uuid[];
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_manifest) <> 'array' THEN
    RAISE EXCEPTION 'Index manifest must be array';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_manifest)
  LOOP
    SELECT container_slot_id INTO v_source_slot
      FROM app_provenance.container_slots
     WHERE container_artefact_id = p_source_plate_id
       AND slot_name = v_entry->>'source_slot'
     LIMIT 1;

    SELECT container_slot_id INTO v_dest_slot
      FROM app_provenance.container_slots
     WHERE container_artefact_id = p_destination_plate_id
       AND slot_name = v_entry->>'dest_slot'
     LIMIT 1;

    IF v_source_slot IS NULL OR v_dest_slot IS NULL THEN
      RAISE EXCEPTION 'Invalid source or dest slot for index entry %', v_entry::text;
    END IF;

    SELECT artefact_id INTO v_source
      FROM app_provenance.artefacts
     WHERE container_slot_id = v_source_slot
     ORDER BY updated_at DESC
     LIMIT 1;

    IF v_source IS NULL THEN
      RAISE EXCEPTION 'No artefact in source slot %', v_entry->>'source_slot';
    END IF;

    v_new := app_provenance.sp_load_material_into_slot(
      v_dest_slot,
      jsonb_build_object(
        'name', coalesce(v_entry->>'output_name', format('Library %s', v_entry->>'dest_slot')),
        'metadata', coalesce(v_entry->'metadata', '{}'::jsonb) || jsonb_build_object('index_pair', v_entry->>'index_pair')
      ),
      v_source,
      'derived_from'
    );

    v_outputs := v_outputs
      || jsonb_build_array(
           jsonb_build_object(
             'artefact_id', v_new,
             'direction', 'output',
             'io_role', 'library_output'
           )
         );
    v_relationships := v_relationships || jsonb_build_array(jsonb_build_object(
      'parent_id', v_source,
      'child_id', v_new,
      'relationship_type', 'derived_from',
      'metadata', jsonb_build_object('index_pair', v_entry->>'index_pair')
    ));

    IF NOT (v_source = ANY(v_seen)) THEN
      v_inputs := v_inputs || jsonb_build_array(jsonb_build_object('artefact_id', v_source, 'direction', 'input', 'io_role', 'source_library', 'is_primary', true));
      v_seen := array_append(v_seen, v_source);
    END IF;
  END LOOP;

  RETURN app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', 'process_indexing',
      'name', 'Index assignment',
      'inputs', v_inputs,
      'outputs', v_outputs,
      'relationships', v_relationships,
      'status', 'completed'
    )
  );
END;
$$;


--
-- Name: sp_load_material_into_slot(uuid, jsonb, uuid, text); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_load_material_into_slot(p_slot_id uuid, p_material jsonb, p_parent_artefact_id uuid DEFAULT NULL::uuid, p_relationship_type text DEFAULT 'derived_from'::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_material jsonb := coalesce(p_material, '{}'::jsonb);
  v_slot RECORD;
  v_type_id uuid;
  v_name text;
  v_status text;
  v_metadata jsonb;
  v_quantity numeric;
  v_quantity_unit text;
  v_external text;
  v_is_virtual boolean := COALESCE((v_material->>'is_virtual')::boolean, false);
  v_container uuid;
  v_slot_name text;
  v_actor uuid := app_security.current_actor_id();
  v_existing uuid;
  v_new uuid;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_material) <> 'object' THEN
    RAISE EXCEPTION 'Material payload must be an object';
  END IF;

  v_name := coalesce(v_material->>'name', v_material->>'display_name');
  IF v_name IS NULL OR trim(v_name) = '' THEN
    RAISE EXCEPTION 'Material name is required';
  END IF;

  v_status := coalesce(v_material->>'status', 'active');
  v_metadata := coalesce(v_material->'metadata', '{}'::jsonb);
  IF jsonb_typeof(v_metadata) <> 'object' THEN
    RAISE EXCEPTION 'Material metadata must be an object';
  END IF;

  v_quantity := NULLIF(v_material->>'quantity', '')::numeric;
  v_quantity_unit := NULLIF(v_material->>'quantity_unit', '');
  v_external := NULLIF(v_material->>'external_identifier', '');

  v_type_id := app_provenance.get_artefact_type_id(coalesce(v_material->>'artefact_type_key', 'material_sample'));
  IF v_type_id IS NULL THEN
    RAISE EXCEPTION 'Unknown material type %', coalesce(v_material->>'artefact_type_key', 'material_sample');
  END IF;

  IF p_slot_id IS NOT NULL THEN
    SELECT cs.container_slot_id,
           cs.container_artefact_id,
           cs.slot_name,
           container.name AS container_name
      INTO v_slot
      FROM app_provenance.container_slots cs
      JOIN app_provenance.artefacts container ON container.artefact_id = cs.container_artefact_id
     WHERE cs.container_slot_id = p_slot_id
     LIMIT 1;

    IF v_slot.container_slot_id IS NULL THEN
      RAISE EXCEPTION 'Container slot % not found', p_slot_id;
    END IF;

    v_container := v_slot.container_artefact_id;
    v_slot_name := v_slot.slot_name;

    SELECT artefact_id INTO v_existing
      FROM app_provenance.artefacts
     WHERE container_slot_id = v_slot.container_slot_id
       AND status IN ('active','reserved')
     ORDER BY updated_at DESC
     LIMIT 1;

    IF v_existing IS NOT NULL THEN
      UPDATE app_provenance.artefacts
         SET status = 'retired',
             updated_at = clock_timestamp(),
             updated_by = v_actor
       WHERE artefact_id = v_existing;
    END IF;
  ELSE
    v_container := NULLIF(v_material->>'container_artefact_id', '')::uuid;
    v_slot_name := v_material->>'container_slot_name';
  END IF;

  INSERT INTO app_provenance.artefacts (
    artefact_type_id,
    name,
    external_identifier,
    status,
    is_virtual,
    quantity,
    quantity_unit,
    metadata,
    container_artefact_id,
    container_slot_id,
    created_by,
    updated_by
  )
  VALUES (
    v_type_id,
    v_name,
    v_external,
    v_status,
    v_is_virtual,
    v_quantity,
    v_quantity_unit,
    v_metadata || jsonb_build_object('source', 'sp_load_material_into_slot', 'container_slot', v_slot_name),
    v_container,
    p_slot_id,
    v_actor,
    v_actor
  )
  RETURNING artefact_id INTO v_new;

  IF p_parent_artefact_id IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_relationships (
      parent_artefact_id,
      child_artefact_id,
      relationship_type,
      metadata,
      created_by
    )
    VALUES (
      p_parent_artefact_id,
      v_new,
      lower(coalesce(p_relationship_type, 'derived_from')),
      jsonb_build_object('source', 'sp_load_material_into_slot'),
      v_actor
    )
    ON CONFLICT ON CONSTRAINT artefact_relationships_parent_artefact_id_child_artefact_id_key DO NOTHING;
  END IF;

  IF v_container IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
    SELECT v_new,
           scope_id,
           relationship,
           v_actor,
           coalesce(metadata, '{}'::jsonb) || jsonb_build_object('source','sp_load_material_into_slot','origin','container')
      FROM app_provenance.artefact_scopes
     WHERE artefact_id = v_container
       AND relationship = 'primary'
    ON CONFLICT ON CONSTRAINT artefact_scopes_pkey DO UPDATE
      SET metadata = coalesce(app_provenance.artefact_scopes.metadata, '{}'::jsonb)
                     || jsonb_build_object('source','sp_load_material_into_slot','origin','container');
  END IF;

  IF p_parent_artefact_id IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
    SELECT v_new,
           scope_id,
           relationship,
           v_actor,
           coalesce(metadata, '{}'::jsonb) || jsonb_build_object('source','sp_load_material_into_slot','origin','parent')
      FROM app_provenance.artefact_scopes
     WHERE artefact_id = p_parent_artefact_id
       AND relationship = 'primary'
    ON CONFLICT ON CONSTRAINT artefact_scopes_pkey DO UPDATE
      SET metadata = coalesce(app_provenance.artefact_scopes.metadata, '{}'::jsonb)
                     || jsonb_build_object('source','sp_load_material_into_slot','origin','parent');
  END IF;

  RETURN v_new;
END;
$$;


--
-- Name: sp_plate_measurement(jsonb, jsonb); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_plate_measurement(p_process jsonb, p_measurements jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_measurements jsonb := coalesce(p_measurements, '[]'::jsonb);
  v_entry jsonb;
  v_slot uuid;
  v_sample uuid;
  v_traits jsonb;
  v_outputs jsonb := '[]'::jsonb;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_measurements) <> 'array' THEN
    RAISE EXCEPTION 'Measurements must be array';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_measurements)
  LOOP
    SELECT container_slot_id INTO v_slot
      FROM app_provenance.container_slots
     WHERE container_artefact_id = (p_process->>'plate_id')::uuid
       AND slot_name = v_entry->>'slot_name'
     LIMIT 1;

    IF v_slot IS NULL THEN
      RAISE EXCEPTION 'Unknown slot % in measurement set', v_entry->>'slot_name';
    END IF;

    SELECT artefact_id INTO v_sample
      FROM app_provenance.artefacts
     WHERE container_slot_id = v_slot
     ORDER BY updated_at DESC
     LIMIT 1;

    IF v_sample IS NULL THEN
      CONTINUE;
    END IF;

    v_traits := coalesce(v_entry->'traits', '{}'::jsonb);
    IF jsonb_typeof(v_traits) <> 'object' THEN
      RAISE EXCEPTION 'Measurement traits must be object';
    END IF;

    UPDATE app_provenance.artefacts
       SET metadata = coalesce(metadata, '{}'::jsonb) || v_traits || jsonb_build_object('last_measurement_at', clock_timestamp()),
           updated_at = clock_timestamp(),
           updated_by = app_security.current_actor_id()
     WHERE artefact_id = v_sample;

    v_outputs := v_outputs || jsonb_build_array(
      jsonb_build_object(
        'artefact_id', v_sample,
        'direction', 'output',
        'io_role', 'measured_sample',
        'metadata', jsonb_build_object('source','sp_plate_measurement')
      )
    );
  END LOOP;

  RETURN app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', coalesce(p_process->>'process_type_key', 'process_plate_measurement'),
      'name', coalesce(p_process->>'name', 'Plate measurement'),
      'status', coalesce(p_process->>'status', 'completed'),
      'metadata', coalesce(p_process->'metadata', '{}'::jsonb),
      'inputs', coalesce(p_process->'inputs', '[]'::jsonb),
      'outputs', CASE
                   WHEN jsonb_array_length(coalesce(p_process->'outputs', '[]'::jsonb)) > 0 THEN
                     coalesce(p_process->'outputs', '[]'::jsonb)
                   ELSE
                     v_outputs
                 END
    )
  );
END;
$$;


--
-- Name: sp_pool_fixed_volume(uuid[], uuid, numeric, jsonb); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_pool_fixed_volume(p_input_slots uuid[], p_destination_slot_id uuid, p_volume_ul numeric, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_meta jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_slot uuid;
  v_inputs jsonb := '[]'::jsonb;
  v_relationships jsonb := '[]'::jsonb;
  v_outputs jsonb;
  v_source_slot uuid;
  v_source uuid;
  v_pool uuid;
  v_total numeric;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF p_destination_slot_id IS NULL THEN
    RAISE EXCEPTION 'Destination slot id required';
  END IF;

  IF p_input_slots IS NULL OR array_length(p_input_slots,1) IS NULL THEN
    RAISE EXCEPTION 'At least one source slot required';
  END IF;

  v_total := coalesce(p_volume_ul, 0) * array_length(p_input_slots,1);

  FOREACH v_source_slot IN ARRAY p_input_slots
  LOOP
    SELECT artefact_id INTO v_source
      FROM app_provenance.artefacts
     WHERE container_slot_id = v_source_slot
     ORDER BY updated_at DESC
     LIMIT 1;

    IF v_source IS NULL THEN
      RAISE EXCEPTION 'No artefact found in source slot %', v_source_slot;
    END IF;

    v_inputs := v_inputs || jsonb_build_array(jsonb_build_object(
      'artefact_id', v_source,
      'direction', 'pooled_input',
      'io_role', 'pool_component',
      'quantity', p_volume_ul,
      'quantity_unit', 'ul',
      'is_primary', true
    ));

    v_relationships := v_relationships || jsonb_build_array(jsonb_build_object('parent_id', v_source, 'relationship_type', 'pooled_from'));
  END LOOP;

  v_pool := app_provenance.sp_load_material_into_slot(
    p_destination_slot_id,
    jsonb_build_object(
      'name', coalesce(v_meta->>'name', 'Pooled sample'),
      'metadata', v_meta,
      'quantity', v_total,
      'quantity_unit', 'ul'
    ),
    NULL,
    'pooled_output'
  );

  v_outputs := jsonb_build_array(jsonb_build_object(
    'artefact_id', v_pool,
    'direction', 'pooled_output',
    'io_role', 'pool',
    'quantity', v_total,
    'quantity_unit', 'ul',
    'is_primary', true
  ));

  -- fill child ids for relationships
  v_relationships := COALESCE(
    (SELECT jsonb_agg(elem || jsonb_build_object('child_id', v_pool)) FROM jsonb_array_elements(v_relationships) elem),
    '[]'::jsonb
  );

  RETURN app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', 'process_pooling',
      'name', 'Fixed volume pooling',
      'metadata', v_meta,
      'inputs', v_inputs,
      'outputs', v_outputs,
      'relationships', v_relationships
    )
  );
END;
$$;


--
-- Name: sp_record_process_with_io(jsonb); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_record_process_with_io(p_process jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_payload jsonb := coalesce(p_process, '{}'::jsonb);
  v_type_id uuid;
  v_name text;
  v_status text;
  v_started timestamptz;
  v_completed timestamptz;
  v_identifier text;
  v_metadata jsonb;
  v_actor uuid := app_security.current_actor_id();
  v_process_id uuid;
  v_item jsonb;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_payload) <> 'object' THEN
    RAISE EXCEPTION 'Process payload must be object';
  END IF;

  v_type_id := app_provenance.get_process_type_id(coalesce(v_payload->>'process_type_key', v_payload->>'type_key'));
  IF v_type_id IS NULL THEN
    RAISE EXCEPTION 'Unknown process type %', coalesce(v_payload->>'process_type_key', v_payload->>'type_key');
  END IF;

  v_name := coalesce(v_payload->>'name', 'Process');
  v_status := coalesce(v_payload->>'status', 'completed');
  v_started := NULLIF(v_payload->>'started_at','')::timestamptz;
  v_completed := NULLIF(v_payload->>'completed_at','')::timestamptz;
  v_identifier := NULLIF(v_payload->>'process_identifier','');
  v_metadata := coalesce(v_payload->'metadata', '{}'::jsonb);
  IF jsonb_typeof(v_metadata) <> 'object' THEN
    RAISE EXCEPTION 'Process metadata must be object';
  END IF;

  INSERT INTO app_provenance.process_instances (
    process_type_id,
    process_identifier,
    name,
    status,
    started_at,
    completed_at,
    executed_by,
    metadata,
    created_by,
    updated_by
  )
  VALUES (
    v_type_id,
    v_identifier,
    v_name,
    v_status,
    v_started,
    v_completed,
    COALESCE(NULLIF(v_payload->>'executed_by','')::uuid, v_actor),
    v_metadata || jsonb_build_object('source', 'sp_record_process_with_io'),
    v_actor,
    v_actor
  )
  RETURNING process_instance_id INTO v_process_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(v_payload->'inputs', '[]'::jsonb))
  LOOP
    INSERT INTO app_provenance.process_io (
      process_instance_id,
      artefact_id,
      direction,
      io_role,
      quantity,
      quantity_unit,
      is_primary,
      multiplex_group,
      metadata
    )
    VALUES (
      v_process_id,
      (v_item->>'artefact_id')::uuid,
      coalesce(v_item->>'direction','input'),
      v_item->>'io_role',
      NULLIF(v_item->>'quantity','')::numeric,
      v_item->>'quantity_unit',
      coalesce((v_item->>'is_primary')::boolean, false),
      v_item->>'multiplex_group',
      coalesce(v_item->'metadata', '{}'::jsonb) || jsonb_build_object('source','sp_record_process_with_io')
    );
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(v_payload->'outputs', '[]'::jsonb))
  LOOP
    INSERT INTO app_provenance.process_io (
      process_instance_id,
      artefact_id,
      direction,
      io_role,
      quantity,
      quantity_unit,
      is_primary,
      multiplex_group,
      metadata
    )
    VALUES (
      v_process_id,
      (v_item->>'artefact_id')::uuid,
      coalesce(v_item->>'direction','output'),
      v_item->>'io_role',
      NULLIF(v_item->>'quantity','')::numeric,
      v_item->>'quantity_unit',
      coalesce((v_item->>'is_primary')::boolean, true),
      v_item->>'multiplex_group',
      coalesce(v_item->'metadata', '{}'::jsonb) || jsonb_build_object('source','sp_record_process_with_io')
    );
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(v_payload->'relationships', '[]'::jsonb))
  LOOP
    INSERT INTO app_provenance.artefact_relationships (
      parent_artefact_id,
      child_artefact_id,
      relationship_type,
      process_instance_id,
      metadata,
      created_by
    )
    VALUES (
      (v_item->>'parent_id')::uuid,
      (v_item->>'child_id')::uuid,
      lower(coalesce(v_item->>'relationship_type','derived_from')),
      v_process_id,
      coalesce(v_item->'metadata', '{}'::jsonb) || jsonb_build_object('source','sp_record_process_with_io'),
      v_actor
    )
    ON CONFLICT ON CONSTRAINT artefact_relationships_parent_artefact_id_child_artefact_id_key DO NOTHING;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(v_payload->'scopes', '[]'::jsonb))
  LOOP
    IF jsonb_typeof(v_item) = 'string' THEN
      INSERT INTO app_provenance.process_scopes (process_instance_id, scope_id, metadata)
      VALUES (v_process_id, (v_item)::text::uuid, jsonb_build_object('source','sp_record_process_with_io'))
      ON CONFLICT DO NOTHING;
    ELSIF jsonb_typeof(v_item) = 'object' THEN
      INSERT INTO app_provenance.process_scopes (process_instance_id, scope_id, metadata)
      VALUES (
        v_process_id,
        (v_item->>'scope_id')::uuid,
        coalesce(v_item->'metadata', '{}'::jsonb) || jsonb_build_object('source','sp_record_process_with_io')
      )
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  WITH referenced AS (
    SELECT DISTINCT (value->>'artefact_id')::uuid AS artefact_id
      FROM jsonb_array_elements(coalesce(v_payload->'inputs', '[]'::jsonb))
     WHERE value ? 'artefact_id'
    UNION
    SELECT DISTINCT (value->>'artefact_id')::uuid AS artefact_id
      FROM jsonb_array_elements(coalesce(v_payload->'outputs', '[]'::jsonb))
     WHERE value ? 'artefact_id'
  )
  INSERT INTO app_provenance.process_scopes (process_instance_id, scope_id, metadata)
  SELECT v_process_id,
         s.scope_id,
         coalesce(s.metadata, '{}'::jsonb) || jsonb_build_object('source','sp_record_process_with_io','origin','artefact')
    FROM referenced r
    JOIN app_provenance.artefact_scopes s
      ON s.artefact_id = r.artefact_id
   WHERE s.relationship = 'primary'
  ON CONFLICT DO NOTHING;

  RETURN v_process_id;
END;
$$;


--
-- Name: sp_register_labware_with_wells(text, jsonb, jsonb, uuid); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_register_labware_with_wells(p_container_type_key text, p_container jsonb, p_wells jsonb DEFAULT '[]'::jsonb, p_scope_id uuid DEFAULT NULL::uuid) RETURNS TABLE(container_id uuid, slot_id uuid, slot_name text, occupant_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_container jsonb := coalesce(p_container, '{}'::jsonb);
  v_wells jsonb := coalesce(p_wells, '[]'::jsonb);
  v_type_id uuid;
  v_container_id uuid;
  v_actor uuid := app_security.current_actor_id();
  v_scope uuid := p_scope_id;
  v_slot jsonb;
  v_slot_id uuid;
  v_existing uuid;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_container) <> 'object' THEN
    RAISE EXCEPTION 'Container payload must be object';
  END IF;

  IF coalesce(v_container->>'name', v_container->>'display_name', '') = '' THEN
    RAISE EXCEPTION 'Container name is required';
  END IF;

  v_type_id := app_provenance.get_artefact_type_id(p_container_type_key);
  IF v_type_id IS NULL THEN
    RAISE EXCEPTION 'Unknown container type %', p_container_type_key;
  END IF;

  SELECT artefact_id
    INTO v_existing
    FROM app_provenance.artefacts
   WHERE external_identifier = NULLIF(v_container->>'external_identifier','')
     AND artefact_type_id = v_type_id
   LIMIT 1;

  IF v_existing IS NULL THEN
    INSERT INTO app_provenance.artefacts (
      artefact_type_id,
      name,
      external_identifier,
      status,
      metadata,
      created_by,
      updated_by
    )
    VALUES (
      v_type_id,
      coalesce(v_container->>'name', v_container->>'display_name'),
      NULLIF(v_container->>'external_identifier',''),
      coalesce(v_container->>'status', 'active'),
      coalesce(v_container->'metadata', '{}'::jsonb) || jsonb_build_object('source', 'sp_register_labware_with_wells'),
      v_actor,
      v_actor
    )
    RETURNING artefact_id INTO v_container_id;
  ELSE
    UPDATE app_provenance.artefacts
       SET name = coalesce(v_container->>'name', v_container->>'display_name'),
           status = coalesce(v_container->>'status', 'active'),
           metadata = coalesce(metadata, '{}'::jsonb)
                      || coalesce(v_container->'metadata', '{}'::jsonb)
                      || jsonb_build_object('source', 'sp_register_labware_with_wells', 'updated_at', clock_timestamp()),
           updated_at = clock_timestamp(),
           updated_by = v_actor
     WHERE artefact_id = v_existing;
    v_container_id := v_existing;
  END IF;

  IF v_scope IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
    VALUES (v_container_id, v_scope, 'primary', v_actor, jsonb_build_object('source', 'sp_register_labware_with_wells'))
    ON CONFLICT ON CONSTRAINT artefact_scopes_pkey DO UPDATE
      SET metadata = coalesce(app_provenance.artefact_scopes.metadata, '{}'::jsonb)
                     || jsonb_build_object('source', 'sp_register_labware_with_wells'),
          assigned_at = clock_timestamp();
  END IF;

  IF jsonb_typeof(v_wells) <> 'array' THEN
    RAISE EXCEPTION 'Well definitions must be array';
  END IF;

  FOR v_slot IN SELECT value FROM jsonb_array_elements(v_wells)
  LOOP
    IF jsonb_typeof(v_slot) <> 'object' THEN
      RAISE EXCEPTION 'Well definition must be object';
    END IF;

    IF coalesce(v_slot->>'slot_name', '') = '' THEN
      RAISE EXCEPTION 'slot_name required in well definition';
    END IF;

    INSERT INTO app_provenance.container_slots (
      container_artefact_id,
      slot_definition_id,
      slot_name,
      display_name,
      position,
      metadata
    )
    VALUES (
      v_container_id,
      NULL,
      v_slot->>'slot_name',
      v_slot->>'display_name',
      v_slot->'position',
      coalesce(v_slot->'metadata', '{}'::jsonb) || jsonb_build_object('source', 'sp_register_labware_with_wells')
    )
    ON CONFLICT ON CONSTRAINT container_slots_container_artefact_id_slot_name_key DO UPDATE
      SET display_name = COALESCE(EXCLUDED.display_name, app_provenance.container_slots.display_name),
          position = COALESCE(EXCLUDED.position, app_provenance.container_slots.position),
          metadata = coalesce(app_provenance.container_slots.metadata, '{}'::jsonb)
                    || coalesce(EXCLUDED.metadata, '{}'::jsonb)
                    || jsonb_build_object('source', 'sp_register_labware_with_wells')
    RETURNING container_slot_id INTO v_slot_id;

    container_id := v_container_id;
    slot_id := v_slot_id;
    slot_name := v_slot->>'slot_name';

    IF v_slot ? 'occupant' THEN
      occupant_id := app_provenance.sp_load_material_into_slot(
        v_slot_id,
        v_slot->'occupant',
        NULLIF((v_slot->'occupant')->>'parent_artefact_id','')::uuid,
        coalesce((v_slot->'occupant')->>'relationship_type', v_slot->>'relationship_type', 'derived_from')
      );
    ELSE
      occupant_id := NULL;
    END IF;

    RETURN NEXT;
  END LOOP;
END;
$$;


--
-- Name: sp_register_virtual_manifest(uuid, jsonb, text); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_register_virtual_manifest(p_scope_id uuid, p_manifest jsonb, p_default_type_key text DEFAULT 'material_sample'::text) RETURNS TABLE(artefact_id uuid, artefact_name text, external_identifier text, was_created boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_manifest jsonb := coalesce(p_manifest, '[]'::jsonb);
  v_entry jsonb;
  v_type_id uuid;
  v_actor uuid := app_security.current_actor_id();
  v_scope uuid := p_scope_id;
  v_existing uuid;
  v_created boolean;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_manifest) <> 'array' THEN
    RAISE EXCEPTION 'Manifest payload must be an array';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_manifest)
  LOOP
    IF jsonb_typeof(v_entry) <> 'object' THEN
      RAISE EXCEPTION 'Manifest entries must be JSON objects';
    END IF;

    IF coalesce(v_entry->>'name', v_entry->>'display_name', '') = '' THEN
      RAISE EXCEPTION 'Manifest entry missing name';
    END IF;

    v_type_id := app_provenance.get_artefact_type_id(coalesce(v_entry->>'artefact_type_key', p_default_type_key));
    IF v_type_id IS NULL THEN
      RAISE EXCEPTION 'Unknown artefact type %', coalesce(v_entry->>'artefact_type_key', p_default_type_key);
    END IF;

    SELECT a.artefact_id
      INTO v_existing
      FROM app_provenance.artefacts a
     WHERE a.external_identifier = NULLIF(v_entry->>'external_identifier','')
        OR (a.name = v_entry->>'name' AND a.is_virtual)
     LIMIT 1;

    v_created := false;

    IF v_existing IS NULL THEN
      INSERT INTO app_provenance.artefacts AS new_art (
        artefact_type_id,
        name,
        external_identifier,
        status,
        is_virtual,
        metadata,
        created_by,
        updated_by
      )
      VALUES (
        v_type_id,
        coalesce(v_entry->>'name', v_entry->>'display_name'),
        NULLIF(v_entry->>'external_identifier',''),
        coalesce(v_entry->>'status', 'active'),
        true,
        coalesce(v_entry->'metadata', '{}'::jsonb) || jsonb_build_object('source', 'sp_register_virtual_manifest'),
        v_actor,
        v_actor
      )
      RETURNING new_art.artefact_id INTO v_existing;
      v_created := true;
    ELSE
      UPDATE app_provenance.artefacts AS upd
         SET artefact_type_id = v_type_id,
             name = coalesce(v_entry->>'name', v_entry->>'display_name'),
             status = coalesce(v_entry->>'status', 'active'),
             metadata = coalesce(upd.metadata, '{}'::jsonb)
                        || coalesce(v_entry->'metadata', '{}'::jsonb)
                        || jsonb_build_object('source', 'sp_register_virtual_manifest', 'updated_at', clock_timestamp()),
             updated_at = clock_timestamp(),
             updated_by = v_actor,
             external_identifier = COALESCE(NULLIF(v_entry->>'external_identifier',''), upd.external_identifier),
             is_virtual = true
       WHERE upd.artefact_id = v_existing;
    END IF;

    IF v_scope IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
      VALUES (v_existing, v_scope, 'primary', v_actor, jsonb_build_object('source','sp_register_virtual_manifest'))
      ON CONFLICT ON CONSTRAINT artefact_scopes_pkey DO UPDATE
        SET metadata = coalesce(app_provenance.artefact_scopes.metadata, '{}'::jsonb)
                       || jsonb_build_object('source','sp_register_virtual_manifest'),
            assigned_at = clock_timestamp();
    END IF;

    artefact_id := v_existing;
    artefact_name := coalesce(v_entry->>'name', v_entry->>'display_name');
    external_identifier := NULLIF(v_entry->>'external_identifier','');
    was_created := v_created;
    RETURN NEXT;
  END LOOP;
END;
$$;


--
-- Name: sp_return_from_ops(uuid, uuid[]); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_return_from_ops(p_ops_artefact_id uuid, p_research_scope_ids uuid[]) RETURNS void
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


--
-- Name: sp_set_location(jsonb); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_set_location(p_move jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance', 'app_security', 'app_core'
    SET row_security TO 'off'
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
  v_event_type text;
  v_occurred_at timestamptz;
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
  v_event_type := lower(NULLIF(v_payload->>'event_type',''));
  v_occurred_at := coalesce(NULLIF(v_payload->>'occurred_at','')::timestamptz, clock_timestamp());

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

  IF v_event_type IS NULL THEN
    IF v_current IS NULL THEN
      v_event_type := 'register';
    ELSE
      v_event_type := 'move';
    END IF;
  END IF;

  IF v_event_type NOT IN (
    'register',
    'move',
    'check_in',
    'check_out',
    'disposed',
    'location_correction'
  ) THEN
    RAISE EXCEPTION 'invalid storage event type %', v_event_type USING ERRCODE='22000';
  END IF;

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
  VALUES (
    v_to,
    v_child,
    'located_in',
    NULL,
    v_meta || jsonb_build_object(
      'reason', v_reason,
      'source', 'sp_set_location',
      'actor', v_actor,
      'last_event_type', v_event_type,
      'last_event_at', v_occurred_at
    )
  )
  RETURNING relationship_id INTO v_rel_id;

  RETURN v_rel_id;
END;
$$;


--
-- Name: sp_transfer_between_scopes(uuid, text, text, uuid[], text[], uuid, text[], text, jsonb, jsonb); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.sp_transfer_between_scopes(p_source_scope_id uuid, p_target_scope_key text, p_target_scope_type text, p_artefact_ids uuid[], p_field_whitelist text[] DEFAULT '{}'::text[], p_target_parent_scope_id uuid DEFAULT NULL::uuid, p_allowed_roles text[] DEFAULT ARRAY['app_operator'::text, 'app_admin'::text, 'app_automation'::text], p_relationship_type text DEFAULT 'handover_duplicate'::text, p_scope_metadata jsonb DEFAULT '{}'::jsonb, p_relationship_metadata jsonb DEFAULT '{}'::jsonb) RETURNS uuid
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


--
-- Name: storage_path(uuid); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.storage_path(p_storage_node_id uuid) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog', 'public', 'app_provenance'
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


--
-- Name: tg_enforce_container_membership(); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.tg_enforce_container_membership() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public', 'app_provenance'
    AS $$
DECLARE
  v_container uuid;
BEGIN
  IF NEW.container_slot_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT cs.container_artefact_id
  INTO v_container
  FROM app_provenance.container_slots cs
  WHERE cs.container_slot_id = NEW.container_slot_id;

  IF v_container IS NULL THEN
    RAISE EXCEPTION 'Container slot % does not exist', NEW.container_slot_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  IF NEW.container_artefact_id IS NULL THEN
    NEW.container_artefact_id := v_container;
  ELSIF NEW.container_artefact_id <> v_container THEN
    RAISE EXCEPTION 'Slot % belongs to container %, but artefact attempted to link to %',
      NEW.container_slot_id,
      v_container,
      NEW.container_artefact_id
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: tg_propagate_handover(); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.tg_propagate_handover() RETURNS trigger
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


--
-- Name: transfer_allowed_roles(uuid, text); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.transfer_allowed_roles(p_artefact_id uuid, p_relationship_type text DEFAULT 'handover_duplicate'::text) RETURNS text[]
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


--
-- Name: actor_accessible_scopes(text[]); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.actor_accessible_scopes(p_scope_types text[] DEFAULT NULL::text[]) RETURNS TABLE(scope_id uuid, scope_key text, scope_type text, display_name text, role_name text, source_scope_id uuid, source_role_name text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    SET row_security TO 'off'
    AS $$
DECLARE
  v_filter text[];
BEGIN
  IF p_scope_types IS NOT NULL THEN
    v_filter := ARRAY(
      SELECT DISTINCT lower(trim(val))
      FROM unnest(p_scope_types) AS val
      WHERE val IS NOT NULL AND trim(val) <> ''
    );
  END IF;

  RETURN QUERY
  SELECT
    ar.scope_id,
    s.scope_key,
    s.scope_type,
    s.display_name,
    ar.role_name,
    ar.source_scope_id,
    ar.source_role_name
  FROM app_security.actor_scope_roles(app_security.current_actor_id()) ar
  JOIN app_security.scopes s
    ON s.scope_id = ar.scope_id
  WHERE s.is_active
    AND (
      v_filter IS NULL
      OR array_length(v_filter, 1) IS NULL
      OR s.scope_type = ANY(v_filter)
    );
END;
$$;


--
-- Name: actor_has_scope(uuid, text[], uuid); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.actor_has_scope(p_scope_id uuid, p_required_roles text[] DEFAULT NULL::text[], p_actor_id uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    SET row_security TO 'off'
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


--
-- Name: actor_scope_roles(uuid); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.actor_scope_roles(p_actor_id uuid DEFAULT NULL::uuid) RETURNS TABLE(scope_id uuid, role_name text, source_scope_id uuid, source_role_name text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    SET row_security TO 'off'
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


--
-- Name: coerce_roles(text[]); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.coerce_roles(p_roles text[]) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF p_roles IS NULL THEN
    RETURN ARRAY[]::text[];
  END IF;
  RETURN ARRAY(
    SELECT DISTINCT trim(both FROM lower(role_value))
    FROM unnest(p_roles) AS role_value
    WHERE role_value IS NOT NULL AND trim(both FROM role_value) <> ''
  );
END;
$$;


--
-- Name: create_api_token(uuid, text, text[], timestamp with time zone, jsonb, text); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.create_api_token(p_user_id uuid, p_plaintext_token text, p_allowed_roles text[], p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_metadata jsonb DEFAULT '{}'::jsonb, p_client_identifier text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    AS $$
DECLARE
  digest text;
  hint text;
  v_client_id uuid;
  v_token_id uuid;
  v_allowed_roles text[];
  creator uuid := app_security.current_actor_id();
BEGIN
  IF p_plaintext_token IS NULL OR length(p_plaintext_token) < 32 THEN
    RAISE EXCEPTION 'API token must be at least 32 characters';
  END IF;

  digest := encode(digest(p_plaintext_token, 'sha256'), 'hex');
  hint := right(p_plaintext_token, 6);

  IF p_client_identifier IS NOT NULL THEN
    SELECT c.id INTO v_client_id
    FROM app_security.api_clients c
    WHERE c.client_identifier = p_client_identifier
    LIMIT 1;
    IF v_client_id IS NULL THEN
      RAISE EXCEPTION 'Unknown API client identifier %', p_client_identifier;
    END IF;
  END IF;

  v_allowed_roles := ARRAY(
    SELECT DISTINCT trim(both FROM lower(role_value))
    FROM unnest(coalesce(p_allowed_roles, ARRAY[]::text[])) AS role_value
    WHERE role_value IS NOT NULL AND trim(both FROM role_value) <> ''
  );
  v_allowed_roles := coalesce(v_allowed_roles, ARRAY[]::text[]);

  INSERT INTO app_security.api_tokens (
    api_client_id,
    user_id,
    token_digest,
    token_hint,
    allowed_roles,
    expires_at,
    metadata,
    created_by
  )
  VALUES (
    v_client_id,
    p_user_id,
    digest,
    hint,
    v_allowed_roles,
    p_expires_at,
    coalesce(p_metadata, '{}'::jsonb),
    creator
  )
  RETURNING id INTO v_token_id;

  RETURN v_token_id;
END;
$$;


--
-- Name: current_actor_id(); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.current_actor_id() RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    AS $$
DECLARE
  cfg text;
  claims jsonb;
  resolved uuid;
BEGIN
  cfg := current_setting('app.actor_id', true);
  IF cfg IS NOT NULL AND cfg <> '' THEN
    BEGIN
      resolved := cfg::uuid;
      RETURN resolved;
    EXCEPTION WHEN invalid_text_representation THEN
      NULL;
    END;
  END IF;

  claims := app_security.current_claims();
  RETURN app_security.lookup_user_id(claims);
END;
$$;


--
-- Name: current_claims(); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.current_claims() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    AS $$
DECLARE
  raw text;
BEGIN
  raw := current_setting('request.jwt.claims', true);
  IF raw IS NULL OR raw = '' THEN
    RETURN '{}'::jsonb;
  END IF;
  BEGIN
    RETURN raw::jsonb;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN '{}'::jsonb;
  END;
END;
$$;


--
-- Name: current_roles(); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.current_roles() RETURNS text[]
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    AS $$
DECLARE
  claims jsonb := app_security.current_claims();
  collected text[] := ARRAY[]::text[];
  cfg text;
  membership text[];
  active_role text;
BEGIN
  IF claims ? 'roles' THEN
    collected := collected || ARRAY(
      SELECT lower(value)
      FROM jsonb_array_elements_text(claims->'roles') AS value
    );
  END IF;
  IF claims ? 'role' THEN
    collected := array_append(collected, lower(claims->>'role'));
  END IF;

  cfg := current_setting('app.roles', true);
  IF cfg IS NOT NULL AND cfg <> '' THEN
    collected := collected || string_to_array(lower(cfg), ',');
  END IF;

  BEGIN
    active_role := current_setting('role', true);
  EXCEPTION
    WHEN undefined_object THEN
      active_role := NULL;
  END;

  IF active_role IS NULL OR active_role = '' OR lower(active_role) = 'none' THEN
    active_role := lower(current_user::text);
  END IF;

  membership := ARRAY(
    SELECT DISTINCT lower(r.rolname)
    FROM pg_roles r
    WHERE pg_has_role(active_role, r.rolname, 'member')
      AND r.rolname LIKE 'app_%'
  );

  collected := collected || membership;

  collected := ARRAY(SELECT DISTINCT trim(both FROM r) FROM unnest(collected) AS r WHERE r IS NOT NULL AND r <> '');
  RETURN collected;
END;
$$;


--
-- Name: extract_primary_key(text, text, jsonb); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.extract_primary_key(p_schema text, p_table text, p_row jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security'
    AS $$
DECLARE
  pk jsonb;
BEGIN
  IF p_row IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT jsonb_object_agg(att.attname, p_row -> att.attname)
  INTO pk
  FROM pg_index idx
  JOIN pg_attribute att
    ON att.attrelid = idx.indrelid
   AND att.attnum = ANY(idx.indkey)
  WHERE idx.indrelid = format('%I.%I', p_schema, p_table)::regclass
    AND idx.indisprimary;

  RETURN pk;
END;
$$;


--
-- Name: finish_transaction_context(uuid, text, text); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.finish_transaction_context(p_txn_id uuid DEFAULT NULL::uuid, p_status text DEFAULT 'committed'::text, p_reason text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    AS $$
DECLARE
  v_txn uuid;
  v_actor uuid := app_security.current_actor_id();
BEGIN
  IF p_status NOT IN ('committed','rolled_back','cancelled') THEN
    RAISE EXCEPTION 'Unknown transaction status %', p_status;
  END IF;

  IF p_txn_id IS NOT NULL THEN
    v_txn := p_txn_id;
  ELSE
    BEGIN
      v_txn := NULLIF(current_setting('app.txn_id', true), '')::uuid;
    EXCEPTION
      WHEN undefined_object THEN
        v_txn := NULL;
      WHEN invalid_text_representation THEN
        v_txn := NULL;
    END;
  END IF;

  IF v_txn IS NULL THEN
    RAISE EXCEPTION 'No transaction context active to finish';
  END IF;

  UPDATE app_security.transaction_contexts
  SET finished_at = clock_timestamp(),
      finished_status = p_status,
      finished_reason = p_reason,
      finished_by = v_actor
  WHERE txn_id = v_txn;

  PERFORM set_config('app.txn_id', '', true);
  PERFORM set_config('app.impersonated_roles', '', true);
END;
$$;


--
-- Name: has_role(text); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.has_role(p_role text) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    AS $$
  SELECT app_security.session_has_role(p_role);
$$;


--
-- Name: lookup_user_id(jsonb); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.lookup_user_id(p_claims jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    AS $$
DECLARE
  candidate uuid;
BEGIN
  IF p_claims ? 'user_id' THEN
    BEGIN
      candidate := (p_claims ->> 'user_id')::uuid;
      IF EXISTS (SELECT 1 FROM app_core.users u WHERE u.id = candidate) THEN
        RETURN candidate;
      END IF;
    EXCEPTION
      WHEN invalid_text_representation THEN NULL;
    END;
  END IF;

  IF p_claims ? 'sub' THEN
    SELECT u.id INTO candidate
    FROM app_core.users u
    WHERE u.external_id = p_claims->>'sub'
    LIMIT 1;
    IF candidate IS NOT NULL THEN
      RETURN candidate;
    END IF;
  END IF;

  IF p_claims ? 'email' THEN
    SELECT u.id INTO candidate
    FROM app_core.users u
    WHERE lower(u.email::text) = lower(p_claims->>'email')
    LIMIT 1;
    IF candidate IS NOT NULL THEN
      RETURN candidate;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;


--
-- Name: mark_transaction_committed(); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.mark_transaction_committed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security'
    AS $$
BEGIN
  UPDATE app_security.transaction_contexts
  SET finished_at = clock_timestamp(),
      finished_status = 'committed'
  WHERE txn_id = NEW.txn_id
    AND finished_status IS NULL;
  RETURN NEW;
END;
$$;


--
-- Name: pre_request(); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.pre_request() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    AS $$
DECLARE
  claims jsonb := app_security.current_claims();
  actor uuid;
  roles text[];
  actor_identifier text;
  http_method text;
  request_path text;
BEGIN
  actor := app_security.lookup_user_id(claims);

  IF claims ? 'roles' THEN
    roles := ARRAY(
      SELECT DISTINCT lower(value)
      FROM jsonb_array_elements_text(claims->'roles') AS value
      WHERE value IS NOT NULL
    );
  ELSE
    roles := ARRAY[]::text[];
  END IF;

  IF claims ? 'role' THEN
    roles := array_append(roles, lower(claims->>'role'));
  END IF;

  roles := ARRAY(SELECT DISTINCT r FROM unnest(roles) AS r WHERE r IS NOT NULL AND r <> '');

  IF claims ? 'sub' THEN
    actor_identifier := claims->>'sub';
  ELSIF claims ? 'email' THEN
    actor_identifier := lower(claims->>'email');
  END IF;

  PERFORM set_config('app.jwt_claims', claims::text, true);
  IF actor IS NOT NULL THEN
    PERFORM set_config('app.actor_id', actor::text, true);
  ELSE
    PERFORM set_config('app.actor_id', '', true);
  END IF;
  PERFORM set_config('app.actor_identity', coalesce(actor_identifier, ''), true);
  PERFORM set_config('app.roles', array_to_string(roles, ','), true);
  PERFORM set_config('app.client_app', 'postgrest', true);

  BEGIN
    http_method := upper(current_setting('request.method', true));
  EXCEPTION
    WHEN undefined_object THEN
      http_method := NULL;
  END;

  IF http_method IS NOT NULL THEN
    PERFORM set_config('app.http_method', http_method, true);
  END IF;

  BEGIN
    request_path := current_setting('request.path', true);
  EXCEPTION
    WHEN undefined_object THEN
      request_path := NULL;
  END;

  IF (coalesce(current_setting('app.txn_id', true), '') = '') AND http_method IN ('POST','PUT','PATCH','DELETE') THEN
    PERFORM app_security.start_transaction_context(
      p_actor_id => actor,
      p_actor_identity => actor_identifier,
      p_effective_roles => roles,
      p_impersonated_roles => NULL,
      p_client_app => 'postgrest',
      p_client_ip => NULL,
      p_jwt_claims => claims,
      p_metadata => jsonb_strip_nulls(jsonb_build_object(
        'http_method', http_method,
        'request_path', request_path
      ))
    );
  END IF;
END;
$$;


--
-- Name: record_audit(); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.record_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    AS $$
DECLARE
  v_txn text;
  v_txn_id uuid;
  v_actor uuid;
  v_identity text;
  v_roles text[];
  v_before jsonb;
  v_after jsonb;
  v_primary_key jsonb;
BEGIN
  v_txn := app_security.require_transaction_context();
  BEGIN
    v_txn_id := v_txn::uuid;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'Transaction context % is not a valid UUID', v_txn;
  END;

  BEGIN
    v_actor := NULLIF(current_setting('app.actor_id', true), '')::uuid;
  EXCEPTION
    WHEN invalid_text_representation THEN
      v_actor := NULL;
    WHEN undefined_object THEN
      v_actor := NULL;
  END;

  BEGIN
    v_identity := current_setting('app.actor_identity', true);
  EXCEPTION
    WHEN undefined_object THEN
      v_identity := NULL;
  END;
  v_roles := app_security.current_roles();

  IF TG_OP = 'DELETE' THEN
    v_before := to_jsonb(OLD);
    v_after := NULL;
    v_primary_key := app_security.extract_primary_key(TG_TABLE_SCHEMA, TG_TABLE_NAME, to_jsonb(OLD));
  ELSIF TG_OP = 'INSERT' THEN
    v_before := NULL;
    v_after := to_jsonb(NEW);
    v_primary_key := app_security.extract_primary_key(TG_TABLE_SCHEMA, TG_TABLE_NAME, to_jsonb(NEW));
  ELSE
    v_before := to_jsonb(OLD);
    v_after := to_jsonb(NEW);
    v_primary_key := app_security.extract_primary_key(TG_TABLE_SCHEMA, TG_TABLE_NAME, to_jsonb(NEW));
  END IF;

  INSERT INTO app_security.audit_log (
    txn_id,
    schema_name,
    table_name,
    operation,
    primary_key_data,
    row_before,
    row_after,
    actor_id,
    actor_identity,
    actor_roles
  )
  VALUES (
    v_txn_id,
    TG_TABLE_SCHEMA,
    TG_TABLE_NAME,
    TG_OP,
    v_primary_key,
    v_before,
    v_after,
    v_actor,
    NULLIF(v_identity, ''),
    v_roles
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;


--
-- Name: require_transaction_context(); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.require_transaction_context() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_txn text;
BEGIN
  BEGIN
    v_txn := current_setting('app.txn_id', true);
  EXCEPTION
    WHEN undefined_object THEN
      v_txn := NULL;
  END;

  IF v_txn IS NULL OR v_txn = '' THEN
    PERFORM app_security.start_transaction_context();
    BEGIN
      v_txn := current_setting('app.txn_id', true);
    EXCEPTION
      WHEN undefined_object THEN
        v_txn := NULL;
    END;
  END IF;

  IF v_txn IS NULL OR v_txn = '' THEN
    RAISE EXCEPTION 'app.txn_id is not set; start_transaction_context() must be called before writing'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN v_txn;
END;
$$;


--
-- Name: session_has_role(text); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.session_has_role(p_role text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
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


--
-- Name: start_transaction_context(uuid, text, text[], text[], text, inet, jsonb, jsonb); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.start_transaction_context(p_actor_id uuid DEFAULT NULL::uuid, p_actor_identity text DEFAULT NULL::text, p_effective_roles text[] DEFAULT NULL::text[], p_impersonated_roles text[] DEFAULT NULL::text[], p_client_app text DEFAULT NULL::text, p_client_ip inet DEFAULT NULL::inet, p_jwt_claims jsonb DEFAULT NULL::jsonb, p_metadata jsonb DEFAULT NULL::jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_security', 'app_core'
    AS $$
DECLARE
  v_existing text;
  v_txn_id uuid := gen_random_uuid();
  v_claims jsonb;
  v_actor uuid;
  v_identity text;
  v_roles text[];
  v_impersonated text[];
  v_client_app text;
  v_client_ip inet := p_client_ip;
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
BEGIN
  BEGIN
    v_existing := current_setting('app.txn_id', true);
  EXCEPTION
    WHEN undefined_object THEN
      v_existing := NULL;
  END;

  IF v_existing IS NOT NULL AND v_existing <> '' THEN
    RETURN v_existing::uuid;
  END IF;

  v_claims := coalesce(p_jwt_claims, app_security.current_claims());
  v_actor := coalesce(p_actor_id, app_security.current_actor_id());
  v_identity := coalesce(p_actor_identity, current_setting('app.actor_identity', true));
  v_roles := app_security.coerce_roles(coalesce(p_effective_roles, app_security.current_roles()));
  v_impersonated := app_security.coerce_roles(p_impersonated_roles);

  BEGIN
    v_client_app := coalesce(p_client_app, NULLIF(current_setting('app.client_app', true), ''));
  EXCEPTION
    WHEN undefined_object THEN
      v_client_app := p_client_app;
  END;

  IF v_client_ip IS NULL THEN
    BEGIN
      v_client_ip := NULLIF(current_setting('app.client_ip', true), '')::inet;
    EXCEPTION
      WHEN undefined_object THEN
        v_client_ip := NULL;
      WHEN invalid_text_representation THEN
        v_client_ip := NULL;
    END;
  END IF;

  INSERT INTO app_security.transaction_contexts (
    txn_id,
    actor_id,
    actor_identity,
    actor_roles,
    impersonated_roles,
    jwt_claims,
    client_app,
    client_ip,
    metadata
  )
  VALUES (
    v_txn_id,
    v_actor,
    v_identity,
    v_roles,
    v_impersonated,
    coalesce(p_jwt_claims, v_claims),
    v_client_app,
    v_client_ip,
    v_metadata
  );

  PERFORM set_config('app.txn_id', v_txn_id::text, true);
  PERFORM set_config('app.actor_id', COALESCE(v_actor::text, ''), true);
  PERFORM set_config('app.actor_identity', coalesce(v_identity, ''), true);
  PERFORM set_config('app.roles', array_to_string(v_roles, ','), true);
  PERFORM set_config('app.impersonated_roles', array_to_string(v_impersonated, ','), true);
  PERFORM set_config('app.jwt_claims', coalesce(v_claims, '{}'::jsonb)::text, true);
  IF v_client_app IS NOT NULL THEN
    PERFORM set_config('app.client_app', v_client_app, true);
  END IF;

  RETURN v_txn_id;
END;
$$;


--
-- Name: touch_updated_at(); Type: FUNCTION; Schema: app_security; Owner: -
--

CREATE FUNCTION app_security.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$$;


--
-- Name: notify_watchers_ddl(); Type: FUNCTION; Schema: postgraphile_watch; Owner: -
--

CREATE FUNCTION postgraphile_watch.notify_watchers_ddl() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform pg_notify(
    'postgraphile_watch',
    json_build_object(
      'type',
      'ddl',
      'payload',
      (select json_agg(json_build_object('schema', schema_name, 'command', command_tag)) from pg_event_trigger_ddl_commands() as x)
    )::text
  );
end;
$$;


--
-- Name: notify_watchers_drop(); Type: FUNCTION; Schema: postgraphile_watch; Owner: -
--

CREATE FUNCTION postgraphile_watch.notify_watchers_drop() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform pg_notify(
    'postgraphile_watch',
    json_build_object(
      'type',
      'drop',
      'payload',
      (select json_agg(distinct x.schema_name) from pg_event_trigger_dropped_objects() as x)
    )::text
  );
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: notebook_entries; Type: TABLE; Schema: app_eln; Owner: -
--

CREATE TABLE app_eln.notebook_entries (
    entry_id uuid DEFAULT gen_random_uuid() NOT NULL,
    entry_key text,
    title text NOT NULL,
    description text,
    primary_scope_id uuid NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    submitted_at timestamp with time zone,
    submitted_by uuid,
    locked_at timestamp with time zone,
    locked_by uuid,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid DEFAULT app_security.current_actor_id() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_by uuid DEFAULT app_security.current_actor_id() NOT NULL,
    CONSTRAINT notebook_entries_entry_key_check CHECK (((entry_key IS NULL) OR (entry_key = lower(entry_key)))),
    CONSTRAINT notebook_entries_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT notebook_entries_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text, 'locked'::text]))),
    CONSTRAINT notebook_entries_title_check CHECK ((TRIM(BOTH FROM title) <> ''::text))
);

ALTER TABLE ONLY app_eln.notebook_entries FORCE ROW LEVEL SECURITY;


--
-- Name: notebook_entries; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.notebook_entries AS
 SELECT entry_id,
    entry_key,
    title,
    description,
    primary_scope_id,
    status,
    metadata,
    submitted_at,
    submitted_by,
    locked_at,
    locked_by,
    created_at,
    created_by,
    updated_at,
    updated_by
   FROM app_eln.notebook_entries;


--
-- Name: VIEW notebook_entries; Type: COMMENT; Schema: app_core; Owner: -
--

COMMENT ON VIEW app_core.notebook_entries IS '@omit';


--
-- Name: notebook_entry_versions; Type: TABLE; Schema: app_eln; Owner: -
--

CREATE TABLE app_eln.notebook_entry_versions (
    version_id uuid DEFAULT gen_random_uuid() NOT NULL,
    entry_id uuid NOT NULL,
    version_number integer NOT NULL,
    notebook_json jsonb NOT NULL,
    checksum text NOT NULL,
    note text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid DEFAULT app_security.current_actor_id() NOT NULL,
    CONSTRAINT notebook_entry_versions_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT notebook_entry_versions_notebook_json_check CHECK ((jsonb_typeof(notebook_json) = ANY (ARRAY['object'::text, 'array'::text]))),
    CONSTRAINT notebook_entry_versions_version_number_check CHECK ((version_number > 0))
);

ALTER TABLE ONLY app_eln.notebook_entry_versions FORCE ROW LEVEL SECURITY;


--
-- Name: notebook_entry_versions; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.notebook_entry_versions AS
 SELECT version_id,
    entry_id,
    version_number,
    notebook_json,
    checksum,
    note,
    metadata,
    created_at,
    created_by
   FROM app_eln.notebook_entry_versions;


--
-- Name: VIEW notebook_entry_versions; Type: COMMENT; Schema: app_core; Owner: -
--

COMMENT ON VIEW app_core.notebook_entry_versions IS '@omit';


--
-- Name: roles; Type: TABLE; Schema: app_core; Owner: -
--

CREATE TABLE app_core.roles (
    role_name text NOT NULL,
    display_name text NOT NULL,
    description text,
    is_system_role boolean DEFAULT false NOT NULL,
    is_assignable boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    CONSTRAINT roles_role_name_check CHECK ((role_name = lower(role_name)))
);

ALTER TABLE ONLY app_core.roles FORCE ROW LEVEL SECURITY;


--
-- Name: user_roles; Type: TABLE; Schema: app_core; Owner: -
--

CREATE TABLE app_core.user_roles (
    user_id uuid NOT NULL,
    role_name text NOT NULL,
    granted_by uuid,
    granted_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);

ALTER TABLE ONLY app_core.user_roles FORCE ROW LEVEL SECURITY;


--
-- Name: users; Type: TABLE; Schema: app_core; Owner: -
--

CREATE TABLE app_core.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    external_id text,
    email public.citext NOT NULL,
    full_name text NOT NULL,
    default_role text,
    is_service_account boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    last_authenticated_at timestamp with time zone,
    created_by uuid,
    updated_by uuid,
    CONSTRAINT users_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text))
);

ALTER TABLE ONLY app_core.users FORCE ROW LEVEL SECURITY;


--
-- Name: audit_log; Type: TABLE; Schema: app_security; Owner: -
--

CREATE TABLE app_security.audit_log (
    audit_id bigint NOT NULL,
    txn_id uuid NOT NULL,
    schema_name text NOT NULL,
    table_name text NOT NULL,
    operation text NOT NULL,
    primary_key_data jsonb,
    row_before jsonb,
    row_after jsonb,
    actor_id uuid,
    actor_identity text,
    actor_roles text[] DEFAULT ARRAY[]::text[] NOT NULL,
    performed_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT audit_log_operation_check CHECK ((operation = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);

ALTER TABLE ONLY app_security.audit_log FORCE ROW LEVEL SECURITY;


--
-- Name: v_audit_recent_activity; Type: VIEW; Schema: app_security; Owner: -
--

CREATE VIEW app_security.v_audit_recent_activity AS
 SELECT audit_id,
    performed_at,
    schema_name,
    table_name,
    operation,
    txn_id,
    actor_id,
    actor_identity,
    actor_roles
   FROM app_security.audit_log
  WHERE app_security.has_role('app_admin'::text)
  ORDER BY performed_at DESC
 LIMIT 200;


--
-- Name: v_audit_recent_activity; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_audit_recent_activity AS
 SELECT audit_id,
    performed_at,
    schema_name,
    table_name,
    operation,
    txn_id,
    actor_id,
    actor_identity,
    actor_roles
   FROM app_security.v_audit_recent_activity;


--
-- Name: artefact_relationships; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.artefact_relationships (
    relationship_id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_artefact_id uuid NOT NULL,
    child_artefact_id uuid NOT NULL,
    relationship_type text NOT NULL,
    process_instance_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    CONSTRAINT artefact_relationships_check CHECK ((parent_artefact_id <> child_artefact_id)),
    CONSTRAINT artefact_relationships_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT artefact_relationships_relationship_type_check CHECK ((relationship_type = lower(relationship_type)))
);

ALTER TABLE ONLY app_provenance.artefact_relationships FORCE ROW LEVEL SECURITY;


--
-- Name: artefact_scopes; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.artefact_scopes (
    artefact_id uuid NOT NULL,
    scope_id uuid NOT NULL,
    relationship text DEFAULT 'primary'::text NOT NULL,
    assigned_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    assigned_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT artefact_scopes_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT artefact_scopes_relationship_check CHECK ((relationship = ANY (ARRAY['primary'::text, 'supplementary'::text, 'facility'::text, 'dataset'::text, 'derived_from'::text])))
);

ALTER TABLE ONLY app_provenance.artefact_scopes FORCE ROW LEVEL SECURITY;


--
-- Name: artefact_trait_values; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.artefact_trait_values (
    artefact_trait_value_id uuid DEFAULT gen_random_uuid() NOT NULL,
    artefact_id uuid NOT NULL,
    trait_id uuid NOT NULL,
    value jsonb NOT NULL,
    effective_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    recorded_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT artefact_trait_values_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text))
);

ALTER TABLE ONLY app_provenance.artefact_trait_values FORCE ROW LEVEL SECURITY;


--
-- Name: artefact_traits; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.artefact_traits (
    trait_id uuid DEFAULT gen_random_uuid() NOT NULL,
    trait_key text NOT NULL,
    display_name text NOT NULL,
    description text,
    data_type text NOT NULL,
    allowed_values jsonb,
    default_value jsonb,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_by uuid,
    CONSTRAINT artefact_traits_allowed_values_check CHECK (((allowed_values IS NULL) OR (jsonb_typeof(allowed_values) = ANY (ARRAY['array'::text, 'object'::text])))),
    CONSTRAINT artefact_traits_data_type_check CHECK ((data_type = ANY (ARRAY['boolean'::text, 'text'::text, 'integer'::text, 'numeric'::text, 'json'::text, 'enum'::text]))),
    CONSTRAINT artefact_traits_default_value_check CHECK (((default_value IS NULL) OR (jsonb_typeof(default_value) = ANY (ARRAY['object'::text, 'array'::text, 'string'::text, 'number'::text, 'boolean'::text, 'null'::text])))),
    CONSTRAINT artefact_traits_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT artefact_traits_trait_key_check CHECK ((trait_key = lower(trait_key)))
);

ALTER TABLE ONLY app_provenance.artefact_traits FORCE ROW LEVEL SECURITY;


--
-- Name: artefacts; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.artefacts (
    artefact_id uuid DEFAULT gen_random_uuid() NOT NULL,
    artefact_type_id uuid NOT NULL,
    name text NOT NULL,
    external_identifier text,
    description text,
    status text DEFAULT 'active'::text NOT NULL,
    is_virtual boolean DEFAULT false NOT NULL,
    quantity numeric,
    quantity_unit text,
    quantity_estimated boolean DEFAULT false NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    origin_process_instance_id uuid,
    container_artefact_id uuid,
    container_slot_id uuid,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_by uuid,
    CONSTRAINT artefacts_check CHECK (((container_slot_id IS NULL) OR (container_artefact_id IS NOT NULL))),
    CONSTRAINT artefacts_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT artefacts_name_check CHECK ((name <> ''::text)),
    CONSTRAINT artefacts_quantity_check CHECK (((quantity IS NULL) OR (quantity >= (0)::numeric))),
    CONSTRAINT artefacts_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'reserved'::text, 'consumed'::text, 'completed'::text, 'archived'::text, 'retired'::text])))
);

ALTER TABLE ONLY app_provenance.artefacts FORCE ROW LEVEL SECURITY;


--
-- Name: scopes; Type: TABLE; Schema: app_security; Owner: -
--

CREATE TABLE app_security.scopes (
    scope_id uuid DEFAULT gen_random_uuid() NOT NULL,
    scope_key text NOT NULL,
    scope_type text NOT NULL,
    display_name text NOT NULL,
    description text,
    parent_scope_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_by uuid,
    CONSTRAINT scopes_check CHECK (((parent_scope_id IS NULL) OR (parent_scope_id <> scope_id))),
    CONSTRAINT scopes_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT scopes_scope_key_check CHECK ((scope_key = lower(scope_key))),
    CONSTRAINT scopes_scope_type_check CHECK ((scope_type = lower(scope_type)))
);

ALTER TABLE ONLY app_security.scopes FORCE ROW LEVEL SECURITY;


--
-- Name: v_scope_transfer_overview; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_scope_transfer_overview AS
 WITH latest_state AS (
         SELECT DISTINCT ON (tv.artefact_id) tv.artefact_id,
            TRIM(BOTH '"'::text FROM (tv.value)::text) AS transfer_state,
            tv.effective_at
           FROM (app_provenance.artefact_trait_values tv
             JOIN app_provenance.artefact_traits t ON ((t.trait_id = tv.trait_id)))
          WHERE (t.trait_key = 'transfer_state'::text)
          ORDER BY tv.artefact_id, tv.effective_at DESC
        ), scope_pairs AS (
         SELECT ascope.artefact_id,
            jsonb_build_object('scope_id', sc.scope_id, 'scope_key', sc.scope_key, 'scope_type', sc.scope_type, 'relationship', ascope.relationship) AS scope_obj
           FROM (app_provenance.artefact_scopes ascope
             JOIN app_security.scopes sc ON ((sc.scope_id = ascope.scope_id)))
        ), artefact_scopes AS (
         SELECT scope_pairs.artefact_id,
            jsonb_agg(scope_pairs.scope_obj ORDER BY (scope_pairs.scope_obj ->> 'scope_key'::text)) AS scopes
           FROM scope_pairs
          GROUP BY scope_pairs.artefact_id
        ), relationship_roles AS (
         SELECT rel_1.relationship_id,
            rel_1.parent_artefact_id,
            rel_1.child_artefact_id,
            rel_1.relationship_type,
            ARRAY( SELECT DISTINCT lower(role.role_value) AS lower
                   FROM jsonb_array_elements_text(COALESCE((rel_1.metadata -> 'allowed_roles'::text), '[]'::jsonb)) role(role_value)) AS allowed_roles
           FROM app_provenance.artefact_relationships rel_1
          WHERE (rel_1.metadata ? 'handover_at'::text)
        )
 SELECT rel.parent_artefact_id AS source_artefact_id,
    parent.name AS source_artefact_name,
    src.scopes AS source_scopes,
    rel.child_artefact_id AS target_artefact_id,
    child.name AS target_artefact_name,
    tgt.scopes AS target_scopes,
    ls_parent.transfer_state AS source_transfer_state,
    ls_child.transfer_state AS target_transfer_state,
    ( SELECT array_agg(elem.value ORDER BY elem.value) AS array_agg
           FROM jsonb_array_elements_text(COALESCE((rel.metadata -> 'propagation_whitelist'::text), '[]'::jsonb)) elem(value)) AS propagation_whitelist,
    COALESCE(rr.allowed_roles, ARRAY['app_operator'::text, 'app_admin'::text, 'app_automation'::text]) AS allowed_roles,
    rel.relationship_type,
    ((rel.metadata ->> 'handover_at'::text))::timestamp with time zone AS handover_at,
    ((rel.metadata ->> 'returned_at'::text))::timestamp with time zone AS returned_at,
    ((rel.metadata ->> 'handover_by'::text))::uuid AS handover_by,
    ((rel.metadata ->> 'returned_by'::text))::uuid AS returned_by,
    rel.metadata AS relationship_metadata
   FROM (((((((app_provenance.artefact_relationships rel
     JOIN app_provenance.artefacts parent ON ((parent.artefact_id = rel.parent_artefact_id)))
     JOIN app_provenance.artefacts child ON ((child.artefact_id = rel.child_artefact_id)))
     LEFT JOIN latest_state ls_parent ON ((ls_parent.artefact_id = parent.artefact_id)))
     LEFT JOIN latest_state ls_child ON ((ls_child.artefact_id = child.artefact_id)))
     LEFT JOIN artefact_scopes src ON ((src.artefact_id = rel.parent_artefact_id)))
     LEFT JOIN artefact_scopes tgt ON ((tgt.artefact_id = rel.child_artefact_id)))
     LEFT JOIN relationship_roles rr ON ((rr.relationship_id = rel.relationship_id)))
  WHERE (rel.metadata ? 'handover_at'::text);


--
-- Name: VIEW v_scope_transfer_overview; Type: COMMENT; Schema: app_core; Owner: -
--

COMMENT ON VIEW app_core.v_scope_transfer_overview IS 'Generalised scope-to-scope transfer overview including scope metadata and allowed roles.';


--
-- Name: v_handover_overview; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_handover_overview AS
 SELECT source_artefact_id AS research_artefact_id,
    source_artefact_name AS research_artefact_name,
    ( SELECT COALESCE(array_agg((elem.value ->> 'scope_key'::text) ORDER BY (elem.value ->> 'scope_key'::text)), ARRAY[]::text[]) AS "coalesce"
           FROM jsonb_array_elements(COALESCE(info.source_scopes, '[]'::jsonb)) elem(value)
          WHERE ((elem.value ->> 'scope_type'::text) = ANY (ARRAY['project'::text, 'dataset'::text, 'subproject'::text]))) AS research_scope_keys,
    target_artefact_id AS ops_artefact_id,
    target_artefact_name AS ops_artefact_name,
    ( SELECT COALESCE(array_agg((elem.value ->> 'scope_key'::text) ORDER BY (elem.value ->> 'scope_key'::text)), ARRAY[]::text[]) AS "coalesce"
           FROM jsonb_array_elements(COALESCE(info.target_scopes, '[]'::jsonb)) elem(value)
          WHERE ((elem.value ->> 'scope_type'::text) = 'ops'::text)) AS ops_scope_keys,
    source_transfer_state AS research_transfer_state,
    target_transfer_state AS ops_transfer_state,
    propagation_whitelist,
    handover_at,
    returned_at,
    handover_by,
    returned_by
   FROM app_core.v_scope_transfer_overview info
  WHERE ((relationship_type = 'handover_duplicate'::text) AND (EXISTS ( SELECT 1
           FROM jsonb_array_elements(COALESCE(info.target_scopes, '[]'::jsonb)) elem(value)
          WHERE ((elem.value ->> 'scope_type'::text) = 'ops'::text))));


--
-- Name: VIEW v_handover_overview; Type: COMMENT; Schema: app_core; Owner: -
--

COMMENT ON VIEW app_core.v_handover_overview IS 'Summarises handover duplicates, scope memberships, transfer state, and propagation metadata for UI consumption.';


--
-- Name: artefact_types; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.artefact_types (
    artefact_type_id uuid DEFAULT gen_random_uuid() NOT NULL,
    type_key text NOT NULL,
    display_name text NOT NULL,
    kind text NOT NULL,
    description text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_by uuid,
    CONSTRAINT artefact_types_kind_check CHECK ((kind = ANY (ARRAY['subject'::text, 'material'::text, 'reagent'::text, 'container'::text, 'data_product'::text, 'instrument_run'::text, 'workflow'::text, 'instrument'::text, 'virtual'::text, 'storage'::text, 'other'::text]))),
    CONSTRAINT artefact_types_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT artefact_types_type_key_check CHECK ((type_key = lower(type_key)))
);

ALTER TABLE ONLY app_provenance.artefact_types FORCE ROW LEVEL SECURITY;


--
-- Name: v_artefact_current_location; Type: VIEW; Schema: app_provenance; Owner: -
--

CREATE VIEW app_provenance.v_artefact_current_location AS
 SELECT rel.child_artefact_id AS artefact_id,
    rel.parent_artefact_id AS storage_node_id,
    parent.name AS storage_display_name,
    COALESCE((parent.metadata ->> 'storage_level'::text), 'sublocation'::text) AS node_type,
    ( SELECT s.scope_id
           FROM app_provenance.artefact_scopes s
          WHERE (s.artefact_id = parent.artefact_id)
          ORDER BY
                CASE s.relationship
                    WHEN 'primary'::text THEN 0
                    ELSE 1
                END, s.assigned_at DESC
         LIMIT 1) AS scope_id,
    COALESCE((parent.metadata -> 'environment'::text), '{}'::jsonb) AS environment,
    (rel.metadata ->> 'last_event_type'::text) AS last_event_type,
    ((rel.metadata ->> 'last_event_at'::text))::timestamp with time zone AS last_event_at
   FROM (app_provenance.artefact_relationships rel
     JOIN app_provenance.artefacts parent ON ((parent.artefact_id = rel.parent_artefact_id)))
  WHERE (rel.relationship_type = 'located_in'::text);


--
-- Name: v_inventory_status; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_inventory_status AS
 SELECT reagent.artefact_id AS id,
    reagent.name,
    COALESCE((reagent.metadata ->> 'barcode'::text), reagent.external_identifier) AS barcode,
    COALESCE(reagent.quantity, (0)::numeric) AS quantity,
    reagent.quantity_unit AS unit,
        CASE
            WHEN ((reagent.metadata ? 'minimum_quantity'::text) AND ((reagent.metadata ->> 'minimum_quantity'::text) ~ '^-?[0-9]+(\\.[0-9]+)?$'::text)) THEN ((reagent.metadata ->> 'minimum_quantity'::text))::numeric
            ELSE NULL::numeric
        END AS minimum_quantity,
        CASE
            WHEN (reagent.quantity IS NULL) THEN false
            WHEN ((reagent.metadata ? 'minimum_quantity'::text) AND ((reagent.metadata ->> 'minimum_quantity'::text) ~ '^-?[0-9]+(\\.[0-9]+)?$'::text)) THEN (reagent.quantity < ((reagent.metadata ->> 'minimum_quantity'::text))::numeric)
            ELSE false
        END AS below_threshold,
        CASE
            WHEN (reagent.metadata ? 'expires_at'::text) THEN ((reagent.metadata ->> 'expires_at'::text))::timestamp with time zone
            ELSE NULL::timestamp with time zone
        END AS expires_at,
    loc.storage_node_id AS storage_sublocation_id,
    app_provenance.storage_path(loc.storage_node_id) AS storage_path
   FROM ((app_provenance.artefacts reagent
     JOIN app_provenance.artefact_types reagent_type ON ((reagent_type.artefact_type_id = reagent.artefact_type_id)))
     LEFT JOIN app_provenance.v_artefact_current_location loc ON ((loc.artefact_id = reagent.artefact_id)))
  WHERE ((reagent_type.kind = 'reagent'::text) AND app_provenance.can_access_artefact(reagent.artefact_id));


--
-- Name: container_slots; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.container_slots (
    container_slot_id uuid DEFAULT gen_random_uuid() NOT NULL,
    container_artefact_id uuid NOT NULL,
    slot_definition_id uuid,
    slot_name text NOT NULL,
    display_name text,
    "position" jsonb,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT container_slots_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text))
);

ALTER TABLE ONLY app_provenance.container_slots FORCE ROW LEVEL SECURITY;


--
-- Name: v_labware_contents; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_labware_contents AS
 SELECT lab.artefact_id AS labware_id,
    COALESCE((lab.metadata ->> 'barcode'::text), lab.external_identifier) AS barcode,
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
   FROM ((((app_provenance.artefacts lab
     JOIN app_provenance.artefact_types lab_type ON ((lab_type.artefact_type_id = lab.artefact_type_id)))
     LEFT JOIN app_provenance.artefacts sample ON ((sample.container_artefact_id = lab.artefact_id)))
     LEFT JOIN app_provenance.container_slots slot ON (((slot.container_slot_id = sample.container_slot_id) AND (slot.container_artefact_id = lab.artefact_id))))
     LEFT JOIN app_provenance.v_artefact_current_location loc ON ((loc.artefact_id = lab.artefact_id)))
  WHERE ((lab_type.kind = 'container'::text) AND app_provenance.can_access_artefact(lab.artefact_id));


--
-- Name: v_labware_inventory; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_labware_inventory AS
 WITH labware_samples AS (
         SELECT a.container_artefact_id AS labware_id,
            a.artefact_id AS sample_id
           FROM app_provenance.artefacts a
          WHERE (a.container_artefact_id IS NOT NULL)
        )
 SELECT lab.artefact_id AS labware_id,
    COALESCE((lab.metadata ->> 'barcode'::text), lab.external_identifier) AS barcode,
    lab.name AS display_name,
    lab.status,
    lab_type.type_key AS labware_type,
    loc.storage_node_id AS current_storage_sublocation_id,
    app_provenance.storage_path(loc.storage_node_id) AS storage_path,
    count(DISTINCT ls.sample_id) AS active_sample_count,
        CASE
            WHEN (count(ls.sample_id) = 0) THEN NULL::jsonb
            ELSE jsonb_agg(DISTINCT jsonb_build_object('sample_id', sample.artefact_id, 'sample_name', sample.name, 'sample_status', sample.status))
        END AS active_samples
   FROM ((((app_provenance.artefacts lab
     JOIN app_provenance.artefact_types lab_type ON ((lab_type.artefact_type_id = lab.artefact_type_id)))
     LEFT JOIN labware_samples ls ON ((ls.labware_id = lab.artefact_id)))
     LEFT JOIN app_provenance.artefacts sample ON ((sample.artefact_id = ls.sample_id)))
     LEFT JOIN app_provenance.v_artefact_current_location loc ON ((loc.artefact_id = lab.artefact_id)))
  WHERE ((lab_type.kind = 'container'::text) AND app_provenance.can_access_artefact(lab.artefact_id))
  GROUP BY lab.artefact_id, lab.metadata, lab.external_identifier, lab.name, lab.status, lab_type.type_key, loc.storage_node_id;


--
-- Name: v_notebook_entry_overview; Type: VIEW; Schema: app_eln; Owner: -
--

CREATE VIEW app_eln.v_notebook_entry_overview AS
 SELECT e.entry_id,
    e.entry_key,
    e.title,
    e.description,
    e.status,
    e.primary_scope_id,
    s.scope_key AS primary_scope_key,
    s.display_name AS primary_scope_name,
    e.metadata,
    e.submitted_at,
    e.submitted_by,
    e.locked_at,
    e.locked_by,
    e.created_at,
    e.created_by,
    e.updated_at,
    e.updated_by,
    latest.version_number AS latest_version,
    latest.created_at AS latest_version_created_at,
    latest.created_by AS latest_version_created_by
   FROM ((app_eln.notebook_entries e
     LEFT JOIN app_security.scopes s ON ((s.scope_id = e.primary_scope_id)))
     LEFT JOIN LATERAL ( SELECT v.version_number,
            v.created_at,
            v.created_by
           FROM app_eln.notebook_entry_versions v
          WHERE (v.entry_id = e.entry_id)
          ORDER BY v.version_number DESC
         LIMIT 1) latest ON (true));


--
-- Name: v_notebook_entry_overview; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_notebook_entry_overview AS
 SELECT entry_id,
    entry_key,
    title,
    description,
    status,
    primary_scope_id,
    primary_scope_key,
    primary_scope_name,
    metadata,
    submitted_at,
    submitted_by,
    locked_at,
    locked_by,
    created_at,
    created_by,
    updated_at,
    updated_by,
    latest_version,
    latest_version_created_at,
    latest_version_created_by
   FROM app_eln.v_notebook_entry_overview;


--
-- Name: VIEW v_notebook_entry_overview; Type: COMMENT; Schema: app_core; Owner: -
--

COMMENT ON VIEW app_core.v_notebook_entry_overview IS '@omit';


--
-- Name: v_project_access_overview; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_project_access_overview AS
 WITH actor_project_roles AS (
         SELECT project.scope_id AS project_id,
            project.scope_key,
            project.display_name,
            project.depth
           FROM (app_security.actor_scope_roles(app_security.current_actor_id()) ar(scope_id, role_name, source_scope_id, source_role_name)
             JOIN LATERAL ( WITH RECURSIVE ascend AS (
                         SELECT s.scope_id,
                            s.parent_scope_id,
                            s.scope_type,
                            s.scope_key,
                            s.display_name,
                            0 AS depth
                           FROM app_security.scopes s
                          WHERE (s.scope_id = ar.scope_id)
                        UNION ALL
                         SELECT parent.scope_id,
                            parent.parent_scope_id,
                            parent.scope_type,
                            parent.scope_key,
                            parent.display_name,
                            (ascend_1.depth + 1)
                           FROM (app_security.scopes parent
                             JOIN ascend ascend_1 ON ((ascend_1.parent_scope_id = parent.scope_id)))
                        )
                 SELECT ascend.scope_id,
                    ascend.scope_key,
                    ascend.display_name,
                    ascend.depth
                   FROM ascend
                  WHERE (ascend.scope_type = 'project'::text)
                  ORDER BY ascend.depth
                 LIMIT 1) project(scope_id, scope_key, display_name, depth) ON (true))
        ), project_aggregates AS (
         SELECT actor_project_roles.project_id,
            min(actor_project_roles.scope_key) AS scope_key,
            min(actor_project_roles.display_name) AS display_name,
            bool_or((actor_project_roles.depth = 0)) AS has_direct_membership
           FROM actor_project_roles
          GROUP BY actor_project_roles.project_id
        ), sample_assignments AS (
         SELECT sample.artefact_id,
            sc_1.scope_id
           FROM ((app_provenance.artefact_scopes sc_1
             JOIN app_provenance.artefacts sample ON ((sample.artefact_id = sc_1.artefact_id)))
             JOIN app_provenance.artefact_types st ON ((st.artefact_type_id = sample.artefact_type_id)))
          WHERE ((st.kind = 'material'::text) AND app_provenance.can_access_artefact(sample.artefact_id))
        ), sample_projects AS (
         SELECT DISTINCT sa.artefact_id,
            project.scope_id AS project_id
           FROM (sample_assignments sa
             JOIN LATERAL ( WITH RECURSIVE ascend AS (
                         SELECT s.scope_id,
                            s.parent_scope_id,
                            s.scope_type,
                            0 AS depth
                           FROM app_security.scopes s
                          WHERE (s.scope_id = sa.scope_id)
                        UNION ALL
                         SELECT parent.scope_id,
                            parent.parent_scope_id,
                            parent.scope_type,
                            (ascend_1.depth + 1)
                           FROM (app_security.scopes parent
                             JOIN ascend ascend_1 ON ((ascend_1.parent_scope_id = parent.scope_id)))
                        )
                 SELECT ascend.scope_id
                   FROM ascend
                  WHERE (ascend.scope_type = 'project'::text)
                  ORDER BY ascend.depth
                 LIMIT 1) project(scope_id) ON (true))
        ), sample_counts AS (
         SELECT sample_projects.project_id,
            count(DISTINCT sample_projects.artefact_id) AS sample_count
           FROM sample_projects
          GROUP BY sample_projects.project_id
        ), labware_assignments AS (
         SELECT DISTINCT lab.artefact_id AS labware_id,
            sc_1.scope_id
           FROM ((((app_provenance.artefacts sample
             JOIN app_provenance.artefact_types st ON ((st.artefact_type_id = sample.artefact_type_id)))
             JOIN app_provenance.artefacts lab ON ((lab.artefact_id = sample.container_artefact_id)))
             JOIN app_provenance.artefact_types lt ON ((lt.artefact_type_id = lab.artefact_type_id)))
             JOIN app_provenance.artefact_scopes sc_1 ON ((sc_1.artefact_id = sample.artefact_id)))
          WHERE ((lt.kind = 'container'::text) AND (sample.container_artefact_id IS NOT NULL) AND app_provenance.can_access_artefact(lab.artefact_id))
        ), labware_projects AS (
         SELECT DISTINCT la.labware_id,
            project.scope_id AS project_id
           FROM (labware_assignments la
             JOIN LATERAL ( WITH RECURSIVE ascend AS (
                         SELECT s.scope_id,
                            s.parent_scope_id,
                            s.scope_type,
                            0 AS depth
                           FROM app_security.scopes s
                          WHERE (s.scope_id = la.scope_id)
                        UNION ALL
                         SELECT parent.scope_id,
                            parent.parent_scope_id,
                            parent.scope_type,
                            (ascend_1.depth + 1)
                           FROM (app_security.scopes parent
                             JOIN ascend ascend_1 ON ((ascend_1.parent_scope_id = parent.scope_id)))
                        )
                 SELECT ascend.scope_id
                   FROM ascend
                  WHERE (ascend.scope_type = 'project'::text)
                  ORDER BY ascend.depth
                 LIMIT 1) project(scope_id) ON (true))
        ), labware_counts AS (
         SELECT labware_projects.project_id,
            count(DISTINCT labware_projects.labware_id) AS labware_count
           FROM labware_projects
          GROUP BY labware_projects.project_id
        ), accessible_projects AS (
         SELECT project_aggregates.project_id
           FROM project_aggregates
        UNION
         SELECT sample_counts.project_id
           FROM sample_counts
        UNION
         SELECT labware_counts.project_id
           FROM labware_counts
        )
 SELECT ap.project_id AS id,
    split_part(sc.scope_key, ':'::text, 2) AS project_code,
    sc.display_name AS name,
    COALESCE(NULLIF(sc.description, ''::text), 'Project scope'::text) AS description,
    COALESCE((agg.project_id IS NOT NULL), app_security.has_role('app_admin'::text)) AS is_member,
        CASE
            WHEN agg.has_direct_membership THEN 'direct'::text
            WHEN (agg.project_id IS NOT NULL) THEN 'inherited'::text
            ELSE 'implicit'::text
        END AS access_via,
    COALESCE(samples.sample_count, (0)::bigint) AS sample_count,
    COALESCE(labware.labware_count, (0)::bigint) AS active_labware_count
   FROM ((((accessible_projects ap
     JOIN app_security.scopes sc ON ((sc.scope_id = ap.project_id)))
     LEFT JOIN project_aggregates agg ON ((agg.project_id = ap.project_id)))
     LEFT JOIN sample_counts samples ON ((samples.project_id = ap.project_id)))
     LEFT JOIN labware_counts labware ON ((labware.project_id = ap.project_id)));


--
-- Name: process_instances; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.process_instances (
    process_instance_id uuid DEFAULT gen_random_uuid() NOT NULL,
    process_type_id uuid NOT NULL,
    process_identifier text,
    name text NOT NULL,
    description text,
    status text DEFAULT 'in_progress'::text NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    executed_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_by uuid,
    CONSTRAINT process_instances_check CHECK (((completed_at IS NULL) OR (started_at IS NULL) OR (completed_at >= started_at))),
    CONSTRAINT process_instances_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT process_instances_name_check CHECK ((name <> ''::text)),
    CONSTRAINT process_instances_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'scheduled'::text, 'in_progress'::text, 'completed'::text, 'failed'::text, 'cancelled'::text])))
);

ALTER TABLE ONLY app_provenance.process_instances FORCE ROW LEVEL SECURITY;


--
-- Name: v_sample_lineage; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_sample_lineage AS
 SELECT parent.artefact_id AS parent_sample_id,
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
    (pi.executed_by)::text AS created_by
   FROM (((((((((app_provenance.artefact_relationships rel
     JOIN app_provenance.artefacts parent ON ((parent.artefact_id = rel.parent_artefact_id)))
     JOIN app_provenance.artefact_types parent_type ON ((parent_type.artefact_type_id = parent.artefact_type_id)))
     JOIN app_provenance.artefacts child ON ((child.artefact_id = rel.child_artefact_id)))
     JOIN app_provenance.artefact_types child_type ON ((child_type.artefact_type_id = child.artefact_type_id)))
     LEFT JOIN app_provenance.process_instances pi ON ((pi.process_instance_id = rel.process_instance_id)))
     LEFT JOIN LATERAL ( SELECT s.scope_id
           FROM (app_provenance.artefact_scopes sc
             JOIN app_security.scopes s ON ((s.scope_id = sc.scope_id)))
          WHERE ((sc.artefact_id = parent.artefact_id) AND (s.scope_type = 'project'::text))
          ORDER BY
                CASE sc.relationship
                    WHEN 'primary'::text THEN 0
                    ELSE 1
                END, sc.assigned_at DESC
         LIMIT 1) parent_project ON (true))
     LEFT JOIN LATERAL ( SELECT s.scope_id
           FROM (app_provenance.artefact_scopes sc
             JOIN app_security.scopes s ON ((s.scope_id = sc.scope_id)))
          WHERE ((sc.artefact_id = child.artefact_id) AND (s.scope_type = 'project'::text))
          ORDER BY
                CASE sc.relationship
                    WHEN 'primary'::text THEN 0
                    ELSE 1
                END, sc.assigned_at DESC
         LIMIT 1) child_project ON (true))
     LEFT JOIN LATERAL ( SELECT lab.artefact_id AS labware_id,
            COALESCE((lab.metadata ->> 'barcode'::text), lab.external_identifier) AS labware_barcode,
            lab.name AS labware_name,
            app_provenance.storage_path(loc.storage_node_id) AS storage_path
           FROM (app_provenance.artefacts lab
             LEFT JOIN app_provenance.v_artefact_current_location loc ON ((loc.artefact_id = lab.artefact_id)))
          WHERE (lab.artefact_id = parent.container_artefact_id)
         LIMIT 1) lab_parent ON (true))
     LEFT JOIN LATERAL ( SELECT lab.artefact_id AS labware_id,
            COALESCE((lab.metadata ->> 'barcode'::text), lab.external_identifier) AS labware_barcode,
            lab.name AS labware_name,
            app_provenance.storage_path(loc.storage_node_id) AS storage_path
           FROM (app_provenance.artefacts lab
             LEFT JOIN app_provenance.v_artefact_current_location loc ON ((loc.artefact_id = lab.artefact_id)))
          WHERE (lab.artefact_id = child.container_artefact_id)
         LIMIT 1) lab_child ON (true))
  WHERE ((parent_type.kind = 'material'::text) AND (child_type.kind = 'material'::text) AND app_provenance.can_access_artefact(parent.artefact_id) AND app_provenance.can_access_artefact(child.artefact_id));


--
-- Name: v_sample_overview; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_sample_overview AS
 SELECT sample.artefact_id AS id,
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
   FROM ((((((app_provenance.artefacts sample
     JOIN app_provenance.artefact_types sample_type ON ((sample_type.artefact_type_id = sample.artefact_type_id)))
     LEFT JOIN app_provenance.process_instances pi ON ((pi.process_instance_id = sample.origin_process_instance_id)))
     LEFT JOIN app_provenance.v_artefact_current_location sample_loc ON ((sample_loc.artefact_id = sample.artefact_id)))
     LEFT JOIN LATERAL ( WITH RECURSIVE ascend AS (
                 SELECT s.scope_id,
                    s.scope_key,
                    s.display_name,
                    s.scope_type,
                    s.parent_scope_id,
                    0 AS depth
                   FROM (app_provenance.artefact_scopes sc
                     JOIN app_security.scopes s ON ((s.scope_id = sc.scope_id)))
                  WHERE (sc.artefact_id = sample.artefact_id)
                UNION ALL
                 SELECT parent.scope_id,
                    parent.scope_key,
                    parent.display_name,
                    parent.scope_type,
                    parent.parent_scope_id,
                    (ascend_1.depth + 1)
                   FROM (app_security.scopes parent
                     JOIN ascend ascend_1 ON ((ascend_1.parent_scope_id = parent.scope_id)))
                )
         SELECT ascend.scope_id,
            ascend.scope_key,
            ascend.display_name
           FROM ascend
          WHERE (ascend.scope_type = 'project'::text)
          ORDER BY ascend.depth
         LIMIT 1) project_scope ON (true))
     LEFT JOIN LATERAL ( SELECT lab.artefact_id AS labware_id,
            lab.name AS labware_name,
            COALESCE((lab.metadata ->> 'barcode'::text), lab.external_identifier) AS labware_barcode,
            app_provenance.storage_path(loc.storage_node_id) AS storage_path
           FROM (app_provenance.artefacts lab
             LEFT JOIN app_provenance.v_artefact_current_location loc ON ((loc.artefact_id = lab.artefact_id)))
          WHERE (lab.artefact_id = sample.container_artefact_id)
         LIMIT 1) lab_assoc ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('artefact_id', child.artefact_id, 'name', child.name, 'relationship_type', rel.relationship_type) ORDER BY child.name) AS derivatives
           FROM ((app_provenance.artefact_relationships rel
             JOIN app_provenance.artefacts child ON ((child.artefact_id = rel.child_artefact_id)))
             JOIN app_provenance.artefact_types child_type ON ((child_type.artefact_type_id = child.artefact_type_id)))
          WHERE ((rel.parent_artefact_id = sample.artefact_id) AND (child_type.kind = 'material'::text) AND app_provenance.can_access_artefact(child.artefact_id))) derivatives ON (true))
  WHERE ((sample_type.kind = 'material'::text) AND app_provenance.can_access_artefact(sample.artefact_id));


--
-- Name: v_storage_tree; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_storage_tree AS
 WITH storage_nodes AS (
         SELECT a.artefact_id AS node_id,
            a.name AS display_name,
            at.type_key,
            COALESCE((a.metadata ->> 'storage_level'::text), 'sublocation'::text) AS node_type
           FROM (app_provenance.artefacts a
             JOIN app_provenance.artefact_types at ON ((at.artefact_type_id = a.artefact_type_id)))
          WHERE (at.type_key = ANY (ARRAY['storage_facility'::text, 'storage_unit'::text, 'storage_sublocation'::text, 'storage_virtual'::text, 'storage_external'::text]))
        )
 SELECT facility.node_id AS facility_id,
    facility.display_name AS facility_name,
    unit.node_id AS unit_id,
    unit.display_name AS unit_name,
    node.node_type AS storage_type,
        CASE
            WHEN (node.node_type = 'sublocation'::text) THEN node.node_id
            ELSE NULL::uuid
        END AS sublocation_id,
        CASE
            WHEN (node.node_type = 'sublocation'::text) THEN node.display_name
            ELSE NULL::text
        END AS sublocation_name,
        CASE
            WHEN (node.node_type = 'sublocation'::text) THEN ( SELECT r.parent_artefact_id
               FROM app_provenance.artefact_relationships r
              WHERE ((r.child_artefact_id = node.node_id) AND (r.relationship_type = 'located_in'::text))
             LIMIT 1)
            ELSE NULL::uuid
        END AS parent_sublocation_id,
    NULL::integer AS capacity,
    app_provenance.storage_path(node.node_id) AS storage_path,
    COALESCE(metrics.labware_count, (0)::bigint) AS labware_count,
    COALESCE(metrics.sample_count, (0)::bigint) AS sample_count
   FROM (((storage_nodes node
     LEFT JOIN LATERAL ( WITH RECURSIVE descend(node_id) AS (
                 SELECT node.node_id
                UNION ALL
                 SELECT r.child_artefact_id
                   FROM ((app_provenance.artefact_relationships r
                     JOIN storage_nodes s ON ((s.node_id = r.child_artefact_id)))
                     JOIN descend d_1 ON ((d_1.node_id = r.parent_artefact_id)))
                  WHERE (r.relationship_type = 'located_in'::text)
                )
         SELECT count(DISTINCT
                CASE
                    WHEN (at.kind = 'container'::text) THEN loc.artefact_id
                    ELSE NULL::uuid
                END) AS labware_count,
            count(DISTINCT
                CASE
                    WHEN (at.kind = 'material'::text) THEN loc.artefact_id
                    ELSE NULL::uuid
                END) AS sample_count
           FROM (((descend d
             JOIN app_provenance.v_artefact_current_location loc ON ((loc.storage_node_id = d.node_id)))
             JOIN app_provenance.artefacts art ON ((art.artefact_id = loc.artefact_id)))
             JOIN app_provenance.artefact_types at ON ((at.artefact_type_id = art.artefact_type_id)))
          WHERE app_provenance.can_access_artefact(art.artefact_id)) metrics ON (true))
     LEFT JOIN LATERAL ( WITH RECURSIVE ascend(node_id, node_type, display_name) AS (
                 SELECT node.node_id,
                    node.node_type,
                    node.display_name
                UNION ALL
                 SELECT s.node_id,
                    s.node_type,
                    s.display_name
                   FROM ((app_provenance.artefact_relationships r
                     JOIN storage_nodes s ON ((s.node_id = r.parent_artefact_id)))
                     JOIN ascend a ON ((a.node_id = r.child_artefact_id)))
                  WHERE (r.relationship_type = 'located_in'::text)
                )
         SELECT ascend.node_id,
            ascend.display_name
           FROM ascend
          WHERE (ascend.node_type = 'facility'::text)
          ORDER BY
                CASE
                    WHEN (ascend.node_id = node.node_id) THEN 0
                    ELSE 1
                END
         LIMIT 1) facility(node_id, display_name) ON (true))
     LEFT JOIN LATERAL ( WITH RECURSIVE ascend(node_id, node_type, display_name) AS (
                 SELECT node.node_id,
                    node.node_type,
                    node.display_name
                UNION ALL
                 SELECT s.node_id,
                    s.node_type,
                    s.display_name
                   FROM ((app_provenance.artefact_relationships r
                     JOIN storage_nodes s ON ((s.node_id = r.parent_artefact_id)))
                     JOIN ascend a ON ((a.node_id = r.child_artefact_id)))
                  WHERE (r.relationship_type = 'located_in'::text)
                )
         SELECT ascend.node_id,
            ascend.display_name
           FROM ascend
          WHERE (ascend.node_type = 'unit'::text)
          ORDER BY
                CASE
                    WHEN (ascend.node_id = node.node_id) THEN 0
                    ELSE 1
                END
         LIMIT 1) unit(node_id, display_name) ON (true))
  WHERE ((metrics.labware_count IS NOT NULL) OR (metrics.sample_count IS NOT NULL) OR app_provenance.can_access_storage_node(node.node_id));


--
-- Name: transaction_contexts; Type: TABLE; Schema: app_security; Owner: -
--

CREATE TABLE app_security.transaction_contexts (
    txn_id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid,
    actor_identity text,
    actor_roles text[] DEFAULT ARRAY[]::text[] NOT NULL,
    impersonated_roles text[] DEFAULT ARRAY[]::text[] NOT NULL,
    jwt_claims jsonb DEFAULT '{}'::jsonb NOT NULL,
    client_app text,
    client_ip inet,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    started_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    finished_at timestamp with time zone,
    finished_status text,
    finished_reason text,
    finished_by uuid,
    CONSTRAINT transaction_contexts_finished_status_check CHECK (((finished_status IS NULL) OR (finished_status = ANY (ARRAY['committed'::text, 'rolled_back'::text, 'cancelled'::text])))),
    CONSTRAINT transaction_contexts_jwt_claims_check CHECK ((jsonb_typeof(jwt_claims) = 'object'::text)),
    CONSTRAINT transaction_contexts_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text))
);


--
-- Name: v_transaction_context_activity; Type: VIEW; Schema: app_security; Owner: -
--

CREATE VIEW app_security.v_transaction_context_activity AS
 SELECT date_trunc('hour'::text, started_at) AS started_hour,
    COALESCE(client_app, 'unknown'::text) AS client_app,
    COALESCE(finished_status, 'pending'::text) AS finished_status,
    count(*) AS context_count,
    count(*) FILTER (WHERE (finished_status IS NULL)) AS open_contexts
   FROM app_security.transaction_contexts
  WHERE app_security.has_role('app_admin'::text)
  GROUP BY (date_trunc('hour'::text, started_at)), COALESCE(client_app, 'unknown'::text), COALESCE(finished_status, 'pending'::text);


--
-- Name: v_transaction_context_activity; Type: VIEW; Schema: app_core; Owner: -
--

CREATE VIEW app_core.v_transaction_context_activity AS
 SELECT started_hour,
    client_app,
    finished_status,
    context_count,
    open_contexts
   FROM app_security.v_transaction_context_activity;


--
-- Name: notebook_entry_scopes; Type: TABLE; Schema: app_eln; Owner: -
--

CREATE TABLE app_eln.notebook_entry_scopes (
    entry_id uuid NOT NULL,
    scope_id uuid NOT NULL,
    relationship text DEFAULT 'primary'::text NOT NULL,
    assigned_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    assigned_by uuid DEFAULT app_security.current_actor_id() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT notebook_entry_scopes_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT notebook_entry_scopes_relationship_check CHECK ((relationship = ANY (ARRAY['primary'::text, 'supplementary'::text, 'witness'::text, 'reference'::text])))
);

ALTER TABLE ONLY app_eln.notebook_entry_scopes FORCE ROW LEVEL SECURITY;


--
-- Name: container_slot_definitions; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.container_slot_definitions (
    slot_definition_id uuid DEFAULT gen_random_uuid() NOT NULL,
    artefact_type_id uuid NOT NULL,
    slot_name text NOT NULL,
    display_name text,
    "position" jsonb,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT container_slot_definitions_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text))
);

ALTER TABLE ONLY app_provenance.container_slot_definitions FORCE ROW LEVEL SECURITY;


--
-- Name: process_io; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.process_io (
    process_io_id uuid DEFAULT gen_random_uuid() NOT NULL,
    process_instance_id uuid NOT NULL,
    artefact_id uuid NOT NULL,
    direction text NOT NULL,
    io_role text,
    quantity numeric,
    quantity_unit text,
    is_primary boolean DEFAULT false NOT NULL,
    multiplex_group text,
    evidence jsonb,
    confidence numeric,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT process_io_confidence_check CHECK (((confidence IS NULL) OR ((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)))),
    CONSTRAINT process_io_direction_check CHECK ((direction = ANY (ARRAY['input'::text, 'output'::text, 'pooled_input'::text, 'pooled_output'::text, 'reference'::text]))),
    CONSTRAINT process_io_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT process_io_quantity_check CHECK (((quantity IS NULL) OR (quantity >= (0)::numeric)))
);

ALTER TABLE ONLY app_provenance.process_io FORCE ROW LEVEL SECURITY;


--
-- Name: process_scopes; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.process_scopes (
    process_instance_id uuid NOT NULL,
    scope_id uuid NOT NULL,
    relationship text DEFAULT 'primary'::text NOT NULL,
    assigned_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    assigned_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT process_scopes_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT process_scopes_relationship_check CHECK ((relationship = ANY (ARRAY['primary'::text, 'facility'::text, 'dataset'::text, 'workflow'::text, 'instrument'::text])))
);

ALTER TABLE ONLY app_provenance.process_scopes FORCE ROW LEVEL SECURITY;


--
-- Name: process_types; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.process_types (
    process_type_id uuid DEFAULT gen_random_uuid() NOT NULL,
    type_key text NOT NULL,
    display_name text NOT NULL,
    description text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_by uuid,
    CONSTRAINT process_types_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT process_types_type_key_check CHECK ((type_key = lower(type_key)))
);

ALTER TABLE ONLY app_provenance.process_types FORCE ROW LEVEL SECURITY;


--
-- Name: v_accessible_artefacts; Type: VIEW; Schema: app_provenance; Owner: -
--

CREATE VIEW app_provenance.v_accessible_artefacts AS
 SELECT a.artefact_id,
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
   FROM ((((app_provenance.artefacts a
     JOIN app_provenance.artefact_types at ON ((at.artefact_type_id = a.artefact_type_id)))
     LEFT JOIN LATERAL ( SELECT sc.scope_id
           FROM app_provenance.artefact_scopes sc
          WHERE (sc.artefact_id = a.artefact_id)
          ORDER BY
                CASE sc.relationship
                    WHEN 'primary'::text THEN 0
                    ELSE 1
                END, sc.assigned_at DESC
         LIMIT 1) primary_scope ON (true))
     LEFT JOIN app_security.scopes s ON ((s.scope_id = primary_scope.scope_id)))
     LEFT JOIN app_provenance.v_artefact_current_location loc ON ((loc.artefact_id = a.artefact_id)))
  WHERE app_provenance.can_access_artefact(a.artefact_id);


--
-- Name: v_container_contents; Type: VIEW; Schema: app_provenance; Owner: -
--

CREATE VIEW app_provenance.v_container_contents AS
 SELECT cs.container_artefact_id,
    container.name AS container_name,
    container.status AS container_status,
    cs.container_slot_id,
    cs.slot_name,
    cs.display_name AS slot_display_name,
    cs."position",
    occupant.artefact_id,
    occupant.name AS artefact_name,
    occupant.status AS artefact_status,
    occupant.quantity,
    occupant.quantity_unit,
    occupant.created_at AS occupied_at,
    occupant.updated_at AS last_updated_at
   FROM ((app_provenance.container_slots cs
     JOIN app_provenance.artefacts container ON ((container.artefact_id = cs.container_artefact_id)))
     LEFT JOIN app_provenance.artefacts occupant ON (((occupant.container_slot_id = cs.container_slot_id) AND (occupant.container_artefact_id = cs.container_artefact_id) AND (occupant.status = ANY (ARRAY['draft'::text, 'active'::text, 'reserved'::text])))));


--
-- Name: api_clients; Type: TABLE; Schema: app_security; Owner: -
--

CREATE TABLE app_security.api_clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_identifier text NOT NULL,
    display_name text NOT NULL,
    description text,
    contact_email public.citext,
    allowed_roles text[] DEFAULT ARRAY[]::text[] NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    updated_by uuid,
    CONSTRAINT api_clients_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text))
);

ALTER TABLE ONLY app_security.api_clients FORCE ROW LEVEL SECURITY;


--
-- Name: api_tokens; Type: TABLE; Schema: app_security; Owner: -
--

CREATE TABLE app_security.api_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_client_id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_digest text NOT NULL,
    token_hint text NOT NULL,
    allowed_roles text[] DEFAULT ARRAY[]::text[] NOT NULL,
    expires_at timestamp with time zone,
    revoked_at timestamp with time zone,
    revoked_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    CONSTRAINT api_tokens_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT api_tokens_token_digest_check CHECK ((char_length(token_digest) = 64))
);

ALTER TABLE ONLY app_security.api_tokens FORCE ROW LEVEL SECURITY;


--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE; Schema: app_security; Owner: -
--

CREATE SEQUENCE app_security.audit_log_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: app_security; Owner: -
--

ALTER SEQUENCE app_security.audit_log_audit_id_seq OWNED BY app_security.audit_log.audit_id;


--
-- Name: scope_memberships; Type: TABLE; Schema: app_security; Owner: -
--

CREATE TABLE app_security.scope_memberships (
    scope_membership_id uuid DEFAULT gen_random_uuid() NOT NULL,
    scope_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role_name text NOT NULL,
    granted_by uuid,
    granted_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    expires_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT scope_memberships_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text))
);

ALTER TABLE ONLY app_security.scope_memberships FORCE ROW LEVEL SECURITY;


--
-- Name: scope_role_inheritance; Type: TABLE; Schema: app_security; Owner: -
--

CREATE TABLE app_security.scope_role_inheritance (
    parent_scope_type text NOT NULL,
    child_scope_type text NOT NULL,
    parent_role_name text NOT NULL,
    child_role_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT scope_role_inheritance_child_scope_type_check CHECK ((child_scope_type = lower(child_scope_type))),
    CONSTRAINT scope_role_inheritance_parent_scope_type_check CHECK ((parent_scope_type = lower(parent_scope_type)))
);

ALTER TABLE ONLY app_security.scope_role_inheritance FORCE ROW LEVEL SECURITY;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(128) NOT NULL
);


--
-- Name: audit_log audit_id; Type: DEFAULT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.audit_log ALTER COLUMN audit_id SET DEFAULT nextval('app_security.audit_log_audit_id_seq'::regclass);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: app_core; Owner: -
--

ALTER TABLE ONLY app_core.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (role_name);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: app_core; Owner: -
--

ALTER TABLE ONLY app_core.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_name);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: app_core; Owner: -
--

ALTER TABLE ONLY app_core.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_external_id_key; Type: CONSTRAINT; Schema: app_core; Owner: -
--

ALTER TABLE ONLY app_core.users
    ADD CONSTRAINT users_external_id_key UNIQUE (external_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: app_core; Owner: -
--

ALTER TABLE ONLY app_core.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: notebook_entries notebook_entries_entry_key_key; Type: CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entries
    ADD CONSTRAINT notebook_entries_entry_key_key UNIQUE (entry_key);


--
-- Name: notebook_entries notebook_entries_pkey; Type: CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entries
    ADD CONSTRAINT notebook_entries_pkey PRIMARY KEY (entry_id);


--
-- Name: notebook_entry_scopes notebook_entry_scopes_pkey; Type: CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entry_scopes
    ADD CONSTRAINT notebook_entry_scopes_pkey PRIMARY KEY (entry_id, scope_id, relationship);


--
-- Name: notebook_entry_versions notebook_entry_versions_entry_id_version_number_key; Type: CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entry_versions
    ADD CONSTRAINT notebook_entry_versions_entry_id_version_number_key UNIQUE (entry_id, version_number);


--
-- Name: notebook_entry_versions notebook_entry_versions_pkey; Type: CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entry_versions
    ADD CONSTRAINT notebook_entry_versions_pkey PRIMARY KEY (version_id);


--
-- Name: artefact_relationships artefact_relationships_parent_artefact_id_child_artefact_id_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_relationships
    ADD CONSTRAINT artefact_relationships_parent_artefact_id_child_artefact_id_key UNIQUE (parent_artefact_id, child_artefact_id, relationship_type);


--
-- Name: artefact_relationships artefact_relationships_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_relationships
    ADD CONSTRAINT artefact_relationships_pkey PRIMARY KEY (relationship_id);


--
-- Name: artefact_scopes artefact_scopes_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_scopes
    ADD CONSTRAINT artefact_scopes_pkey PRIMARY KEY (artefact_id, scope_id, relationship);


--
-- Name: artefact_trait_values artefact_trait_values_artefact_id_trait_id_effective_at_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_trait_values
    ADD CONSTRAINT artefact_trait_values_artefact_id_trait_id_effective_at_key UNIQUE (artefact_id, trait_id, effective_at);


--
-- Name: artefact_trait_values artefact_trait_values_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_trait_values
    ADD CONSTRAINT artefact_trait_values_pkey PRIMARY KEY (artefact_trait_value_id);


--
-- Name: artefact_traits artefact_traits_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_traits
    ADD CONSTRAINT artefact_traits_pkey PRIMARY KEY (trait_id);


--
-- Name: artefact_traits artefact_traits_trait_key_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_traits
    ADD CONSTRAINT artefact_traits_trait_key_key UNIQUE (trait_key);


--
-- Name: artefact_types artefact_types_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_types
    ADD CONSTRAINT artefact_types_pkey PRIMARY KEY (artefact_type_id);


--
-- Name: artefact_types artefact_types_type_key_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_types
    ADD CONSTRAINT artefact_types_type_key_key UNIQUE (type_key);


--
-- Name: artefacts artefacts_external_identifier_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefacts
    ADD CONSTRAINT artefacts_external_identifier_key UNIQUE (external_identifier);


--
-- Name: artefacts artefacts_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefacts
    ADD CONSTRAINT artefacts_pkey PRIMARY KEY (artefact_id);


--
-- Name: container_slot_definitions container_slot_definitions_artefact_type_id_slot_name_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.container_slot_definitions
    ADD CONSTRAINT container_slot_definitions_artefact_type_id_slot_name_key UNIQUE (artefact_type_id, slot_name);


--
-- Name: container_slot_definitions container_slot_definitions_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.container_slot_definitions
    ADD CONSTRAINT container_slot_definitions_pkey PRIMARY KEY (slot_definition_id);


--
-- Name: container_slots container_slots_container_artefact_id_slot_name_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.container_slots
    ADD CONSTRAINT container_slots_container_artefact_id_slot_name_key UNIQUE (container_artefact_id, slot_name);


--
-- Name: container_slots container_slots_container_unique; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.container_slots
    ADD CONSTRAINT container_slots_container_unique UNIQUE (container_slot_id, container_artefact_id);


--
-- Name: container_slots container_slots_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.container_slots
    ADD CONSTRAINT container_slots_pkey PRIMARY KEY (container_slot_id);


--
-- Name: process_instances process_instances_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_instances
    ADD CONSTRAINT process_instances_pkey PRIMARY KEY (process_instance_id);


--
-- Name: process_instances process_instances_process_identifier_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_instances
    ADD CONSTRAINT process_instances_process_identifier_key UNIQUE (process_identifier);


--
-- Name: process_io process_io_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_io
    ADD CONSTRAINT process_io_pkey PRIMARY KEY (process_io_id);


--
-- Name: process_scopes process_scopes_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_scopes
    ADD CONSTRAINT process_scopes_pkey PRIMARY KEY (process_instance_id, scope_id, relationship);


--
-- Name: process_types process_types_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_types
    ADD CONSTRAINT process_types_pkey PRIMARY KEY (process_type_id);


--
-- Name: process_types process_types_type_key_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_types
    ADD CONSTRAINT process_types_type_key_key UNIQUE (type_key);


--
-- Name: api_clients api_clients_client_identifier_key; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.api_clients
    ADD CONSTRAINT api_clients_client_identifier_key UNIQUE (client_identifier);


--
-- Name: api_clients api_clients_pkey; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.api_clients
    ADD CONSTRAINT api_clients_pkey PRIMARY KEY (id);


--
-- Name: api_tokens api_tokens_pkey; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.api_tokens
    ADD CONSTRAINT api_tokens_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (audit_id);


--
-- Name: scope_memberships scope_memberships_pkey; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scope_memberships
    ADD CONSTRAINT scope_memberships_pkey PRIMARY KEY (scope_membership_id);


--
-- Name: scope_memberships scope_memberships_scope_id_user_id_role_name_key; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scope_memberships
    ADD CONSTRAINT scope_memberships_scope_id_user_id_role_name_key UNIQUE (scope_id, user_id, role_name);


--
-- Name: scope_role_inheritance scope_role_inheritance_pkey; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scope_role_inheritance
    ADD CONSTRAINT scope_role_inheritance_pkey PRIMARY KEY (parent_scope_type, child_scope_type, parent_role_name, child_role_name);


--
-- Name: scopes scopes_parent_scope_id_display_name_key; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scopes
    ADD CONSTRAINT scopes_parent_scope_id_display_name_key UNIQUE (parent_scope_id, display_name);


--
-- Name: scopes scopes_pkey; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scopes
    ADD CONSTRAINT scopes_pkey PRIMARY KEY (scope_id);


--
-- Name: scopes scopes_scope_key_key; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scopes
    ADD CONSTRAINT scopes_scope_key_key UNIQUE (scope_key);


--
-- Name: transaction_contexts transaction_contexts_pkey; Type: CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.transaction_contexts
    ADD CONSTRAINT transaction_contexts_pkey PRIMARY KEY (txn_id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_notebook_entries_scope; Type: INDEX; Schema: app_eln; Owner: -
--

CREATE INDEX idx_notebook_entries_scope ON app_eln.notebook_entries USING btree (primary_scope_id);


--
-- Name: idx_notebook_entry_scopes_scope; Type: INDEX; Schema: app_eln; Owner: -
--

CREATE INDEX idx_notebook_entry_scopes_scope ON app_eln.notebook_entry_scopes USING btree (scope_id);


--
-- Name: idx_notebook_entry_versions_entry; Type: INDEX; Schema: app_eln; Owner: -
--

CREATE INDEX idx_notebook_entry_versions_entry ON app_eln.notebook_entry_versions USING btree (entry_id, version_number DESC);


--
-- Name: idx_artefact_scopes_scope; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_artefact_scopes_scope ON app_provenance.artefact_scopes USING btree (scope_id);


--
-- Name: idx_artefact_slot_unique; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE UNIQUE INDEX idx_artefact_slot_unique ON app_provenance.artefacts USING btree (container_slot_id) WHERE ((container_slot_id IS NOT NULL) AND (status = ANY (ARRAY['draft'::text, 'active'::text, 'reserved'::text])));


--
-- Name: idx_artefact_traits_type; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_artefact_traits_type ON app_provenance.artefact_traits USING btree (data_type);


--
-- Name: idx_artefact_types_kind; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_artefact_types_kind ON app_provenance.artefact_types USING btree (kind);


--
-- Name: idx_artefacts_status; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_artefacts_status ON app_provenance.artefacts USING btree (status);


--
-- Name: idx_artefacts_type; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_artefacts_type ON app_provenance.artefacts USING btree (artefact_type_id);


--
-- Name: idx_container_slots_container; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_container_slots_container ON app_provenance.container_slots USING btree (container_artefact_id);


--
-- Name: idx_process_instances_status; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_process_instances_status ON app_provenance.process_instances USING btree (status);


--
-- Name: idx_process_instances_type; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_process_instances_type ON app_provenance.process_instances USING btree (process_type_id);


--
-- Name: idx_process_io_artefact; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_process_io_artefact ON app_provenance.process_io USING btree (artefact_id);


--
-- Name: idx_process_io_process; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_process_io_process ON app_provenance.process_io USING btree (process_instance_id);


--
-- Name: idx_process_io_unique; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE UNIQUE INDEX idx_process_io_unique ON app_provenance.process_io USING btree (process_instance_id, artefact_id, direction, COALESCE(io_role, ''::text), COALESCE(multiplex_group, ''::text));


--
-- Name: idx_process_scopes_scope; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_process_scopes_scope ON app_provenance.process_scopes USING btree (scope_id);


--
-- Name: idx_relationships_child; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_relationships_child ON app_provenance.artefact_relationships USING btree (child_artefact_id);


--
-- Name: idx_relationships_parent; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_relationships_parent ON app_provenance.artefact_relationships USING btree (parent_artefact_id);


--
-- Name: idx_trait_values_effective; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_trait_values_effective ON app_provenance.artefact_trait_values USING btree (artefact_id, effective_at DESC);


--
-- Name: idx_trait_values_trait; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_trait_values_trait ON app_provenance.artefact_trait_values USING btree (trait_id);


--
-- Name: idx_audit_log_actor; Type: INDEX; Schema: app_security; Owner: -
--

CREATE INDEX idx_audit_log_actor ON app_security.audit_log USING btree (actor_id);


--
-- Name: idx_audit_log_table; Type: INDEX; Schema: app_security; Owner: -
--

CREATE INDEX idx_audit_log_table ON app_security.audit_log USING btree (schema_name, table_name);


--
-- Name: idx_audit_log_txn; Type: INDEX; Schema: app_security; Owner: -
--

CREATE INDEX idx_audit_log_txn ON app_security.audit_log USING btree (txn_id);


--
-- Name: idx_scope_memberships_scope; Type: INDEX; Schema: app_security; Owner: -
--

CREATE INDEX idx_scope_memberships_scope ON app_security.scope_memberships USING btree (scope_id);


--
-- Name: idx_scope_memberships_user; Type: INDEX; Schema: app_security; Owner: -
--

CREATE INDEX idx_scope_memberships_user ON app_security.scope_memberships USING btree (user_id);


--
-- Name: idx_scopes_parent; Type: INDEX; Schema: app_security; Owner: -
--

CREATE INDEX idx_scopes_parent ON app_security.scopes USING btree (parent_scope_id);


--
-- Name: idx_scopes_type; Type: INDEX; Schema: app_security; Owner: -
--

CREATE INDEX idx_scopes_type ON app_security.scopes USING btree (scope_type);


--
-- Name: idx_transaction_contexts_actor_id; Type: INDEX; Schema: app_security; Owner: -
--

CREATE INDEX idx_transaction_contexts_actor_id ON app_security.transaction_contexts USING btree (actor_id);


--
-- Name: idx_transaction_contexts_finished_at; Type: INDEX; Schema: app_security; Owner: -
--

CREATE INDEX idx_transaction_contexts_finished_at ON app_security.transaction_contexts USING btree (finished_at);


--
-- Name: idx_transaction_contexts_started_at; Type: INDEX; Schema: app_security; Owner: -
--

CREATE INDEX idx_transaction_contexts_started_at ON app_security.transaction_contexts USING btree (started_at);


--
-- Name: roles trg_audit_app_core_roles; Type: TRIGGER; Schema: app_core; Owner: -
--

CREATE TRIGGER trg_audit_app_core_roles AFTER INSERT OR DELETE OR UPDATE ON app_core.roles FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: user_roles trg_audit_app_core_user_roles; Type: TRIGGER; Schema: app_core; Owner: -
--

CREATE TRIGGER trg_audit_app_core_user_roles AFTER INSERT OR DELETE OR UPDATE ON app_core.user_roles FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: users trg_audit_app_core_users; Type: TRIGGER; Schema: app_core; Owner: -
--

CREATE TRIGGER trg_audit_app_core_users AFTER INSERT OR DELETE OR UPDATE ON app_core.users FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: users trg_touch_users; Type: TRIGGER; Schema: app_core; Owner: -
--

CREATE TRIGGER trg_touch_users BEFORE UPDATE ON app_core.users FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


--
-- Name: notebook_entries trg_assign_primary_scope; Type: TRIGGER; Schema: app_eln; Owner: -
--

CREATE TRIGGER trg_assign_primary_scope AFTER INSERT ON app_eln.notebook_entries FOR EACH ROW EXECUTE FUNCTION app_eln.tg_ensure_primary_scope();


--
-- Name: notebook_entries trg_audit_notebook_entries; Type: TRIGGER; Schema: app_eln; Owner: -
--

CREATE TRIGGER trg_audit_notebook_entries AFTER INSERT OR DELETE OR UPDATE ON app_eln.notebook_entries FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: notebook_entry_scopes trg_audit_notebook_entry_scopes; Type: TRIGGER; Schema: app_eln; Owner: -
--

CREATE TRIGGER trg_audit_notebook_entry_scopes AFTER INSERT OR DELETE OR UPDATE ON app_eln.notebook_entry_scopes FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: notebook_entry_versions trg_audit_notebook_entry_versions; Type: TRIGGER; Schema: app_eln; Owner: -
--

CREATE TRIGGER trg_audit_notebook_entry_versions AFTER INSERT OR DELETE OR UPDATE ON app_eln.notebook_entry_versions FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: notebook_entries trg_enforce_notebook_entry_status; Type: TRIGGER; Schema: app_eln; Owner: -
--

CREATE TRIGGER trg_enforce_notebook_entry_status BEFORE INSERT OR UPDATE ON app_eln.notebook_entries FOR EACH ROW EXECUTE FUNCTION app_eln.tg_enforce_entry_status();


--
-- Name: notebook_entry_versions trg_prepare_notebook_version; Type: TRIGGER; Schema: app_eln; Owner: -
--

CREATE TRIGGER trg_prepare_notebook_version BEFORE INSERT ON app_eln.notebook_entry_versions FOR EACH ROW EXECUTE FUNCTION app_eln.tg_prepare_notebook_version();


--
-- Name: notebook_entries trg_touch_notebook_entries; Type: TRIGGER; Schema: app_eln; Owner: -
--

CREATE TRIGGER trg_touch_notebook_entries BEFORE UPDATE ON app_eln.notebook_entries FOR EACH ROW EXECUTE FUNCTION app_eln.tg_touch_notebook_entry();


--
-- Name: artefact_relationships trg_audit_artefact_relationships; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_artefact_relationships AFTER INSERT OR DELETE OR UPDATE ON app_provenance.artefact_relationships FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: artefact_scopes trg_audit_artefact_scopes; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_artefact_scopes AFTER INSERT OR DELETE OR UPDATE ON app_provenance.artefact_scopes FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: artefact_trait_values trg_audit_artefact_trait_values; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_artefact_trait_values AFTER INSERT OR DELETE OR UPDATE ON app_provenance.artefact_trait_values FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: artefact_traits trg_audit_artefact_traits; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_artefact_traits AFTER INSERT OR DELETE OR UPDATE ON app_provenance.artefact_traits FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: artefact_types trg_audit_artefact_types; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_artefact_types AFTER INSERT OR DELETE OR UPDATE ON app_provenance.artefact_types FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: artefacts trg_audit_artefacts; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_artefacts AFTER INSERT OR DELETE OR UPDATE ON app_provenance.artefacts FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: container_slot_definitions trg_audit_container_slot_definitions; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_container_slot_definitions AFTER INSERT OR DELETE OR UPDATE ON app_provenance.container_slot_definitions FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: container_slots trg_audit_container_slots; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_container_slots AFTER INSERT OR DELETE OR UPDATE ON app_provenance.container_slots FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: process_instances trg_audit_process_instances; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_process_instances AFTER INSERT OR DELETE OR UPDATE ON app_provenance.process_instances FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: process_io trg_audit_process_io; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_process_io AFTER INSERT OR DELETE OR UPDATE ON app_provenance.process_io FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: process_scopes trg_audit_process_scopes; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_process_scopes AFTER INSERT OR DELETE OR UPDATE ON app_provenance.process_scopes FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: process_types trg_audit_process_types; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_process_types AFTER INSERT OR DELETE OR UPDATE ON app_provenance.process_types FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: artefacts trg_enforce_container_membership; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_enforce_container_membership BEFORE INSERT OR UPDATE ON app_provenance.artefacts FOR EACH ROW EXECUTE FUNCTION app_provenance.tg_enforce_container_membership();


--
-- Name: artefacts trg_propagate_handover; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_propagate_handover AFTER UPDATE OF metadata ON app_provenance.artefacts FOR EACH ROW EXECUTE FUNCTION app_provenance.tg_propagate_handover();


--
-- Name: artefact_traits trg_touch_artefact_traits; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_touch_artefact_traits BEFORE UPDATE ON app_provenance.artefact_traits FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


--
-- Name: artefact_types trg_touch_artefact_types; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_touch_artefact_types BEFORE UPDATE ON app_provenance.artefact_types FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


--
-- Name: artefacts trg_touch_artefacts; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_touch_artefacts BEFORE UPDATE ON app_provenance.artefacts FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


--
-- Name: process_instances trg_touch_process_instances; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_touch_process_instances BEFORE UPDATE ON app_provenance.process_instances FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


--
-- Name: process_types trg_touch_process_types; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_touch_process_types BEFORE UPDATE ON app_provenance.process_types FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


--
-- Name: api_clients trg_audit_api_clients; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_audit_api_clients AFTER INSERT OR DELETE OR UPDATE ON app_security.api_clients FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: api_tokens trg_audit_api_tokens; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_audit_api_tokens AFTER INSERT OR DELETE OR UPDATE ON app_security.api_tokens FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: scope_memberships trg_audit_scope_memberships; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_audit_scope_memberships AFTER INSERT OR DELETE OR UPDATE ON app_security.scope_memberships FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: scope_role_inheritance trg_audit_scope_role_inheritance; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_audit_scope_role_inheritance AFTER INSERT OR DELETE OR UPDATE ON app_security.scope_role_inheritance FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: scopes trg_audit_scopes; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_audit_scopes AFTER INSERT OR DELETE OR UPDATE ON app_security.scopes FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: transaction_contexts trg_mark_transaction_committed; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_mark_transaction_committed AFTER INSERT ON app_security.transaction_contexts DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION app_security.mark_transaction_committed();


--
-- Name: api_clients trg_touch_api_clients; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_touch_api_clients BEFORE UPDATE ON app_security.api_clients FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


--
-- Name: scope_memberships trg_touch_scope_memberships; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_touch_scope_memberships BEFORE UPDATE ON app_security.scope_memberships FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


--
-- Name: scopes trg_touch_scopes; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_touch_scopes BEFORE UPDATE ON app_security.scopes FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


--
-- Name: user_roles user_roles_granted_by_fkey; Type: FK CONSTRAINT; Schema: app_core; Owner: -
--

ALTER TABLE ONLY app_core.user_roles
    ADD CONSTRAINT user_roles_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES app_core.users(id) ON DELETE SET NULL;


--
-- Name: user_roles user_roles_role_name_fkey; Type: FK CONSTRAINT; Schema: app_core; Owner: -
--

ALTER TABLE ONLY app_core.user_roles
    ADD CONSTRAINT user_roles_role_name_fkey FOREIGN KEY (role_name) REFERENCES app_core.roles(role_name) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: app_core; Owner: -
--

ALTER TABLE ONLY app_core.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_core.users(id) ON DELETE CASCADE;


--
-- Name: users users_default_role_fkey; Type: FK CONSTRAINT; Schema: app_core; Owner: -
--

ALTER TABLE ONLY app_core.users
    ADD CONSTRAINT users_default_role_fkey FOREIGN KEY (default_role) REFERENCES app_core.roles(role_name);


--
-- Name: notebook_entries notebook_entries_created_by_fkey; Type: FK CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entries
    ADD CONSTRAINT notebook_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: notebook_entries notebook_entries_locked_by_fkey; Type: FK CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entries
    ADD CONSTRAINT notebook_entries_locked_by_fkey FOREIGN KEY (locked_by) REFERENCES app_core.users(id);


--
-- Name: notebook_entries notebook_entries_primary_scope_id_fkey; Type: FK CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entries
    ADD CONSTRAINT notebook_entries_primary_scope_id_fkey FOREIGN KEY (primary_scope_id) REFERENCES app_security.scopes(scope_id) ON DELETE RESTRICT;


--
-- Name: notebook_entries notebook_entries_submitted_by_fkey; Type: FK CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entries
    ADD CONSTRAINT notebook_entries_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES app_core.users(id);


--
-- Name: notebook_entries notebook_entries_updated_by_fkey; Type: FK CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entries
    ADD CONSTRAINT notebook_entries_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES app_core.users(id);


--
-- Name: notebook_entry_scopes notebook_entry_scopes_assigned_by_fkey; Type: FK CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entry_scopes
    ADD CONSTRAINT notebook_entry_scopes_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES app_core.users(id);


--
-- Name: notebook_entry_scopes notebook_entry_scopes_entry_id_fkey; Type: FK CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entry_scopes
    ADD CONSTRAINT notebook_entry_scopes_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES app_eln.notebook_entries(entry_id) ON DELETE CASCADE;


--
-- Name: notebook_entry_scopes notebook_entry_scopes_scope_id_fkey; Type: FK CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entry_scopes
    ADD CONSTRAINT notebook_entry_scopes_scope_id_fkey FOREIGN KEY (scope_id) REFERENCES app_security.scopes(scope_id) ON DELETE CASCADE;


--
-- Name: notebook_entry_versions notebook_entry_versions_created_by_fkey; Type: FK CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entry_versions
    ADD CONSTRAINT notebook_entry_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: notebook_entry_versions notebook_entry_versions_entry_id_fkey; Type: FK CONSTRAINT; Schema: app_eln; Owner: -
--

ALTER TABLE ONLY app_eln.notebook_entry_versions
    ADD CONSTRAINT notebook_entry_versions_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES app_eln.notebook_entries(entry_id) ON DELETE CASCADE;


--
-- Name: artefact_relationships artefact_relationships_child_artefact_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_relationships
    ADD CONSTRAINT artefact_relationships_child_artefact_id_fkey FOREIGN KEY (child_artefact_id) REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE;


--
-- Name: artefact_relationships artefact_relationships_created_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_relationships
    ADD CONSTRAINT artefact_relationships_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: artefact_relationships artefact_relationships_parent_artefact_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_relationships
    ADD CONSTRAINT artefact_relationships_parent_artefact_id_fkey FOREIGN KEY (parent_artefact_id) REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE;


--
-- Name: artefact_relationships artefact_relationships_process_instance_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_relationships
    ADD CONSTRAINT artefact_relationships_process_instance_id_fkey FOREIGN KEY (process_instance_id) REFERENCES app_provenance.process_instances(process_instance_id) ON DELETE SET NULL;


--
-- Name: artefact_scopes artefact_scopes_artefact_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_scopes
    ADD CONSTRAINT artefact_scopes_artefact_id_fkey FOREIGN KEY (artefact_id) REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE;


--
-- Name: artefact_scopes artefact_scopes_assigned_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_scopes
    ADD CONSTRAINT artefact_scopes_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES app_core.users(id);


--
-- Name: artefact_scopes artefact_scopes_scope_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_scopes
    ADD CONSTRAINT artefact_scopes_scope_id_fkey FOREIGN KEY (scope_id) REFERENCES app_security.scopes(scope_id) ON DELETE CASCADE;


--
-- Name: artefact_trait_values artefact_trait_values_artefact_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_trait_values
    ADD CONSTRAINT artefact_trait_values_artefact_id_fkey FOREIGN KEY (artefact_id) REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE;


--
-- Name: artefact_trait_values artefact_trait_values_recorded_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_trait_values
    ADD CONSTRAINT artefact_trait_values_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES app_core.users(id);


--
-- Name: artefact_trait_values artefact_trait_values_trait_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_trait_values
    ADD CONSTRAINT artefact_trait_values_trait_id_fkey FOREIGN KEY (trait_id) REFERENCES app_provenance.artefact_traits(trait_id) ON DELETE CASCADE;


--
-- Name: artefact_traits artefact_traits_created_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_traits
    ADD CONSTRAINT artefact_traits_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: artefact_traits artefact_traits_updated_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_traits
    ADD CONSTRAINT artefact_traits_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES app_core.users(id);


--
-- Name: artefact_types artefact_types_created_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_types
    ADD CONSTRAINT artefact_types_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: artefact_types artefact_types_updated_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_types
    ADD CONSTRAINT artefact_types_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES app_core.users(id);


--
-- Name: artefacts artefacts_artefact_type_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefacts
    ADD CONSTRAINT artefacts_artefact_type_id_fkey FOREIGN KEY (artefact_type_id) REFERENCES app_provenance.artefact_types(artefact_type_id);


--
-- Name: artefacts artefacts_container_artefact_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefacts
    ADD CONSTRAINT artefacts_container_artefact_id_fkey FOREIGN KEY (container_artefact_id) REFERENCES app_provenance.artefacts(artefact_id) ON DELETE SET NULL;


--
-- Name: artefacts artefacts_container_slot_fk; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefacts
    ADD CONSTRAINT artefacts_container_slot_fk FOREIGN KEY (container_slot_id, container_artefact_id) REFERENCES app_provenance.container_slots(container_slot_id, container_artefact_id) ON DELETE SET NULL;


--
-- Name: artefacts artefacts_created_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefacts
    ADD CONSTRAINT artefacts_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: artefacts artefacts_origin_process_instance_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefacts
    ADD CONSTRAINT artefacts_origin_process_instance_id_fkey FOREIGN KEY (origin_process_instance_id) REFERENCES app_provenance.process_instances(process_instance_id) ON DELETE SET NULL;


--
-- Name: artefacts artefacts_updated_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefacts
    ADD CONSTRAINT artefacts_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES app_core.users(id);


--
-- Name: container_slot_definitions container_slot_definitions_artefact_type_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.container_slot_definitions
    ADD CONSTRAINT container_slot_definitions_artefact_type_id_fkey FOREIGN KEY (artefact_type_id) REFERENCES app_provenance.artefact_types(artefact_type_id) ON DELETE CASCADE;


--
-- Name: container_slots container_slots_container_artefact_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.container_slots
    ADD CONSTRAINT container_slots_container_artefact_id_fkey FOREIGN KEY (container_artefact_id) REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE;


--
-- Name: container_slots container_slots_slot_definition_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.container_slots
    ADD CONSTRAINT container_slots_slot_definition_id_fkey FOREIGN KEY (slot_definition_id) REFERENCES app_provenance.container_slot_definitions(slot_definition_id) ON DELETE SET NULL;


--
-- Name: process_instances process_instances_created_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_instances
    ADD CONSTRAINT process_instances_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: process_instances process_instances_executed_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_instances
    ADD CONSTRAINT process_instances_executed_by_fkey FOREIGN KEY (executed_by) REFERENCES app_core.users(id);


--
-- Name: process_instances process_instances_process_type_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_instances
    ADD CONSTRAINT process_instances_process_type_id_fkey FOREIGN KEY (process_type_id) REFERENCES app_provenance.process_types(process_type_id);


--
-- Name: process_instances process_instances_updated_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_instances
    ADD CONSTRAINT process_instances_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES app_core.users(id);


--
-- Name: process_io process_io_artefact_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_io
    ADD CONSTRAINT process_io_artefact_id_fkey FOREIGN KEY (artefact_id) REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE;


--
-- Name: process_io process_io_process_instance_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_io
    ADD CONSTRAINT process_io_process_instance_id_fkey FOREIGN KEY (process_instance_id) REFERENCES app_provenance.process_instances(process_instance_id) ON DELETE CASCADE;


--
-- Name: process_scopes process_scopes_assigned_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_scopes
    ADD CONSTRAINT process_scopes_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES app_core.users(id);


--
-- Name: process_scopes process_scopes_process_instance_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_scopes
    ADD CONSTRAINT process_scopes_process_instance_id_fkey FOREIGN KEY (process_instance_id) REFERENCES app_provenance.process_instances(process_instance_id) ON DELETE CASCADE;


--
-- Name: process_scopes process_scopes_scope_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_scopes
    ADD CONSTRAINT process_scopes_scope_id_fkey FOREIGN KEY (scope_id) REFERENCES app_security.scopes(scope_id) ON DELETE CASCADE;


--
-- Name: process_types process_types_created_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_types
    ADD CONSTRAINT process_types_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: process_types process_types_updated_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.process_types
    ADD CONSTRAINT process_types_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES app_core.users(id);


--
-- Name: api_clients api_clients_created_by_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.api_clients
    ADD CONSTRAINT api_clients_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: api_clients api_clients_updated_by_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.api_clients
    ADD CONSTRAINT api_clients_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES app_core.users(id);


--
-- Name: api_tokens api_tokens_api_client_id_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.api_tokens
    ADD CONSTRAINT api_tokens_api_client_id_fkey FOREIGN KEY (api_client_id) REFERENCES app_security.api_clients(id) ON DELETE CASCADE;


--
-- Name: api_tokens api_tokens_created_by_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.api_tokens
    ADD CONSTRAINT api_tokens_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: api_tokens api_tokens_revoked_by_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.api_tokens
    ADD CONSTRAINT api_tokens_revoked_by_fkey FOREIGN KEY (revoked_by) REFERENCES app_core.users(id);


--
-- Name: api_tokens api_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.api_tokens
    ADD CONSTRAINT api_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_core.users(id) ON DELETE CASCADE;


--
-- Name: audit_log audit_log_txn_id_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.audit_log
    ADD CONSTRAINT audit_log_txn_id_fkey FOREIGN KEY (txn_id) REFERENCES app_security.transaction_contexts(txn_id) ON DELETE CASCADE;


--
-- Name: scope_memberships scope_memberships_granted_by_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scope_memberships
    ADD CONSTRAINT scope_memberships_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES app_core.users(id);


--
-- Name: scope_memberships scope_memberships_role_name_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scope_memberships
    ADD CONSTRAINT scope_memberships_role_name_fkey FOREIGN KEY (role_name) REFERENCES app_core.roles(role_name);


--
-- Name: scope_memberships scope_memberships_scope_id_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scope_memberships
    ADD CONSTRAINT scope_memberships_scope_id_fkey FOREIGN KEY (scope_id) REFERENCES app_security.scopes(scope_id) ON DELETE CASCADE;


--
-- Name: scope_memberships scope_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scope_memberships
    ADD CONSTRAINT scope_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_core.users(id) ON DELETE CASCADE;


--
-- Name: scope_role_inheritance scope_role_inheritance_child_role_name_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scope_role_inheritance
    ADD CONSTRAINT scope_role_inheritance_child_role_name_fkey FOREIGN KEY (child_role_name) REFERENCES app_core.roles(role_name);


--
-- Name: scope_role_inheritance scope_role_inheritance_parent_role_name_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scope_role_inheritance
    ADD CONSTRAINT scope_role_inheritance_parent_role_name_fkey FOREIGN KEY (parent_role_name) REFERENCES app_core.roles(role_name);


--
-- Name: scopes scopes_created_by_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scopes
    ADD CONSTRAINT scopes_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: scopes scopes_parent_scope_id_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scopes
    ADD CONSTRAINT scopes_parent_scope_id_fkey FOREIGN KEY (parent_scope_id) REFERENCES app_security.scopes(scope_id) ON DELETE CASCADE;


--
-- Name: scopes scopes_updated_by_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.scopes
    ADD CONSTRAINT scopes_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES app_core.users(id);


--
-- Name: transaction_contexts transaction_contexts_actor_id_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.transaction_contexts
    ADD CONSTRAINT transaction_contexts_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES app_core.users(id);


--
-- Name: transaction_contexts transaction_contexts_finished_by_fkey; Type: FK CONSTRAINT; Schema: app_security; Owner: -
--

ALTER TABLE ONLY app_security.transaction_contexts
    ADD CONSTRAINT transaction_contexts_finished_by_fkey FOREIGN KEY (finished_by) REFERENCES app_core.users(id);


--
-- Name: roles; Type: ROW SECURITY; Schema: app_core; Owner: -
--

ALTER TABLE app_core.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: roles roles_admin_manage; Type: POLICY; Schema: app_core; Owner: -
--

CREATE POLICY roles_admin_manage ON app_core.roles USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: roles roles_read_any; Type: POLICY; Schema: app_core; Owner: -
--

CREATE POLICY roles_read_any ON app_core.roles FOR SELECT USING (true);


--
-- Name: user_roles; Type: ROW SECURITY; Schema: app_core; Owner: -
--

ALTER TABLE app_core.user_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: user_roles user_roles_admin_manage; Type: POLICY; Schema: app_core; Owner: -
--

CREATE POLICY user_roles_admin_manage ON app_core.user_roles USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: users; Type: ROW SECURITY; Schema: app_core; Owner: -
--

ALTER TABLE app_core.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_admin_manage; Type: POLICY; Schema: app_core; Owner: -
--

CREATE POLICY users_admin_manage ON app_core.users USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: users users_self_or_admin_read; Type: POLICY; Schema: app_core; Owner: -
--

CREATE POLICY users_self_or_admin_read ON app_core.users FOR SELECT USING ((app_security.has_role('app_admin'::text) OR (id = app_security.current_actor_id())));


--
-- Name: notebook_entries; Type: ROW SECURITY; Schema: app_eln; Owner: -
--

ALTER TABLE app_eln.notebook_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: notebook_entries notebook_entries_delete; Type: POLICY; Schema: app_eln; Owner: -
--

CREATE POLICY notebook_entries_delete ON app_eln.notebook_entries FOR DELETE USING (app_security.has_role('app_admin'::text));


--
-- Name: notebook_entries notebook_entries_insert; Type: POLICY; Schema: app_eln; Owner: -
--

CREATE POLICY notebook_entries_insert ON app_eln.notebook_entries FOR INSERT WITH CHECK ((app_security.has_role('app_admin'::text) OR app_security.actor_has_scope(primary_scope_id, ARRAY['app_researcher'::text, 'app_operator'::text, 'app_admin'::text])));


--
-- Name: notebook_entries notebook_entries_select; Type: POLICY; Schema: app_eln; Owner: -
--

CREATE POLICY notebook_entries_select ON app_eln.notebook_entries FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_eln.can_access_entry(entry_id) OR app_security.actor_has_scope(primary_scope_id)));


--
-- Name: notebook_entries notebook_entries_update; Type: POLICY; Schema: app_eln; Owner: -
--

CREATE POLICY notebook_entries_update ON app_eln.notebook_entries FOR UPDATE USING ((app_security.has_role('app_admin'::text) OR app_eln.can_access_entry(entry_id, ARRAY['app_researcher'::text, 'app_operator'::text, 'app_admin'::text]))) WITH CHECK ((app_security.has_role('app_admin'::text) OR app_eln.can_access_entry(entry_id, ARRAY['app_researcher'::text, 'app_operator'::text, 'app_admin'::text])));


--
-- Name: notebook_entry_scopes; Type: ROW SECURITY; Schema: app_eln; Owner: -
--

ALTER TABLE app_eln.notebook_entry_scopes ENABLE ROW LEVEL SECURITY;

--
-- Name: notebook_entry_scopes notebook_entry_scopes_modify; Type: POLICY; Schema: app_eln; Owner: -
--

CREATE POLICY notebook_entry_scopes_modify ON app_eln.notebook_entry_scopes USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: notebook_entry_scopes notebook_entry_scopes_select; Type: POLICY; Schema: app_eln; Owner: -
--

CREATE POLICY notebook_entry_scopes_select ON app_eln.notebook_entry_scopes FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_eln.can_access_entry(entry_id)));


--
-- Name: notebook_entry_versions; Type: ROW SECURITY; Schema: app_eln; Owner: -
--

ALTER TABLE app_eln.notebook_entry_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: notebook_entry_versions notebook_entry_versions_delete; Type: POLICY; Schema: app_eln; Owner: -
--

CREATE POLICY notebook_entry_versions_delete ON app_eln.notebook_entry_versions FOR DELETE USING (app_security.has_role('app_admin'::text));


--
-- Name: notebook_entry_versions notebook_entry_versions_insert; Type: POLICY; Schema: app_eln; Owner: -
--

CREATE POLICY notebook_entry_versions_insert ON app_eln.notebook_entry_versions FOR INSERT WITH CHECK ((app_security.has_role('app_admin'::text) OR app_eln.can_edit_entry(entry_id)));


--
-- Name: notebook_entry_versions notebook_entry_versions_select; Type: POLICY; Schema: app_eln; Owner: -
--

CREATE POLICY notebook_entry_versions_select ON app_eln.notebook_entry_versions FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_eln.can_access_entry(entry_id)));


--
-- Name: artefact_relationships; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.artefact_relationships ENABLE ROW LEVEL SECURITY;

--
-- Name: artefact_relationships artefact_relationships_modify; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_relationships_modify ON app_provenance.artefact_relationships USING ((app_security.has_role('app_admin'::text) OR (app_provenance.can_access_artefact(parent_artefact_id, ARRAY['app_operator'::text]) AND app_provenance.can_access_artefact(child_artefact_id, ARRAY['app_operator'::text])))) WITH CHECK ((app_security.has_role('app_admin'::text) OR (app_provenance.can_access_artefact(parent_artefact_id, ARRAY['app_operator'::text]) AND app_provenance.can_access_artefact(child_artefact_id, ARRAY['app_operator'::text]))));


--
-- Name: artefact_relationships artefact_relationships_select; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_relationships_select ON app_provenance.artefact_relationships FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(parent_artefact_id) OR app_provenance.can_access_artefact(child_artefact_id)));


--
-- Name: artefact_scopes; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.artefact_scopes ENABLE ROW LEVEL SECURITY;

--
-- Name: artefact_scopes artefact_scopes_modify; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_scopes_modify ON app_provenance.artefact_scopes USING ((app_security.has_role('app_admin'::text) OR app_security.has_role('app_operator'::text))) WITH CHECK ((app_security.has_role('app_admin'::text) OR app_security.has_role('app_operator'::text)));


--
-- Name: artefact_scopes artefact_scopes_select; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_scopes_select ON app_provenance.artefact_scopes FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(artefact_id)));


--
-- Name: artefact_trait_values; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.artefact_trait_values ENABLE ROW LEVEL SECURITY;

--
-- Name: artefact_trait_values artefact_trait_values_modify; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_trait_values_modify ON app_provenance.artefact_trait_values USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(artefact_id, ARRAY['app_operator'::text]))) WITH CHECK ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(artefact_id, ARRAY['app_operator'::text])));


--
-- Name: artefact_trait_values artefact_trait_values_select; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_trait_values_select ON app_provenance.artefact_trait_values FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(artefact_id)));


--
-- Name: artefact_traits; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.artefact_traits ENABLE ROW LEVEL SECURITY;

--
-- Name: artefact_traits artefact_traits_admin_manage; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_traits_admin_manage ON app_provenance.artefact_traits USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: artefact_traits artefact_traits_read; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_traits_read ON app_provenance.artefact_traits FOR SELECT USING (true);


--
-- Name: artefact_types; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.artefact_types ENABLE ROW LEVEL SECURITY;

--
-- Name: artefact_types artefact_types_admin_manage; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_types_admin_manage ON app_provenance.artefact_types USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: artefact_types artefact_types_read; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_types_read ON app_provenance.artefact_types FOR SELECT USING (true);


--
-- Name: artefacts; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.artefacts ENABLE ROW LEVEL SECURITY;

--
-- Name: artefacts artefacts_delete; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefacts_delete ON app_provenance.artefacts FOR DELETE USING (app_security.has_role('app_admin'::text));


--
-- Name: artefacts artefacts_insert; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefacts_insert ON app_provenance.artefacts FOR INSERT WITH CHECK ((app_security.has_role('app_admin'::text) OR app_security.has_role('app_operator'::text) OR app_security.has_role('app_automation'::text)));


--
-- Name: artefacts artefacts_select; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefacts_select ON app_provenance.artefacts FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(artefact_id)));


--
-- Name: artefacts artefacts_update; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefacts_update ON app_provenance.artefacts FOR UPDATE USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(artefact_id, ARRAY['app_operator'::text, 'app_automation'::text, 'app_researcher'::text]))) WITH CHECK ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(artefact_id, ARRAY['app_operator'::text, 'app_automation'::text, 'app_researcher'::text])));


--
-- Name: container_slot_definitions; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.container_slot_definitions ENABLE ROW LEVEL SECURITY;

--
-- Name: container_slot_definitions container_slot_definitions_manage; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY container_slot_definitions_manage ON app_provenance.container_slot_definitions USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: container_slot_definitions container_slot_definitions_read; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY container_slot_definitions_read ON app_provenance.container_slot_definitions FOR SELECT USING (true);


--
-- Name: container_slots; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.container_slots ENABLE ROW LEVEL SECURITY;

--
-- Name: container_slots container_slots_modify; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY container_slots_modify ON app_provenance.container_slots USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(container_artefact_id, ARRAY['app_operator'::text]))) WITH CHECK ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(container_artefact_id, ARRAY['app_operator'::text])));


--
-- Name: container_slots container_slots_select; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY container_slots_select ON app_provenance.container_slots FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(container_artefact_id)));


--
-- Name: process_instances; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.process_instances ENABLE ROW LEVEL SECURITY;

--
-- Name: process_instances process_instances_delete; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_instances_delete ON app_provenance.process_instances FOR DELETE USING (app_security.has_role('app_admin'::text));


--
-- Name: process_instances process_instances_insert; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_instances_insert ON app_provenance.process_instances FOR INSERT WITH CHECK ((app_security.has_role('app_admin'::text) OR app_security.has_role('app_operator'::text) OR app_security.has_role('app_automation'::text)));


--
-- Name: process_instances process_instances_select; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_instances_select ON app_provenance.process_instances FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_process(process_instance_id)));


--
-- Name: process_instances process_instances_update; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_instances_update ON app_provenance.process_instances FOR UPDATE USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator'::text, 'app_automation'::text, 'app_researcher'::text]))) WITH CHECK ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator'::text, 'app_automation'::text, 'app_researcher'::text])));


--
-- Name: process_io; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.process_io ENABLE ROW LEVEL SECURITY;

--
-- Name: process_io process_io_delete; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_io_delete ON app_provenance.process_io FOR DELETE USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator'::text])));


--
-- Name: process_io process_io_select; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_io_select ON app_provenance.process_io FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_process(process_instance_id) OR app_provenance.can_access_artefact(artefact_id)));


--
-- Name: process_io process_io_update; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_io_update ON app_provenance.process_io FOR UPDATE USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator'::text, 'app_automation'::text]))) WITH CHECK ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator'::text, 'app_automation'::text])));


--
-- Name: process_io process_io_write; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_io_write ON app_provenance.process_io FOR INSERT WITH CHECK ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_process(process_instance_id, ARRAY['app_operator'::text, 'app_automation'::text])));


--
-- Name: process_scopes; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.process_scopes ENABLE ROW LEVEL SECURITY;

--
-- Name: process_scopes process_scopes_modify; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_scopes_modify ON app_provenance.process_scopes USING ((app_security.has_role('app_admin'::text) OR app_security.has_role('app_operator'::text))) WITH CHECK ((app_security.has_role('app_admin'::text) OR app_security.has_role('app_operator'::text)));


--
-- Name: process_scopes process_scopes_select; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_scopes_select ON app_provenance.process_scopes FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_process(process_instance_id)));


--
-- Name: process_types; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.process_types ENABLE ROW LEVEL SECURITY;

--
-- Name: process_types process_types_admin_manage; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_types_admin_manage ON app_provenance.process_types USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: process_types process_types_read; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY process_types_read ON app_provenance.process_types FOR SELECT USING (true);


--
-- Name: api_clients; Type: ROW SECURITY; Schema: app_security; Owner: -
--

ALTER TABLE app_security.api_clients ENABLE ROW LEVEL SECURITY;

--
-- Name: api_clients api_clients_admin_manage; Type: POLICY; Schema: app_security; Owner: -
--

CREATE POLICY api_clients_admin_manage ON app_security.api_clients USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: api_tokens; Type: ROW SECURITY; Schema: app_security; Owner: -
--

ALTER TABLE app_security.api_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: api_tokens api_tokens_admin_manage; Type: POLICY; Schema: app_security; Owner: -
--

CREATE POLICY api_tokens_admin_manage ON app_security.api_tokens USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: audit_log; Type: ROW SECURITY; Schema: app_security; Owner: -
--

ALTER TABLE app_security.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log audit_log_admin_read; Type: POLICY; Schema: app_security; Owner: -
--

CREATE POLICY audit_log_admin_read ON app_security.audit_log FOR SELECT USING (app_security.has_role('app_admin'::text));


--
-- Name: scope_memberships; Type: ROW SECURITY; Schema: app_security; Owner: -
--

ALTER TABLE app_security.scope_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: scope_memberships scope_memberships_admin_manage; Type: POLICY; Schema: app_security; Owner: -
--

CREATE POLICY scope_memberships_admin_manage ON app_security.scope_memberships USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: scope_memberships scope_memberships_read_access; Type: POLICY; Schema: app_security; Owner: -
--

CREATE POLICY scope_memberships_read_access ON app_security.scope_memberships FOR SELECT USING ((app_security.has_role('app_admin'::text) OR (user_id = app_security.current_actor_id()) OR app_security.actor_has_scope(scope_id)));


--
-- Name: scope_role_inheritance; Type: ROW SECURITY; Schema: app_security; Owner: -
--

ALTER TABLE app_security.scope_role_inheritance ENABLE ROW LEVEL SECURITY;

--
-- Name: scope_role_inheritance scope_role_inheritance_admin_manage; Type: POLICY; Schema: app_security; Owner: -
--

CREATE POLICY scope_role_inheritance_admin_manage ON app_security.scope_role_inheritance USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: scope_role_inheritance scope_role_inheritance_read_access; Type: POLICY; Schema: app_security; Owner: -
--

CREATE POLICY scope_role_inheritance_read_access ON app_security.scope_role_inheritance FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_security.has_role('app_operator'::text)));


--
-- Name: scopes; Type: ROW SECURITY; Schema: app_security; Owner: -
--

ALTER TABLE app_security.scopes ENABLE ROW LEVEL SECURITY;

--
-- Name: scopes scopes_admin_manage; Type: POLICY; Schema: app_security; Owner: -
--

CREATE POLICY scopes_admin_manage ON app_security.scopes USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


--
-- Name: scopes scopes_read_access; Type: POLICY; Schema: app_security; Owner: -
--

CREATE POLICY scopes_read_access ON app_security.scopes FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_security.actor_has_scope(scope_id)));


--
-- Name: postgraphile_watch_ddl; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER postgraphile_watch_ddl ON ddl_command_end
         WHEN TAG IN ('ALTER AGGREGATE', 'ALTER DOMAIN', 'ALTER EXTENSION', 'ALTER FOREIGN TABLE', 'ALTER FUNCTION', 'ALTER POLICY', 'ALTER SCHEMA', 'ALTER TABLE', 'ALTER TYPE', 'ALTER VIEW', 'COMMENT', 'CREATE AGGREGATE', 'CREATE DOMAIN', 'CREATE EXTENSION', 'CREATE FOREIGN TABLE', 'CREATE FUNCTION', 'CREATE INDEX', 'CREATE POLICY', 'CREATE RULE', 'CREATE SCHEMA', 'CREATE TABLE', 'CREATE TABLE AS', 'CREATE VIEW', 'DROP AGGREGATE', 'DROP DOMAIN', 'DROP EXTENSION', 'DROP FOREIGN TABLE', 'DROP FUNCTION', 'DROP INDEX', 'DROP OWNED', 'DROP POLICY', 'DROP RULE', 'DROP SCHEMA', 'DROP TABLE', 'DROP TYPE', 'DROP VIEW', 'GRANT', 'REVOKE', 'SELECT INTO')
   EXECUTE FUNCTION postgraphile_watch.notify_watchers_ddl();


--
-- Name: postgraphile_watch_drop; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER postgraphile_watch_drop ON sql_drop
   EXECUTE FUNCTION postgraphile_watch.notify_watchers_drop();


--
-- PostgreSQL database dump complete
--

\unrestrict jYWeOf8VunMdUKfASs5z5n0l4ZKHGiX0sgpOZfep9DiZnyLckFH2euYaAE4dEe0


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20251010000000'),
    ('20251010001000'),
    ('20251010002000'),
    ('20251010003000'),
    ('20251010004000'),
    ('20251010005000'),
    ('20251010006000'),
    ('20251010007000'),
    ('20251010008000'),
    ('20251010009000'),
    ('20251010010000'),
    ('20251010011000'),
    ('20251010012000'),
    ('20251010013000'),
    ('20251010013500'),
    ('20251010014000'),
    ('20251010014500'),
    ('20251010015000'),
    ('20251010015100'),
    ('20251010015200'),
    ('20251010015300'),
    ('20251010015400'),
    ('20251010016000'),
    ('20251010017000'),
    ('20251010017100'),
    ('20251010017200'),
    ('20251010018000'),
    ('20251010018100'),
    ('20251010018200'),
    ('20251010018300'),
    ('20251010018400'),
    ('20251010018500'),
    ('20251010018600');
