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
  SELECT lower(p_role) = ANY(app_security.current_roles());
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
-- Name: api_clients trg_audit_api_clients; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_audit_api_clients AFTER INSERT OR DELETE OR UPDATE ON app_security.api_clients FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: api_tokens trg_audit_api_tokens; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_audit_api_tokens AFTER INSERT OR DELETE OR UPDATE ON app_security.api_tokens FOR EACH ROW EXECUTE FUNCTION app_security.record_audit();


--
-- Name: transaction_contexts trg_mark_transaction_committed; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_mark_transaction_committed AFTER INSERT ON app_security.transaction_contexts DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION app_security.mark_transaction_committed();


--
-- Name: api_clients trg_touch_api_clients; Type: TRIGGER; Schema: app_security; Owner: -
--

CREATE TRIGGER trg_touch_api_clients BEFORE UPDATE ON app_security.api_clients FOR EACH ROW EXECUTE FUNCTION app_security.touch_updated_at();


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
    ('20251010008000');
