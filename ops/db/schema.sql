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
-- Name: lims; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA lims;


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
-- Name: can_access_inventory_item(uuid); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.can_access_inventory_item(p_inventory_item_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
BEGIN
  IF p_inventory_item_id IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN lims.has_role('app_admin') OR lims.has_role('app_operator');
END;
$$;


--
-- Name: can_access_labware(uuid); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.can_access_labware(p_labware_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
BEGIN
  IF p_labware_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.samples s
    WHERE s.current_labware_id = p_labware_id
      AND lims.can_access_project(s.project_id)
  )
  OR EXISTS (
    SELECT 1
    FROM lims.sample_labware_assignments sla
    JOIN lims.samples s ON s.id = sla.sample_id
    WHERE sla.labware_id = p_labware_id
      AND sla.released_at IS NULL
      AND lims.can_access_project(s.project_id)
  );
END;
$$;


--
-- Name: can_access_project(uuid); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.can_access_project(p_project_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
BEGIN
  IF p_project_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.project_members pm
    WHERE pm.project_id = p_project_id
      AND pm.user_id = lims.current_user_id()
  );
END;
$$;


--
-- Name: can_access_sample(uuid); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.can_access_sample(p_sample_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
BEGIN
  IF p_sample_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.samples s
    WHERE s.id = p_sample_id
      AND lims.can_access_project(s.project_id)
  );
END;
$$;


--
-- Name: can_access_storage_facility(uuid); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.can_access_storage_facility(p_facility_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
BEGIN
  IF p_facility_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.storage_units su
    WHERE su.facility_id = p_facility_id
      AND lims.can_access_storage_unit(su.id)
  );
END;
$$;


--
-- Name: can_access_storage_sublocation(uuid); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.can_access_storage_sublocation(p_sublocation_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
BEGIN
  IF p_sublocation_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.labware lw
    WHERE lw.current_storage_sublocation_id = p_sublocation_id
      AND lims.can_access_labware(lw.id)
  );
END;
$$;


--
-- Name: can_access_storage_unit(uuid); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.can_access_storage_unit(p_unit_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
BEGIN
  IF p_unit_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.storage_sublocations ss
    WHERE ss.unit_id = p_unit_id
      AND lims.can_access_storage_sublocation(ss.id)
  );
END;
$$;


--
-- Name: create_api_token(uuid, text, text[], timestamp with time zone, jsonb); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.create_api_token(p_user_id uuid, p_plain_token text, p_allowed_roles text[] DEFAULT NULL::text[], p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
DECLARE
  token_hash text;
  token_hint text;
  new_id uuid;
  roles text[];
BEGIN
  IF p_plain_token IS NULL OR length(p_plain_token) < 32 THEN
    RAISE EXCEPTION 'API token must be at least 32 characters long';
  END IF;

  IF jsonb_typeof(p_metadata) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'metadata must be a JSON object';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lims.users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;

  roles := COALESCE(p_allowed_roles,
    ARRAY(SELECT role_name FROM lims.user_roles WHERE user_id = p_user_id));

  token_hash := encode(digest(p_plain_token, 'sha256'), 'hex');
  token_hint := right(p_plain_token, 6);

  INSERT INTO lims.user_tokens (
    user_id,
    token_digest,
    allowed_roles,
    token_hint,
    expires_at,
    created_by,
    metadata
  )
  VALUES (
    p_user_id,
    token_hash,
    COALESCE(roles, ARRAY[]::text[]),
    token_hint,
    p_expires_at,
    lims.current_user_id(),
    COALESCE(p_metadata, '{}'::jsonb)
  )
  RETURNING id INTO new_id;

  RETURN new_id;
END;
$$;


--
-- Name: current_actor(); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.current_actor() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
DECLARE
  claims jsonb := lims.current_claims();
  actor text;
BEGIN
  IF claims ? 'preferred_username' THEN
    actor := claims->>'preferred_username';
  ELSIF claims ? 'email' THEN
    actor := claims->>'email';
  ELSIF claims ? 'sub' THEN
    actor := claims->>'sub';
  END IF;

  IF actor IS NULL THEN
    SELECT u.email INTO actor FROM lims.users u WHERE u.id = lims.current_user_id();
  END IF;

  RETURN COALESCE(actor, current_user);
END;
$$;


--
-- Name: current_claims(); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.current_claims() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
DECLARE
  raw text;
BEGIN
  raw := current_setting('request.jwt.claims', true);
  IF raw IS NULL OR raw = '' THEN
    RETURN '{}'::jsonb;
  END IF;
  RETURN raw::jsonb;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN '{}'::jsonb;
  WHEN others THEN
    RETURN '{}'::jsonb;
END;
$$;


--
-- Name: current_roles(); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.current_roles() RETURNS text[]
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
DECLARE
  claims jsonb := lims.current_claims();
  role_list text[] := ARRAY[]::text[];
  cfg text;
  active_role text;
BEGIN
  IF claims ? 'roles' THEN
    role_list := ARRAY(SELECT lower(value) FROM jsonb_array_elements_text(claims->'roles') AS value);
  ELSIF claims ? 'role' THEN
    role_list := ARRAY[lower(claims->>'role')];
  END IF;

  cfg := current_setting('lims.current_roles', true);
  IF cfg IS NOT NULL AND cfg <> '' THEN
    role_list := role_list || string_to_array(lower(cfg), ',');
  END IF;

  active_role := lower(current_setting('role', true));
  IF active_role IS NULL OR active_role = '' OR active_role = 'none' THEN
    active_role := lower(current_user::text);
  END IF;

  RETURN role_list || ARRAY(
    SELECT DISTINCT lower(r.rolname)
    FROM pg_roles r
    WHERE pg_has_role(active_role, r.rolname, 'member')
      AND r.rolname LIKE 'app_%'
  );
END;
$$;


--
-- Name: current_user_id(); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.current_user_id() RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
DECLARE
  claims jsonb := lims.current_claims();
  user_id uuid;
  cfg text;
BEGIN
  cfg := current_setting('lims.current_user_id', true);
  IF cfg IS NOT NULL AND cfg <> '' THEN
    BEGIN
      user_id := cfg::uuid;
    EXCEPTION
      WHEN invalid_text_representation THEN
        user_id := NULL;
    END;
  END IF;

  IF user_id IS NULL AND claims ? 'user_id' THEN
    BEGIN
      user_id := (claims ->> 'user_id')::uuid;
    EXCEPTION
      WHEN invalid_text_representation THEN
        user_id := NULL;
    END;
  END IF;

  IF user_id IS NULL AND claims ? 'sub' THEN
    SELECT u.id INTO user_id
    FROM lims.users u
    WHERE u.external_id = claims->>'sub'
    LIMIT 1;
  END IF;

  IF user_id IS NULL AND claims ? 'email' THEN
    SELECT u.id INTO user_id
    FROM lims.users u
    WHERE lower(u.email) = lower(claims->>'email')
    LIMIT 1;
  END IF;

  RETURN user_id;
END;
$$;


--
-- Name: fn_audit(); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.fn_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
DECLARE
  new_doc jsonb;
  old_doc jsonb;
  pk text := NULL;
  row_diff jsonb;
  user_component text;
  role_component text;
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    new_doc := to_jsonb(NEW);
  END IF;
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    old_doc := to_jsonb(OLD);
  END IF;

  IF new_doc IS NOT NULL AND new_doc ? 'id' THEN
    pk := new_doc->>'id';
  ELSIF old_doc IS NOT NULL AND old_doc ? 'id' THEN
    pk := old_doc->>'id';
  END IF;

  IF pk IS NULL THEN
    IF new_doc IS NOT NULL AND new_doc ? 'role_name' THEN
      pk := new_doc->>'role_name';
    ELSIF old_doc IS NOT NULL AND old_doc ? 'role_name' THEN
      pk := old_doc->>'role_name';
    END IF;
  END IF;

  IF pk IS NULL THEN
    IF new_doc IS NOT NULL AND new_doc ? 'email' THEN
      pk := new_doc->>'email';
    ELSIF old_doc IS NOT NULL AND old_doc ? 'email' THEN
      pk := old_doc->>'email';
    END IF;
  END IF;

  IF pk IS NULL AND (
        (new_doc IS NOT NULL AND new_doc ? 'user_id')
        OR (old_doc IS NOT NULL AND old_doc ? 'user_id')
      ) THEN
    user_component := CASE
      WHEN new_doc IS NOT NULL AND new_doc ? 'user_id' THEN new_doc->>'user_id'
      ELSE old_doc->>'user_id'
    END;
    role_component := CASE
      WHEN new_doc IS NOT NULL AND new_doc ? 'role_name' THEN new_doc->>'role_name'
      ELSE old_doc->>'role_name'
    END;
    pk := concat_ws(':', user_component, role_component);
  END IF;

  IF TG_OP = 'INSERT' THEN
    row_diff := jsonb_build_object('new', new_doc);
  ELSIF TG_OP = 'UPDATE' THEN
    row_diff := jsonb_build_object('old', old_doc, 'new', new_doc);
  ELSE
    row_diff := jsonb_build_object('old', old_doc);
  END IF;

  INSERT INTO lims.audit_log(actor_id, actor_identity, actor_roles, action, table_name, row_pk, diff)
  VALUES (
    lims.current_user_id(),
    lims.current_actor(),
    COALESCE(lims.current_roles(), ARRAY[]::text[]),
    TG_OP,
    TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
    pk,
    row_diff
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: fn_samples_set_project(); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.fn_samples_set_project() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
DECLARE
  proj_id uuid;
BEGIN
  IF NEW.project_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.project_code IS NULL THEN
    RAISE EXCEPTION 'project_id or project_code must be supplied';
  END IF;

  SELECT id INTO proj_id FROM lims.projects WHERE project_code = NEW.project_code;

  IF proj_id IS NULL THEN
    INSERT INTO lims.projects(project_code, name)
    VALUES (NEW.project_code, NEW.project_code)
    ON CONFLICT (project_code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO proj_id;
  END IF;

  NEW.project_id := proj_id;
  RETURN NEW;
END;
$$;


--
-- Name: fn_touch_updated_at(); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.fn_touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$$;


--
-- Name: has_role(text); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.has_role(role_name text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
DECLARE
  normalized text := lower(role_name);
  role_entry text;
BEGIN
  IF role_name IS NULL OR role_name = '' THEN
    RETURN false;
  END IF;

  FOREACH role_entry IN ARRAY lims.current_roles() LOOP
    IF lower(role_entry) = normalized THEN
      RETURN true;
    END IF;
  END LOOP;

  IF lims.current_user_id() IS NOT NULL THEN
    RETURN EXISTS (
      SELECT 1
      FROM lims.user_roles ur
      WHERE ur.user_id = lims.current_user_id()
        AND lower(ur.role_name) = normalized
    );
  END IF;

  RETURN false;
END;
$$;


--
-- Name: pre_request(jsonb); Type: FUNCTION; Schema: lims; Owner: -
--

CREATE FUNCTION lims.pre_request(jwt jsonb DEFAULT NULL::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'lims'
    AS $$
DECLARE
  claims jsonb := COALESCE(jwt, '{}'::jsonb);
  roles_array text[] := ARRAY[]::text[];
  roles_csv text := '';
  user_id uuid;
  role_text text;
BEGIN
  IF claims IS NULL OR claims::text = 'null' THEN
    claims := '{}'::jsonb;
  END IF;

  IF claims ? 'roles' THEN
    roles_array := ARRAY(SELECT lower(value) FROM jsonb_array_elements_text(claims->'roles') AS value);
  END IF;

  IF array_length(roles_array, 1) IS NULL AND claims ? 'role' THEN
    roles_array := ARRAY[lower(claims->>'role')];
  END IF;

  IF array_length(roles_array, 1) IS NOT NULL THEN
    roles_csv := array_to_string(roles_array, ',');
  END IF;

  IF claims ? 'user_id' THEN
    BEGIN
      user_id := (claims ->> 'user_id')::uuid;
    EXCEPTION
      WHEN invalid_text_representation THEN
        user_id := NULL;
    END;
  END IF;

  IF user_id IS NULL AND claims ? 'sub' THEN
    SELECT u.id INTO user_id
    FROM lims.users u
    WHERE u.external_id = claims->>'sub'
    LIMIT 1;
  END IF;

  IF user_id IS NOT NULL THEN
    PERFORM set_config('lims.current_user_id', user_id::text, true);
  ELSE
    PERFORM set_config('lims.current_user_id', '', true);
  END IF;

  PERFORM set_config('lims.current_roles', roles_csv, true);

  IF array_length(roles_array, 1) IS NOT NULL THEN
    role_text := roles_array[1];
    IF role_text IS NOT NULL AND role_text <> '' THEN
      PERFORM set_config('role', role_text, true);
    END IF;
  END IF;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.audit_log (
    id bigint NOT NULL,
    ts timestamp with time zone DEFAULT now() NOT NULL,
    actor_id uuid,
    actor_identity text,
    actor_roles text[] DEFAULT ARRAY[]::text[] NOT NULL,
    action text NOT NULL,
    table_name text NOT NULL,
    row_pk text,
    diff jsonb
);


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: lims; Owner: -
--

CREATE SEQUENCE lims.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: lims; Owner: -
--

ALTER SEQUENCE lims.audit_log_id_seq OWNED BY lims.audit_log.id;


--
-- Name: custody_event_types; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.custody_event_types (
    event_type text NOT NULL,
    description text NOT NULL,
    requires_destination boolean DEFAULT false NOT NULL
);


--
-- Name: custody_events; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.custody_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sample_id uuid NOT NULL,
    labware_id uuid,
    from_sublocation_id uuid,
    to_sublocation_id uuid,
    event_type text NOT NULL,
    performed_by uuid,
    performed_at timestamp with time zone DEFAULT now() NOT NULL,
    event_notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

ALTER TABLE ONLY lims.custody_events FORCE ROW LEVEL SECURITY;


--
-- Name: inventory_items; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.inventory_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    barcode text,
    name text NOT NULL,
    description text,
    catalogue_number text,
    lot_number text,
    quantity numeric DEFAULT 0 NOT NULL,
    unit text DEFAULT 'unit'::text NOT NULL,
    minimum_quantity numeric,
    storage_requirements text,
    expires_at timestamp with time zone,
    storage_sublocation_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY lims.inventory_items FORCE ROW LEVEL SECURITY;


--
-- Name: inventory_transaction_types; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.inventory_transaction_types (
    transaction_type text NOT NULL,
    description text NOT NULL,
    direction text NOT NULL,
    CONSTRAINT inventory_transaction_types_direction_check CHECK ((direction = ANY (ARRAY['increase'::text, 'decrease'::text, 'neutral'::text])))
);


--
-- Name: inventory_transactions; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.inventory_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    inventory_item_id uuid NOT NULL,
    transaction_type text NOT NULL,
    quantity_delta numeric NOT NULL,
    unit text,
    reason text,
    performed_at timestamp with time zone DEFAULT now() NOT NULL,
    performed_by uuid,
    resulting_quantity numeric,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

ALTER TABLE ONLY lims.inventory_transactions FORCE ROW LEVEL SECURITY;


--
-- Name: labware; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.labware (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    labware_type_id uuid,
    barcode text,
    display_name text,
    status text DEFAULT 'in_use'::text NOT NULL,
    is_disposable boolean DEFAULT false NOT NULL,
    expected_disposal_at timestamp with time zone,
    current_storage_sublocation_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY lims.labware FORCE ROW LEVEL SECURITY;


--
-- Name: labware_location_history; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.labware_location_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    labware_id uuid NOT NULL,
    storage_sublocation_id uuid,
    moved_at timestamp with time zone DEFAULT now() NOT NULL,
    moved_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

ALTER TABLE ONLY lims.labware_location_history FORCE ROW LEVEL SECURITY;


--
-- Name: labware_positions; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.labware_positions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    labware_id uuid NOT NULL,
    position_label text NOT NULL,
    row_index integer,
    column_index integer,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

ALTER TABLE ONLY lims.labware_positions FORCE ROW LEVEL SECURITY;


--
-- Name: labware_types; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.labware_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    capacity integer,
    layout jsonb DEFAULT '{}'::jsonb NOT NULL,
    barcode_format text,
    is_disposable boolean DEFAULT false NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: project_members; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.project_members (
    project_id uuid NOT NULL,
    user_id uuid NOT NULL,
    member_role text,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    added_by uuid
);

ALTER TABLE ONLY lims.project_members FORCE ROW LEVEL SECURITY;


--
-- Name: projects; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_code text NOT NULL,
    name text NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);

ALTER TABLE ONLY lims.projects FORCE ROW LEVEL SECURITY;


--
-- Name: roles; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.roles (
    role_name text NOT NULL,
    display_name text NOT NULL,
    description text,
    is_system_role boolean DEFAULT false NOT NULL,
    is_assignable boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT roles_role_name_check CHECK ((role_name = lower(role_name)))
);

ALTER TABLE ONLY lims.roles FORCE ROW LEVEL SECURITY;


--
-- Name: sample_derivations; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.sample_derivations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_sample_id uuid NOT NULL,
    child_sample_id uuid NOT NULL,
    method text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

ALTER TABLE ONLY lims.sample_derivations FORCE ROW LEVEL SECURITY;


--
-- Name: sample_labware_assignments; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.sample_labware_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sample_id uuid NOT NULL,
    labware_id uuid NOT NULL,
    labware_position_id uuid,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    assigned_by uuid,
    volume numeric,
    volume_unit text,
    released_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

ALTER TABLE ONLY lims.sample_labware_assignments FORCE ROW LEVEL SECURITY;


--
-- Name: sample_statuses; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.sample_statuses (
    status_code text NOT NULL,
    description text NOT NULL,
    is_terminal boolean DEFAULT false NOT NULL
);


--
-- Name: sample_types_lookup; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.sample_types_lookup (
    sample_type_code text NOT NULL,
    description text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: samples; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.samples (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    external_id text,
    name text NOT NULL,
    sample_type text NOT NULL,
    project_code text,
    parent_id uuid,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sample_status text DEFAULT 'available'::text,
    sample_type_code text,
    collected_at timestamp with time zone,
    collected_by uuid,
    condition_notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    current_labware_id uuid,
    project_id uuid NOT NULL
);

ALTER TABLE ONLY lims.samples FORCE ROW LEVEL SECURITY;


--
-- Name: storage_facilities; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.storage_facilities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    location text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

ALTER TABLE ONLY lims.storage_facilities FORCE ROW LEVEL SECURITY;


--
-- Name: storage_sublocations; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.storage_sublocations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    unit_id uuid,
    parent_sublocation_id uuid,
    name text NOT NULL,
    barcode text,
    capacity integer,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

ALTER TABLE ONLY lims.storage_sublocations FORCE ROW LEVEL SECURITY;


--
-- Name: storage_units; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.storage_units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    facility_id uuid,
    name text NOT NULL,
    storage_type text NOT NULL,
    temperature_setpoint numeric,
    humidity_setpoint numeric,
    barcode text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

ALTER TABLE ONLY lims.storage_units FORCE ROW LEVEL SECURITY;


--
-- Name: user_roles; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.user_roles (
    user_id uuid NOT NULL,
    role_name text NOT NULL,
    granted_by uuid,
    granted_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY lims.user_roles FORCE ROW LEVEL SECURITY;


--
-- Name: user_tokens; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.user_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_digest text NOT NULL,
    allowed_roles text[] DEFAULT ARRAY[]::text[] NOT NULL,
    token_hint text,
    expires_at timestamp with time zone,
    last_used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    revoked_at timestamp with time zone,
    revoked_by uuid,
    revoked_reason text,
    CONSTRAINT user_tokens_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT user_tokens_token_hint_check CHECK (((token_hint IS NULL) OR (char_length(token_hint) <= 12)))
);

ALTER TABLE ONLY lims.user_tokens FORCE ROW LEVEL SECURITY;


--
-- Name: users; Type: TABLE; Schema: lims; Owner: -
--

CREATE TABLE lims.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    external_id text,
    email public.citext NOT NULL,
    full_name text NOT NULL,
    default_role text,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_authenticated_at timestamp with time zone,
    is_service_account boolean DEFAULT false NOT NULL,
    CONSTRAINT users_metadata_check CHECK ((jsonb_typeof(metadata) = 'object'::text))
);

ALTER TABLE ONLY lims.users FORCE ROW LEVEL SECURITY;


--
-- Name: v_api_token_overview; Type: VIEW; Schema: lims; Owner: -
--

CREATE VIEW lims.v_api_token_overview AS
 SELECT u.id AS user_id,
    u.email,
    u.full_name,
    u.default_role,
    u.is_service_account,
    u.metadata,
    COALESCE(active_tokens.active_count, (0)::bigint) AS active_token_count,
    COALESCE(last_usage.last_used_at, NULL::timestamp with time zone) AS last_token_use
   FROM ((lims.users u
     LEFT JOIN ( SELECT user_tokens.user_id,
            count(*) AS active_count
           FROM lims.user_tokens
          WHERE (user_tokens.revoked_at IS NULL)
          GROUP BY user_tokens.user_id) active_tokens ON ((active_tokens.user_id = u.id)))
     LEFT JOIN ( SELECT user_tokens.user_id,
            max(user_tokens.last_used_at) AS last_used_at
           FROM lims.user_tokens
          GROUP BY user_tokens.user_id) last_usage ON ((last_usage.user_id = u.id)));


--
-- Name: v_audit_recent_activity; Type: VIEW; Schema: lims; Owner: -
--

CREATE VIEW lims.v_audit_recent_activity AS
 SELECT id,
    ts,
    actor_identity,
    actor_roles,
    action,
    table_name,
    row_pk,
    diff
   FROM lims.audit_log
  ORDER BY ts DESC
 LIMIT 200;


--
-- Name: v_inventory_status; Type: VIEW; Schema: lims; Owner: -
--

CREATE VIEW lims.v_inventory_status WITH (security_invoker='true') AS
 SELECT id,
    name,
    barcode,
    quantity,
    unit,
    minimum_quantity,
    (quantity <= COALESCE(minimum_quantity, ('-1'::integer)::numeric)) AS below_threshold,
    expires_at,
    storage_sublocation_id
   FROM lims.inventory_items ii;


--
-- Name: v_labware_contents; Type: VIEW; Schema: lims; Owner: -
--

CREATE VIEW lims.v_labware_contents WITH (security_invoker='true') AS
 SELECT lw.id AS labware_id,
    lw.barcode,
    lw.display_name,
    lw.status,
    pos.position_label,
    sla.sample_id,
    s.name AS sample_name,
    sla.volume,
    sla.volume_unit,
    lw.current_storage_sublocation_id
   FROM (((lims.labware lw
     LEFT JOIN lims.labware_positions pos ON ((pos.labware_id = lw.id)))
     LEFT JOIN lims.sample_labware_assignments sla ON (((sla.labware_id = lw.id) AND ((sla.labware_position_id = pos.id) OR (sla.labware_position_id IS NULL)))))
     LEFT JOIN lims.samples s ON ((s.id = sla.sample_id)));


--
-- Name: v_project_access_overview; Type: VIEW; Schema: lims; Owner: -
--

CREATE VIEW lims.v_project_access_overview WITH (security_invoker='true') AS
 SELECT p.id,
    p.project_code,
    p.name,
    p.description,
    COALESCE(membership.is_member, false) AS is_member,
        CASE
            WHEN lims.has_role('app_admin'::text) THEN 'admin'::text
            WHEN lims.has_role('app_operator'::text) THEN 'operator'::text
            WHEN COALESCE(membership.is_member, false) THEN 'project_membership'::text
            ELSE 'role_policy'::text
        END AS access_via,
    COALESCE(sample_stats.sample_count, (0)::bigint) AS sample_count,
    COALESCE(labware_stats.labware_count, (0)::bigint) AS active_labware_count
   FROM (((lims.projects p
     LEFT JOIN LATERAL ( SELECT true AS is_member
           FROM lims.project_members pm
          WHERE ((pm.project_id = p.id) AND (pm.user_id = lims.current_user_id()))
         LIMIT 1) membership ON (true))
     LEFT JOIN LATERAL ( SELECT count(DISTINCT s.id) AS sample_count
           FROM lims.samples s
          WHERE (s.project_id = p.id)) sample_stats ON (true))
     LEFT JOIN LATERAL ( SELECT count(DISTINCT lw.id) AS labware_count
           FROM lims.labware lw
          WHERE (EXISTS ( SELECT 1
                   FROM lims.samples s
                  WHERE ((s.project_id = p.id) AND ((s.current_labware_id = lw.id) OR (EXISTS ( SELECT 1
                           FROM lims.sample_labware_assignments sla
                          WHERE ((sla.sample_id = s.id) AND (sla.labware_id = lw.id) AND (sla.released_at IS NULL))))))))) labware_stats ON (true));


--
-- Name: v_sample_overview; Type: VIEW; Schema: lims; Owner: -
--

CREATE VIEW lims.v_sample_overview WITH (security_invoker='true') AS
 SELECT s.id,
    s.name,
    s.sample_type_code,
    s.sample_status,
    s.collected_at,
    s.project_id,
    p.project_code,
    p.name AS project_name,
    lab.barcode AS current_labware_barcode,
    loc_path.path_text AS storage_path,
    ( SELECT jsonb_agg(jsonb_build_object('child_sample_id', sd.child_sample_id, 'method', sd.method)) AS jsonb_agg
           FROM lims.sample_derivations sd
          WHERE (sd.parent_sample_id = s.id)) AS derivatives
   FROM (((lims.samples s
     JOIN lims.projects p ON ((p.id = s.project_id)))
     LEFT JOIN lims.labware lab ON ((lab.id = s.current_labware_id)))
     LEFT JOIN LATERAL ( SELECT string_agg(format('%s/%s/%s'::text, COALESCE(sf.name, ''::text), COALESCE(su.name, ''::text), COALESCE(ss.name, ''::text)), ' → '::text) AS path_text
           FROM ((lims.storage_sublocations ss
             LEFT JOIN lims.storage_units su ON ((su.id = ss.unit_id)))
             LEFT JOIN lims.storage_facilities sf ON ((sf.id = su.facility_id)))
          WHERE (ss.id = lab.current_storage_sublocation_id)) loc_path ON (true));


--
-- Name: v_storage_dashboard; Type: VIEW; Schema: lims; Owner: -
--

CREATE VIEW lims.v_storage_dashboard WITH (security_invoker='true') AS
 SELECT sf.name AS facility,
    su.name AS unit,
    su.storage_type,
    ss.name AS sublocation,
    count(DISTINCT lw.id) AS labware_count,
    count(DISTINCT sla.sample_id) AS sample_count
   FROM ((((lims.storage_sublocations ss
     LEFT JOIN lims.storage_units su ON ((su.id = ss.unit_id)))
     LEFT JOIN lims.storage_facilities sf ON ((sf.id = su.facility_id)))
     LEFT JOIN lims.labware lw ON ((lw.current_storage_sublocation_id = ss.id)))
     LEFT JOIN lims.sample_labware_assignments sla ON (((sla.labware_id = lw.id) AND (sla.released_at IS NULL))))
  GROUP BY sf.name, su.name, su.storage_type, ss.name;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(128) NOT NULL
);


--
-- Name: audit_log id; Type: DEFAULT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.audit_log ALTER COLUMN id SET DEFAULT nextval('lims.audit_log_id_seq'::regclass);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: custody_event_types custody_event_types_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.custody_event_types
    ADD CONSTRAINT custody_event_types_pkey PRIMARY KEY (event_type);


--
-- Name: custody_events custody_events_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.custody_events
    ADD CONSTRAINT custody_events_pkey PRIMARY KEY (id);


--
-- Name: inventory_items inventory_items_barcode_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.inventory_items
    ADD CONSTRAINT inventory_items_barcode_key UNIQUE (barcode);


--
-- Name: inventory_items inventory_items_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.inventory_items
    ADD CONSTRAINT inventory_items_pkey PRIMARY KEY (id);


--
-- Name: inventory_transaction_types inventory_transaction_types_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.inventory_transaction_types
    ADD CONSTRAINT inventory_transaction_types_pkey PRIMARY KEY (transaction_type);


--
-- Name: inventory_transactions inventory_transactions_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.inventory_transactions
    ADD CONSTRAINT inventory_transactions_pkey PRIMARY KEY (id);


--
-- Name: labware labware_barcode_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware
    ADD CONSTRAINT labware_barcode_key UNIQUE (barcode);


--
-- Name: labware_location_history labware_location_history_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware_location_history
    ADD CONSTRAINT labware_location_history_pkey PRIMARY KEY (id);


--
-- Name: labware labware_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware
    ADD CONSTRAINT labware_pkey PRIMARY KEY (id);


--
-- Name: labware_positions labware_positions_labware_id_position_label_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware_positions
    ADD CONSTRAINT labware_positions_labware_id_position_label_key UNIQUE (labware_id, position_label);


--
-- Name: labware_positions labware_positions_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware_positions
    ADD CONSTRAINT labware_positions_pkey PRIMARY KEY (id);


--
-- Name: labware_types labware_types_name_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware_types
    ADD CONSTRAINT labware_types_name_key UNIQUE (name);


--
-- Name: labware_types labware_types_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware_types
    ADD CONSTRAINT labware_types_pkey PRIMARY KEY (id);


--
-- Name: project_members project_members_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.project_members
    ADD CONSTRAINT project_members_pkey PRIMARY KEY (project_id, user_id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: projects projects_project_code_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.projects
    ADD CONSTRAINT projects_project_code_key UNIQUE (project_code);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (role_name);


--
-- Name: sample_derivations sample_derivations_parent_sample_id_child_sample_id_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_derivations
    ADD CONSTRAINT sample_derivations_parent_sample_id_child_sample_id_key UNIQUE (parent_sample_id, child_sample_id);


--
-- Name: sample_derivations sample_derivations_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_derivations
    ADD CONSTRAINT sample_derivations_pkey PRIMARY KEY (id);


--
-- Name: sample_labware_assignments sample_labware_assignments_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_labware_assignments
    ADD CONSTRAINT sample_labware_assignments_pkey PRIMARY KEY (id);


--
-- Name: sample_labware_assignments sample_labware_assignments_sample_id_labware_id_labware_pos_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_labware_assignments
    ADD CONSTRAINT sample_labware_assignments_sample_id_labware_id_labware_pos_key UNIQUE (sample_id, labware_id, labware_position_id);


--
-- Name: sample_statuses sample_statuses_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_statuses
    ADD CONSTRAINT sample_statuses_pkey PRIMARY KEY (status_code);


--
-- Name: sample_types_lookup sample_types_lookup_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_types_lookup
    ADD CONSTRAINT sample_types_lookup_pkey PRIMARY KEY (sample_type_code);


--
-- Name: samples samples_external_id_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.samples
    ADD CONSTRAINT samples_external_id_key UNIQUE (external_id);


--
-- Name: samples samples_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.samples
    ADD CONSTRAINT samples_pkey PRIMARY KEY (id);


--
-- Name: storage_facilities storage_facilities_name_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.storage_facilities
    ADD CONSTRAINT storage_facilities_name_key UNIQUE (name);


--
-- Name: storage_facilities storage_facilities_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.storage_facilities
    ADD CONSTRAINT storage_facilities_pkey PRIMARY KEY (id);


--
-- Name: storage_sublocations storage_sublocations_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.storage_sublocations
    ADD CONSTRAINT storage_sublocations_pkey PRIMARY KEY (id);


--
-- Name: storage_sublocations storage_sublocations_unit_id_name_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.storage_sublocations
    ADD CONSTRAINT storage_sublocations_unit_id_name_key UNIQUE (unit_id, name);


--
-- Name: storage_units storage_units_facility_id_name_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.storage_units
    ADD CONSTRAINT storage_units_facility_id_name_key UNIQUE (facility_id, name);


--
-- Name: storage_units storage_units_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.storage_units
    ADD CONSTRAINT storage_units_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_name);


--
-- Name: user_tokens user_tokens_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.user_tokens
    ADD CONSTRAINT user_tokens_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_external_id_key; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.users
    ADD CONSTRAINT users_external_id_key UNIQUE (external_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_user_tokens_active; Type: INDEX; Schema: lims; Owner: -
--

CREATE INDEX idx_user_tokens_active ON lims.user_tokens USING btree (user_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_user_tokens_user_digest; Type: INDEX; Schema: lims; Owner: -
--

CREATE INDEX idx_user_tokens_user_digest ON lims.user_tokens USING btree (user_id, token_digest);


--
-- Name: roles trg_audit_roles; Type: TRIGGER; Schema: lims; Owner: -
--

CREATE TRIGGER trg_audit_roles AFTER INSERT OR DELETE OR UPDATE ON lims.roles FOR EACH ROW EXECUTE FUNCTION lims.fn_audit();


--
-- Name: samples trg_audit_samples; Type: TRIGGER; Schema: lims; Owner: -
--

CREATE TRIGGER trg_audit_samples AFTER INSERT OR DELETE OR UPDATE ON lims.samples FOR EACH ROW EXECUTE FUNCTION lims.fn_audit();


--
-- Name: user_roles trg_audit_user_roles; Type: TRIGGER; Schema: lims; Owner: -
--

CREATE TRIGGER trg_audit_user_roles AFTER INSERT OR DELETE OR UPDATE ON lims.user_roles FOR EACH ROW EXECUTE FUNCTION lims.fn_audit();


--
-- Name: users trg_audit_users; Type: TRIGGER; Schema: lims; Owner: -
--

CREATE TRIGGER trg_audit_users AFTER INSERT OR DELETE OR UPDATE ON lims.users FOR EACH ROW EXECUTE FUNCTION lims.fn_audit();


--
-- Name: samples trg_samples_set_project; Type: TRIGGER; Schema: lims; Owner: -
--

CREATE TRIGGER trg_samples_set_project BEFORE INSERT OR UPDATE ON lims.samples FOR EACH ROW EXECUTE FUNCTION lims.fn_samples_set_project();


--
-- Name: inventory_items trg_touch_inventory_items; Type: TRIGGER; Schema: lims; Owner: -
--

CREATE TRIGGER trg_touch_inventory_items BEFORE UPDATE ON lims.inventory_items FOR EACH ROW EXECUTE FUNCTION lims.fn_touch_updated_at();


--
-- Name: labware trg_touch_labware; Type: TRIGGER; Schema: lims; Owner: -
--

CREATE TRIGGER trg_touch_labware BEFORE UPDATE ON lims.labware FOR EACH ROW EXECUTE FUNCTION lims.fn_touch_updated_at();


--
-- Name: samples trg_touch_samples; Type: TRIGGER; Schema: lims; Owner: -
--

CREATE TRIGGER trg_touch_samples BEFORE UPDATE ON lims.samples FOR EACH ROW EXECUTE FUNCTION lims.fn_touch_updated_at();


--
-- Name: users trg_touch_users; Type: TRIGGER; Schema: lims; Owner: -
--

CREATE TRIGGER trg_touch_users BEFORE UPDATE ON lims.users FOR EACH ROW EXECUTE FUNCTION lims.fn_touch_updated_at();


--
-- Name: custody_events custody_events_event_type_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.custody_events
    ADD CONSTRAINT custody_events_event_type_fkey FOREIGN KEY (event_type) REFERENCES lims.custody_event_types(event_type);


--
-- Name: custody_events custody_events_from_sublocation_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.custody_events
    ADD CONSTRAINT custody_events_from_sublocation_id_fkey FOREIGN KEY (from_sublocation_id) REFERENCES lims.storage_sublocations(id) ON DELETE SET NULL;


--
-- Name: custody_events custody_events_labware_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.custody_events
    ADD CONSTRAINT custody_events_labware_id_fkey FOREIGN KEY (labware_id) REFERENCES lims.labware(id) ON DELETE SET NULL;


--
-- Name: custody_events custody_events_performed_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.custody_events
    ADD CONSTRAINT custody_events_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES lims.users(id);


--
-- Name: custody_events custody_events_sample_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.custody_events
    ADD CONSTRAINT custody_events_sample_id_fkey FOREIGN KEY (sample_id) REFERENCES lims.samples(id) ON DELETE CASCADE;


--
-- Name: custody_events custody_events_to_sublocation_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.custody_events
    ADD CONSTRAINT custody_events_to_sublocation_id_fkey FOREIGN KEY (to_sublocation_id) REFERENCES lims.storage_sublocations(id) ON DELETE SET NULL;


--
-- Name: inventory_items inventory_items_created_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.inventory_items
    ADD CONSTRAINT inventory_items_created_by_fkey FOREIGN KEY (created_by) REFERENCES lims.users(id);


--
-- Name: inventory_items inventory_items_storage_sublocation_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.inventory_items
    ADD CONSTRAINT inventory_items_storage_sublocation_id_fkey FOREIGN KEY (storage_sublocation_id) REFERENCES lims.storage_sublocations(id);


--
-- Name: inventory_transactions inventory_transactions_inventory_item_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.inventory_transactions
    ADD CONSTRAINT inventory_transactions_inventory_item_id_fkey FOREIGN KEY (inventory_item_id) REFERENCES lims.inventory_items(id) ON DELETE CASCADE;


--
-- Name: inventory_transactions inventory_transactions_performed_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.inventory_transactions
    ADD CONSTRAINT inventory_transactions_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES lims.users(id);


--
-- Name: inventory_transactions inventory_transactions_transaction_type_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.inventory_transactions
    ADD CONSTRAINT inventory_transactions_transaction_type_fkey FOREIGN KEY (transaction_type) REFERENCES lims.inventory_transaction_types(transaction_type);


--
-- Name: labware labware_created_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware
    ADD CONSTRAINT labware_created_by_fkey FOREIGN KEY (created_by) REFERENCES lims.users(id);


--
-- Name: labware labware_current_storage_sublocation_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware
    ADD CONSTRAINT labware_current_storage_sublocation_id_fkey FOREIGN KEY (current_storage_sublocation_id) REFERENCES lims.storage_sublocations(id);


--
-- Name: labware labware_labware_type_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware
    ADD CONSTRAINT labware_labware_type_id_fkey FOREIGN KEY (labware_type_id) REFERENCES lims.labware_types(id) ON DELETE RESTRICT;


--
-- Name: labware_location_history labware_location_history_labware_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware_location_history
    ADD CONSTRAINT labware_location_history_labware_id_fkey FOREIGN KEY (labware_id) REFERENCES lims.labware(id) ON DELETE CASCADE;


--
-- Name: labware_location_history labware_location_history_moved_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware_location_history
    ADD CONSTRAINT labware_location_history_moved_by_fkey FOREIGN KEY (moved_by) REFERENCES lims.users(id);


--
-- Name: labware_location_history labware_location_history_storage_sublocation_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware_location_history
    ADD CONSTRAINT labware_location_history_storage_sublocation_id_fkey FOREIGN KEY (storage_sublocation_id) REFERENCES lims.storage_sublocations(id) ON DELETE SET NULL;


--
-- Name: labware_positions labware_positions_labware_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.labware_positions
    ADD CONSTRAINT labware_positions_labware_id_fkey FOREIGN KEY (labware_id) REFERENCES lims.labware(id) ON DELETE CASCADE;


--
-- Name: project_members project_members_added_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.project_members
    ADD CONSTRAINT project_members_added_by_fkey FOREIGN KEY (added_by) REFERENCES lims.users(id);


--
-- Name: project_members project_members_project_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.project_members
    ADD CONSTRAINT project_members_project_id_fkey FOREIGN KEY (project_id) REFERENCES lims.projects(id) ON DELETE CASCADE;


--
-- Name: project_members project_members_user_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.project_members
    ADD CONSTRAINT project_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES lims.users(id) ON DELETE CASCADE;


--
-- Name: projects projects_created_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.projects
    ADD CONSTRAINT projects_created_by_fkey FOREIGN KEY (created_by) REFERENCES lims.users(id);


--
-- Name: roles roles_created_by_fk; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.roles
    ADD CONSTRAINT roles_created_by_fk FOREIGN KEY (created_by) REFERENCES lims.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: sample_derivations sample_derivations_child_sample_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_derivations
    ADD CONSTRAINT sample_derivations_child_sample_id_fkey FOREIGN KEY (child_sample_id) REFERENCES lims.samples(id) ON DELETE CASCADE;


--
-- Name: sample_derivations sample_derivations_created_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_derivations
    ADD CONSTRAINT sample_derivations_created_by_fkey FOREIGN KEY (created_by) REFERENCES lims.users(id);


--
-- Name: sample_derivations sample_derivations_parent_sample_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_derivations
    ADD CONSTRAINT sample_derivations_parent_sample_id_fkey FOREIGN KEY (parent_sample_id) REFERENCES lims.samples(id) ON DELETE CASCADE;


--
-- Name: sample_labware_assignments sample_labware_assignments_assigned_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_labware_assignments
    ADD CONSTRAINT sample_labware_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES lims.users(id);


--
-- Name: sample_labware_assignments sample_labware_assignments_labware_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_labware_assignments
    ADD CONSTRAINT sample_labware_assignments_labware_id_fkey FOREIGN KEY (labware_id) REFERENCES lims.labware(id) ON DELETE CASCADE;


--
-- Name: sample_labware_assignments sample_labware_assignments_labware_position_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_labware_assignments
    ADD CONSTRAINT sample_labware_assignments_labware_position_id_fkey FOREIGN KEY (labware_position_id) REFERENCES lims.labware_positions(id) ON DELETE SET NULL;


--
-- Name: sample_labware_assignments sample_labware_assignments_sample_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.sample_labware_assignments
    ADD CONSTRAINT sample_labware_assignments_sample_id_fkey FOREIGN KEY (sample_id) REFERENCES lims.samples(id) ON DELETE CASCADE;


--
-- Name: samples samples_collected_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.samples
    ADD CONSTRAINT samples_collected_by_fkey FOREIGN KEY (collected_by) REFERENCES lims.users(id);


--
-- Name: samples samples_created_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.samples
    ADD CONSTRAINT samples_created_by_fkey FOREIGN KEY (created_by) REFERENCES lims.users(id);


--
-- Name: samples samples_current_labware_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.samples
    ADD CONSTRAINT samples_current_labware_id_fkey FOREIGN KEY (current_labware_id) REFERENCES lims.labware(id);


--
-- Name: samples samples_parent_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.samples
    ADD CONSTRAINT samples_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES lims.samples(id) ON DELETE SET NULL;


--
-- Name: samples samples_project_id_fk; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.samples
    ADD CONSTRAINT samples_project_id_fk FOREIGN KEY (project_id) REFERENCES lims.projects(id);


--
-- Name: samples samples_sample_status_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.samples
    ADD CONSTRAINT samples_sample_status_fkey FOREIGN KEY (sample_status) REFERENCES lims.sample_statuses(status_code);


--
-- Name: samples samples_sample_type_code_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.samples
    ADD CONSTRAINT samples_sample_type_code_fkey FOREIGN KEY (sample_type_code) REFERENCES lims.sample_types_lookup(sample_type_code);


--
-- Name: storage_sublocations storage_sublocations_parent_sublocation_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.storage_sublocations
    ADD CONSTRAINT storage_sublocations_parent_sublocation_id_fkey FOREIGN KEY (parent_sublocation_id) REFERENCES lims.storage_sublocations(id) ON DELETE CASCADE;


--
-- Name: storage_sublocations storage_sublocations_unit_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.storage_sublocations
    ADD CONSTRAINT storage_sublocations_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES lims.storage_units(id) ON DELETE CASCADE;


--
-- Name: storage_units storage_units_facility_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.storage_units
    ADD CONSTRAINT storage_units_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES lims.storage_facilities(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_granted_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.user_roles
    ADD CONSTRAINT user_roles_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES lims.users(id) ON DELETE SET NULL;


--
-- Name: user_roles user_roles_role_name_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.user_roles
    ADD CONSTRAINT user_roles_role_name_fkey FOREIGN KEY (role_name) REFERENCES lims.roles(role_name) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES lims.users(id) ON DELETE CASCADE;


--
-- Name: user_tokens user_tokens_created_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.user_tokens
    ADD CONSTRAINT user_tokens_created_by_fkey FOREIGN KEY (created_by) REFERENCES lims.users(id);


--
-- Name: user_tokens user_tokens_revoked_by_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.user_tokens
    ADD CONSTRAINT user_tokens_revoked_by_fkey FOREIGN KEY (revoked_by) REFERENCES lims.users(id);


--
-- Name: user_tokens user_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.user_tokens
    ADD CONSTRAINT user_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES lims.users(id) ON DELETE CASCADE;


--
-- Name: users users_default_role_fkey; Type: FK CONSTRAINT; Schema: lims; Owner: -
--

ALTER TABLE ONLY lims.users
    ADD CONSTRAINT users_default_role_fkey FOREIGN KEY (default_role) REFERENCES lims.roles(role_name);


--
-- Name: custody_events; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.custody_events ENABLE ROW LEVEL SECURITY;

--
-- Name: inventory_items; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.inventory_items ENABLE ROW LEVEL SECURITY;

--
-- Name: inventory_transactions; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.inventory_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: labware; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.labware ENABLE ROW LEVEL SECURITY;

--
-- Name: labware_location_history; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.labware_location_history ENABLE ROW LEVEL SECURITY;

--
-- Name: labware_positions; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.labware_positions ENABLE ROW LEVEL SECURITY;

--
-- Name: custody_events p_custody_events_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_custody_events_admin_all ON lims.custody_events TO app_admin USING (true) WITH CHECK (true);


--
-- Name: custody_events p_custody_events_operator_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_custody_events_operator_all ON lims.custody_events TO app_operator USING (true) WITH CHECK (true);


--
-- Name: custody_events p_custody_events_select_researcher; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_custody_events_select_researcher ON lims.custody_events FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR lims.can_access_sample(sample_id)));


--
-- Name: inventory_items p_inventory_items_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_inventory_items_admin_all ON lims.inventory_items TO app_admin USING (true) WITH CHECK (true);


--
-- Name: inventory_items p_inventory_items_operator_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_inventory_items_operator_all ON lims.inventory_items TO app_operator USING (true) WITH CHECK (true);


--
-- Name: inventory_items p_inventory_items_select_ops; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_inventory_items_select_ops ON lims.inventory_items FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text)));


--
-- Name: inventory_transactions p_inventory_transactions_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_inventory_transactions_admin_all ON lims.inventory_transactions TO app_admin USING (true) WITH CHECK (true);


--
-- Name: inventory_transactions p_inventory_transactions_operator_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_inventory_transactions_operator_all ON lims.inventory_transactions TO app_operator USING (true) WITH CHECK (true);


--
-- Name: inventory_transactions p_inventory_transactions_select_ops; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_inventory_transactions_select_ops ON lims.inventory_transactions FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text)));


