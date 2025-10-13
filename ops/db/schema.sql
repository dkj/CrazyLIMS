\restrict 5xeENcvMfOjbkpQFGnS6efnrNtqZ3t13V2HehTibUuS5Eoztp6d1VmkgtMI9rBy

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
-- Name: can_access_artefact(uuid, text[]); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.can_access_artefact(p_artefact_id uuid, p_required_roles text[] DEFAULT NULL::text[]) RETURNS boolean
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
DECLARE
  v_scope uuid;
BEGIN
  IF p_storage_node_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_security.session_has_role('app_admin') THEN
    RETURN true;
  END IF;

  SELECT scope_id
    INTO v_scope
    FROM app_provenance.storage_nodes
   WHERE storage_node_id = p_storage_node_id
     AND is_active;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_scope IS NULL THEN
    RETURN true;
  END IF;

  RETURN app_security.actor_has_scope(v_scope, p_required_roles);
END;
$$;


--
-- Name: storage_path(uuid); Type: FUNCTION; Schema: app_provenance; Owner: -
--

CREATE FUNCTION app_provenance.storage_path(p_storage_node_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_provenance'
    SET row_security TO 'on'
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
-- Name: artefact_storage_events; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.artefact_storage_events (
    storage_event_id uuid DEFAULT gen_random_uuid() NOT NULL,
    artefact_id uuid NOT NULL,
    from_storage_node_id uuid,
    to_storage_node_id uuid,
    event_type text NOT NULL,
    occurred_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    actor_id uuid,
    process_instance_id uuid,
    reason text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT artefact_storage_events_check CHECK (((from_storage_node_id IS NOT NULL) OR (to_storage_node_id IS NOT NULL) OR (event_type = 'register'::text))),
    CONSTRAINT artefact_storage_events_event_type_check CHECK ((event_type = ANY (ARRAY['register'::text, 'move'::text, 'check_in'::text, 'check_out'::text, 'disposed'::text, 'location_correction'::text]))),
    CONSTRAINT artefact_storage_events_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text))
);

ALTER TABLE ONLY app_provenance.artefact_storage_events FORCE ROW LEVEL SECURITY;


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
    CONSTRAINT artefact_types_kind_check CHECK ((kind = ANY (ARRAY['subject'::text, 'material'::text, 'reagent'::text, 'container'::text, 'data_product'::text, 'instrument_run'::text, 'workflow'::text, 'instrument'::text, 'virtual'::text, 'other'::text]))),
    CONSTRAINT artefact_types_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT artefact_types_type_key_check CHECK ((type_key = lower(type_key)))
);

ALTER TABLE ONLY app_provenance.artefact_types FORCE ROW LEVEL SECURITY;


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
-- Name: storage_nodes; Type: TABLE; Schema: app_provenance; Owner: -
--

CREATE TABLE app_provenance.storage_nodes (
    storage_node_id uuid DEFAULT gen_random_uuid() NOT NULL,
    node_key text NOT NULL,
    node_type text NOT NULL,
    display_name text NOT NULL,
    description text,
    parent_storage_node_id uuid,
    scope_id uuid,
    barcode text,
    environment jsonb DEFAULT '{}'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_by uuid,
    CONSTRAINT storage_nodes_check CHECK (((parent_storage_node_id IS NULL) OR (parent_storage_node_id <> storage_node_id))),
    CONSTRAINT storage_nodes_environment_check CHECK ((jsonb_typeof(environment) = ANY (ARRAY['object'::text, 'null'::text]))),
    CONSTRAINT storage_nodes_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT storage_nodes_node_key_check CHECK ((node_key = lower(node_key))),
    CONSTRAINT storage_nodes_node_type_check CHECK ((node_type = ANY (ARRAY['facility'::text, 'unit'::text, 'sublocation'::text, 'virtual'::text, 'external'::text])))
);

ALTER TABLE ONLY app_provenance.storage_nodes FORCE ROW LEVEL SECURITY;


--
-- Name: v_artefact_current_location; Type: VIEW; Schema: app_provenance; Owner: -
--