--
-- Name: labware p_labware_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_labware_admin_all ON lims.labware TO app_admin USING (true) WITH CHECK (true);


--
-- Name: labware_location_history p_labware_location_history_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_labware_location_history_admin_all ON lims.labware_location_history TO app_admin USING (true) WITH CHECK (true);


--
-- Name: labware_location_history p_labware_location_history_operator_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_labware_location_history_operator_all ON lims.labware_location_history TO app_operator USING (true) WITH CHECK (true);


--
-- Name: labware_location_history p_labware_location_history_select_researcher; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_labware_location_history_select_researcher ON lims.labware_location_history FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR lims.can_access_labware(labware_id)));


--
-- Name: labware p_labware_operator_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_labware_operator_all ON lims.labware TO app_operator USING (true) WITH CHECK (true);


--
-- Name: labware_positions p_labware_positions_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_labware_positions_admin_all ON lims.labware_positions TO app_admin USING (true) WITH CHECK (true);


--
-- Name: labware_positions p_labware_positions_operator_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_labware_positions_operator_all ON lims.labware_positions TO app_operator USING (true) WITH CHECK (true);


--
-- Name: labware_positions p_labware_positions_select_researcher; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_labware_positions_select_researcher ON lims.labware_positions FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR lims.can_access_labware(labware_id)));


--
-- Name: labware p_labware_select_researcher; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_labware_select_researcher ON lims.labware FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR lims.can_access_labware(id)));


--
-- Name: project_members p_project_members_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_project_members_admin_all ON lims.project_members TO app_admin USING (true) WITH CHECK (true);


--
-- Name: project_members p_project_members_member_select; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_project_members_member_select ON lims.project_members FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR (user_id = lims.current_user_id())));


--
-- Name: project_members p_project_members_operator_select; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_project_members_operator_select ON lims.project_members FOR SELECT TO app_operator USING (true);


--
-- Name: projects p_projects_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_projects_admin_all ON lims.projects TO app_admin USING (true) WITH CHECK (true);


--
-- Name: projects p_projects_member_select; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_projects_member_select ON lims.projects FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR (EXISTS ( SELECT 1
   FROM lims.project_members pm
  WHERE ((pm.project_id = projects.id) AND (pm.user_id = lims.current_user_id()))))));


--
-- Name: projects p_projects_operator_manage; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_projects_operator_manage ON lims.projects FOR SELECT TO app_operator USING (true);


--
-- Name: roles p_roles_select_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_roles_select_all ON lims.roles FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR is_assignable));


--
-- Name: roles p_roles_write_admin; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_roles_write_admin ON lims.roles TO app_admin USING (true) WITH CHECK (true);