CREATE VIEW app_provenance.v_artefact_current_location AS
 WITH latest_event AS (
         SELECT DISTINCT ON (ase.artefact_id) ase.artefact_id,
            ase.event_type,
            ase.occurred_at,
            ase.to_storage_node_id,
            ase.from_storage_node_id,
            ase.metadata
           FROM app_provenance.artefact_storage_events ase
          ORDER BY ase.artefact_id, ase.occurred_at DESC
        )
 SELECT le.artefact_id,
        CASE
            WHEN (le.event_type = ANY (ARRAY['check_out'::text, 'disposed'::text])) THEN NULL::uuid
            ELSE le.to_storage_node_id
        END AS storage_node_id,
    sn.display_name AS storage_display_name,
    sn.node_type,
    sn.scope_id,
    COALESCE(sn.environment, '{}'::jsonb) AS environment,
    le.event_type AS last_event_type,
    le.occurred_at AS last_event_at
   FROM (latest_event le
     LEFT JOIN app_provenance.storage_nodes sn ON ((sn.storage_node_id = le.to_storage_node_id)));


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
     LEFT JOIN app_provenance.container_slots slot ON ((slot.container_artefact_id = lab.artefact_id)))
     LEFT JOIN app_provenance.artefacts sample ON (((sample.container_slot_id = slot.container_slot_id) AND (sample.container_artefact_id = lab.artefact_id))))
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
 SELECT facility.storage_node_id AS facility_id,
    facility.display_name AS facility_name,
    unit.storage_node_id AS unit_id,
    unit.display_name AS unit_name,
    node.node_type AS storage_type,
        CASE
            WHEN (node.node_type = 'sublocation'::text) THEN node.storage_node_id
            ELSE NULL::uuid
        END AS sublocation_id,
        CASE
            WHEN (node.node_type = 'sublocation'::text) THEN node.display_name
            ELSE NULL::text
        END AS sublocation_name,
        CASE
            WHEN (node.node_type = 'sublocation'::text) THEN node.parent_storage_node_id
            ELSE NULL::uuid
        END AS parent_sublocation_id,
    NULL::integer AS capacity,
    app_provenance.storage_path(node.storage_node_id) AS storage_path,
    COALESCE(metrics.labware_count, (0)::bigint) AS labware_count,
    COALESCE(metrics.sample_count, (0)::bigint) AS sample_count
   FROM (((app_provenance.storage_nodes node
     LEFT JOIN LATERAL ( WITH RECURSIVE descend AS (
                 SELECT node.storage_node_id
                UNION ALL
                 SELECT child.storage_node_id
                   FROM (app_provenance.storage_nodes child
                     JOIN descend ON ((child.parent_storage_node_id = descend.storage_node_id)))
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
             JOIN app_provenance.v_artefact_current_location loc ON ((loc.storage_node_id = d.storage_node_id)))
             JOIN app_provenance.artefacts art ON ((art.artefact_id = loc.artefact_id)))
             JOIN app_provenance.artefact_types at ON ((at.artefact_type_id = art.artefact_type_id)))
          WHERE app_provenance.can_access_artefact(art.artefact_id)) metrics ON (true))
     LEFT JOIN LATERAL ( WITH RECURSIVE ascend AS (
                 SELECT node.storage_node_id,
                    node.parent_storage_node_id,
                    node.display_name,
                    node.scope_id,
                    node.node_type
                UNION ALL
                 SELECT parent.storage_node_id,
                    parent.parent_storage_node_id,
                    parent.display_name,
                    parent.scope_id,
                    parent.node_type
                   FROM (app_provenance.storage_nodes parent
                     JOIN ascend child ON ((child.parent_storage_node_id = parent.storage_node_id)))
                )
         SELECT ascend.storage_node_id,
            ascend.display_name,
            ascend.scope_id
           FROM ascend
          WHERE (ascend.node_type = 'facility'::text)
          ORDER BY
                CASE
                    WHEN (ascend.storage_node_id = node.storage_node_id) THEN 0
                    ELSE 1
                END
         LIMIT 1) facility(storage_node_id, display_name, scope_id) ON (true))
     LEFT JOIN LATERAL ( WITH RECURSIVE ascend AS (
                 SELECT node.storage_node_id,
                    node.parent_storage_node_id,
                    node.display_name,
                    node.node_type
                UNION ALL
                 SELECT parent.storage_node_id,
                    parent.parent_storage_node_id,
                    parent.display_name,
                    parent.node_type
                   FROM (app_provenance.storage_nodes parent
                     JOIN ascend child ON ((child.parent_storage_node_id = parent.storage_node_id)))
                )
         SELECT ascend.storage_node_id,
            ascend.display_name
           FROM ascend
          WHERE (ascend.node_type = 'unit'::text)
          ORDER BY
                CASE
                    WHEN (ascend.storage_node_id = node.storage_node_id) THEN 0
                    ELSE 1
                END
         LIMIT 1) unit(storage_node_id, display_name) ON (true))
  WHERE ((metrics.labware_count IS NOT NULL) OR (metrics.sample_count IS NOT NULL) OR app_provenance.can_access_storage_node(node.storage_node_id));


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
     LEFT JOIN app_provenance.artefacts occupant ON (((occupant.container_slot_id = cs.container_slot_id) AND (occupant.container_artefact_id = cs.container_artefact_id))));


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
-- Name: artefact_storage_events artefact_storage_events_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_storage_events
    ADD CONSTRAINT artefact_storage_events_pkey PRIMARY KEY (storage_event_id);


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
-- Name: storage_nodes storage_nodes_node_key_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.storage_nodes
    ADD CONSTRAINT storage_nodes_node_key_key UNIQUE (node_key);