--
-- Name: sample_derivations p_sample_derivations_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_sample_derivations_admin_all ON lims.sample_derivations TO app_admin USING (true) WITH CHECK (true);


--
-- Name: sample_derivations p_sample_derivations_operator_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_sample_derivations_operator_all ON lims.sample_derivations TO app_operator USING (true) WITH CHECK (true);


--
-- Name: sample_derivations p_sample_derivations_select_researcher; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_sample_derivations_select_researcher ON lims.sample_derivations FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR lims.can_access_sample(parent_sample_id) OR lims.can_access_sample(child_sample_id)));


--
-- Name: sample_labware_assignments p_sample_labware_assign_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_sample_labware_assign_admin_all ON lims.sample_labware_assignments TO app_admin USING (true) WITH CHECK (true);


--
-- Name: sample_labware_assignments p_sample_labware_assign_operator_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_sample_labware_assign_operator_all ON lims.sample_labware_assignments TO app_operator USING (true) WITH CHECK (true);


--
-- Name: sample_labware_assignments p_sample_labware_assign_select_researcher; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_sample_labware_assign_select_researcher ON lims.sample_labware_assignments FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR lims.can_access_sample(sample_id)));


--
-- Name: samples p_samples_delete_admin; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_delete_admin ON lims.samples FOR DELETE TO app_admin USING (true);