--
-- Name: storage_nodes storage_nodes_parent_storage_node_id_display_name_key; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.storage_nodes
    ADD CONSTRAINT storage_nodes_parent_storage_node_id_display_name_key UNIQUE (parent_storage_node_id, display_name);


--
-- Name: storage_nodes storage_nodes_pkey; Type: CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.storage_nodes
    ADD CONSTRAINT storage_nodes_pkey PRIMARY KEY (storage_node_id);


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
-- Name: idx_artefact_scopes_scope; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_artefact_scopes_scope ON app_provenance.artefact_scopes USING btree (scope_id);


--
-- Name: idx_artefact_slot_unique; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE UNIQUE INDEX idx_artefact_slot_unique ON app_provenance.artefacts USING btree (container_slot_id) WHERE (container_slot_id IS NOT NULL);


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
-- Name: idx_storage_events_artefact; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_storage_events_artefact ON app_provenance.artefact_storage_events USING btree (artefact_id, occurred_at DESC);


--
-- Name: idx_storage_events_process; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_storage_events_process ON app_provenance.artefact_storage_events USING btree (process_instance_id);


--
-- Name: idx_storage_nodes_parent; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_storage_nodes_parent ON app_provenance.storage_nodes USING btree (parent_storage_node_id);


--
-- Name: idx_storage_nodes_scope; Type: INDEX; Schema: app_provenance; Owner: -
--

CREATE INDEX idx_storage_nodes_scope ON app_provenance.storage_nodes USING btree (scope_id);


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
-- Name: artefact_relationships trg_audit_artefact_relationships; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_artefact_relationships AFTER INSERT OR DELETE OR UPDATE ON app_provenance.artefact_relationships FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: artefact_scopes trg_audit_artefact_scopes; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_artefact_scopes AFTER INSERT OR DELETE OR UPDATE ON app_provenance.artefact_scopes FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: artefact_storage_events trg_audit_artefact_storage_events; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_artefact_storage_events AFTER INSERT OR DELETE OR UPDATE ON app_provenance.artefact_storage_events FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


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
-- Name: storage_nodes trg_audit_storage_nodes; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_audit_storage_nodes AFTER INSERT OR DELETE OR UPDATE ON app_provenance.storage_nodes FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: artefacts trg_enforce_container_membership; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_enforce_container_membership BEFORE INSERT OR UPDATE ON app_provenance.artefacts FOR EACH ROW EXECUTE FUNCTION app_provenance.tg_enforce_container_membership();


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
-- Name: storage_nodes trg_touch_storage_nodes; Type: TRIGGER; Schema: app_provenance; Owner: -
--

CREATE TRIGGER trg_touch_storage_nodes BEFORE UPDATE ON app_provenance.storage_nodes FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


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
-- Name: artefact_storage_events artefact_storage_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_storage_events
    ADD CONSTRAINT artefact_storage_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES app_core.users(id);