--
-- Name: samples p_samples_delete_ops; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_delete_ops ON lims.samples FOR DELETE TO app_operator USING (lims.can_access_project(project_id));


--
-- Name: samples p_samples_insert_admin; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_insert_admin ON lims.samples FOR INSERT TO app_admin WITH CHECK (true);


--
-- Name: samples p_samples_insert_automation; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_insert_automation ON lims.samples FOR INSERT TO app_automation WITH CHECK (lims.can_access_project(project_id));


--
-- Name: samples p_samples_insert_ops; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_insert_ops ON lims.samples FOR INSERT TO app_operator WITH CHECK (lims.can_access_project(project_id));


--
-- Name: samples p_samples_select_admin; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_select_admin ON lims.samples FOR SELECT TO app_admin USING (true);


--
-- Name: samples p_samples_select_automation; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_select_automation ON lims.samples FOR SELECT TO app_automation USING (true);


--
-- Name: samples p_samples_select_operator; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_select_operator ON lims.samples FOR SELECT TO app_operator USING (true);


--
-- Name: samples p_samples_select_researcher; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_select_researcher ON lims.samples FOR SELECT TO app_researcher USING (lims.can_access_project(project_id));


--
-- Name: samples p_samples_update_admin; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_update_admin ON lims.samples FOR UPDATE TO app_admin USING (true) WITH CHECK (true);