--
-- Name: artefact_storage_events artefact_storage_events_artefact_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_storage_events
    ADD CONSTRAINT artefact_storage_events_artefact_id_fkey FOREIGN KEY (artefact_id) REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE;


--
-- Name: artefact_storage_events artefact_storage_events_from_storage_node_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_storage_events
    ADD CONSTRAINT artefact_storage_events_from_storage_node_id_fkey FOREIGN KEY (from_storage_node_id) REFERENCES app_provenance.storage_nodes(storage_node_id) ON DELETE SET NULL;


--
-- Name: artefact_storage_events artefact_storage_events_process_instance_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_storage_events
    ADD CONSTRAINT artefact_storage_events_process_instance_id_fkey FOREIGN KEY (process_instance_id) REFERENCES app_provenance.process_instances(process_instance_id) ON DELETE SET NULL;


--
-- Name: artefact_storage_events artefact_storage_events_to_storage_node_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.artefact_storage_events
    ADD CONSTRAINT artefact_storage_events_to_storage_node_id_fkey FOREIGN KEY (to_storage_node_id) REFERENCES app_provenance.storage_nodes(storage_node_id) ON DELETE SET NULL;


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
-- Name: storage_nodes storage_nodes_created_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.storage_nodes
    ADD CONSTRAINT storage_nodes_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_core.users(id);


--
-- Name: storage_nodes storage_nodes_parent_storage_node_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.storage_nodes
    ADD CONSTRAINT storage_nodes_parent_storage_node_id_fkey FOREIGN KEY (parent_storage_node_id) REFERENCES app_provenance.storage_nodes(storage_node_id) ON DELETE CASCADE;


--
-- Name: storage_nodes storage_nodes_scope_id_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.storage_nodes
    ADD CONSTRAINT storage_nodes_scope_id_fkey FOREIGN KEY (scope_id) REFERENCES app_security.scopes(scope_id) ON DELETE SET NULL;


--
-- Name: storage_nodes storage_nodes_updated_by_fkey; Type: FK CONSTRAINT; Schema: app_provenance; Owner: -
--

ALTER TABLE ONLY app_provenance.storage_nodes
    ADD CONSTRAINT storage_nodes_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES app_core.users(id);


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
-- Name: artefact_storage_events; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.artefact_storage_events ENABLE ROW LEVEL SECURITY;

--
-- Name: artefact_storage_events artefact_storage_events_delete; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_storage_events_delete ON app_provenance.artefact_storage_events FOR DELETE USING (app_security.has_role('app_admin'::text));


--
-- Name: artefact_storage_events artefact_storage_events_insert; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_storage_events_insert ON app_provenance.artefact_storage_events FOR INSERT WITH CHECK ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(artefact_id, ARRAY['app_operator'::text, 'app_automation'::text])));


--
-- Name: artefact_storage_events artefact_storage_events_select; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_storage_events_select ON app_provenance.artefact_storage_events FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_artefact(artefact_id)));


--
-- Name: artefact_storage_events artefact_storage_events_update; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY artefact_storage_events_update ON app_provenance.artefact_storage_events FOR UPDATE USING (app_security.has_role('app_admin'::text)) WITH CHECK (app_security.has_role('app_admin'::text));


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
-- Name: storage_nodes; Type: ROW SECURITY; Schema: app_provenance; Owner: -
--

ALTER TABLE app_provenance.storage_nodes ENABLE ROW LEVEL SECURITY;

--
-- Name: storage_nodes storage_nodes_modify; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY storage_nodes_modify ON app_provenance.storage_nodes USING ((app_security.has_role('app_admin'::text) OR app_security.has_role('app_operator'::text))) WITH CHECK ((app_security.has_role('app_admin'::text) OR app_security.has_role('app_operator'::text)));


--
-- Name: storage_nodes storage_nodes_select; Type: POLICY; Schema: app_provenance; Owner: -
--

CREATE POLICY storage_nodes_select ON app_provenance.storage_nodes FOR SELECT USING ((app_security.has_role('app_admin'::text) OR app_provenance.can_access_storage_node(storage_node_id)));


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

\unrestrict 5xeENcvMfOjbkpQFGnS6efnrNtqZ3t13V2HehTibUuS5Eoztp6d1VmkgtMI9rBy


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
    ('20251010014500');