--
-- Name: samples p_samples_update_automation; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_update_automation ON lims.samples FOR UPDATE TO app_automation USING (lims.can_access_project(project_id)) WITH CHECK (lims.can_access_project(project_id));


--
-- Name: samples p_samples_update_ops; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_samples_update_ops ON lims.samples FOR UPDATE TO app_operator USING (lims.can_access_project(project_id)) WITH CHECK (lims.can_access_project(project_id));


--
-- Name: storage_facilities p_storage_facilities_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_storage_facilities_admin_all ON lims.storage_facilities TO app_admin USING (true) WITH CHECK (true);


--
-- Name: storage_facilities p_storage_facilities_select_auth; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_storage_facilities_select_auth ON lims.storage_facilities FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR lims.can_access_storage_facility(id)));


--
-- Name: storage_sublocations p_storage_sublocations_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_storage_sublocations_admin_all ON lims.storage_sublocations TO app_admin USING (true) WITH CHECK (true);


--
-- Name: storage_sublocations p_storage_sublocations_select_auth; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_storage_sublocations_select_auth ON lims.storage_sublocations FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR lims.can_access_storage_sublocation(id)));


--
-- Name: storage_units p_storage_units_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_storage_units_admin_all ON lims.storage_units TO app_admin USING (true) WITH CHECK (true);


--
-- Name: storage_units p_storage_units_select_auth; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_storage_units_select_auth ON lims.storage_units FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR lims.has_role('app_operator'::text) OR lims.can_access_storage_unit(id)));


--
-- Name: user_roles p_user_roles_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_user_roles_admin_all ON lims.user_roles TO app_admin USING (true) WITH CHECK (true);


--
-- Name: user_roles p_user_roles_self_select; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_user_roles_self_select ON lims.user_roles FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR (lims.current_user_id() = user_id)));


--
-- Name: user_tokens p_user_tokens_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_user_tokens_admin_all ON lims.user_tokens TO app_admin USING (true) WITH CHECK (true);


--
-- Name: user_tokens p_user_tokens_owner_select; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_user_tokens_owner_select ON lims.user_tokens FOR SELECT TO app_auth USING ((user_id = lims.current_user_id()));


--
-- Name: users p_users_admin_all; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_users_admin_all ON lims.users TO app_admin USING (true) WITH CHECK (true);


--
-- Name: users p_users_operator_select; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_users_operator_select ON lims.users FOR SELECT TO app_operator USING (true);


--
-- Name: users p_users_self_access; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_users_self_access ON lims.users FOR SELECT TO app_auth USING ((lims.has_role('app_admin'::text) OR (lims.current_user_id() = id)));


--
-- Name: users p_users_self_update; Type: POLICY; Schema: lims; Owner: -
--

CREATE POLICY p_users_self_update ON lims.users FOR UPDATE TO app_auth USING ((lims.has_role('app_admin'::text) OR (lims.current_user_id() = id))) WITH CHECK ((lims.has_role('app_admin'::text) OR (lims.current_user_id() = id)));


--
-- Name: project_members; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.project_members ENABLE ROW LEVEL SECURITY;

--
-- Name: projects; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.projects ENABLE ROW LEVEL SECURITY;

--
-- Name: roles; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: sample_derivations; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.sample_derivations ENABLE ROW LEVEL SECURITY;

--
-- Name: sample_labware_assignments; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.sample_labware_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: samples; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.samples ENABLE ROW LEVEL SECURITY;

--
-- Name: storage_facilities; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.storage_facilities ENABLE ROW LEVEL SECURITY;

--
-- Name: storage_sublocations; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.storage_sublocations ENABLE ROW LEVEL SECURITY;

--
-- Name: storage_units; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.storage_units ENABLE ROW LEVEL SECURITY;

--
-- Name: user_roles; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.user_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: user_tokens; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.user_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: lims; Owner: -
--

ALTER TABLE lims.users ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20240513000000'),
    ('20240513001000'),
    ('20240513002000'),
    ('20240513003000'),
    ('20240513004000'),
    ('20240513005000'),
    ('20240520010000'),
    ('20240520011000'),
    ('20240520012000');
