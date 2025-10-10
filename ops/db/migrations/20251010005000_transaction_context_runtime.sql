-- migrate:up
CREATE OR REPLACE FUNCTION app_security.pre_request()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
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

CREATE OR REPLACE FUNCTION app_security.start_transaction_context(
  p_actor_id uuid DEFAULT NULL,
  p_actor_identity text DEFAULT NULL,
  p_effective_roles text[] DEFAULT NULL,
  p_impersonated_roles text[] DEFAULT NULL,
  p_client_app text DEFAULT NULL,
  p_client_ip inet DEFAULT NULL,
  p_jwt_claims jsonb DEFAULT NULL,
  p_metadata jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
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

CREATE OR REPLACE FUNCTION app_security.require_transaction_context()
RETURNS text
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

CREATE OR REPLACE FUNCTION app_security.finish_transaction_context(
  p_txn_id uuid DEFAULT NULL,
  p_status text DEFAULT 'committed',
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
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

CREATE OR REPLACE FUNCTION app_security.mark_transaction_committed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security
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

DROP TRIGGER IF EXISTS trg_mark_transaction_committed ON app_security.transaction_contexts;

CREATE CONSTRAINT TRIGGER trg_mark_transaction_committed
AFTER INSERT ON app_security.transaction_contexts
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION app_security.mark_transaction_committed();

-- migrate:down
DROP TRIGGER IF EXISTS trg_mark_transaction_committed ON app_security.transaction_contexts;
DROP FUNCTION IF EXISTS app_security.mark_transaction_committed();

CREATE OR REPLACE FUNCTION app_security.finish_transaction_context(
  p_txn_id uuid DEFAULT NULL,
  p_status text DEFAULT 'committed',
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
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

CREATE OR REPLACE FUNCTION app_security.require_transaction_context()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_txn text := current_setting('app.txn_id', true);
BEGIN
  IF v_txn IS NULL OR v_txn = '' THEN
    RAISE EXCEPTION 'app.txn_id is not set; start_transaction_context() must be called before writing'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN v_txn;
END;
$$;

CREATE OR REPLACE FUNCTION app_security.start_transaction_context(
  p_actor_id uuid DEFAULT NULL,
  p_actor_identity text DEFAULT NULL,
  p_effective_roles text[] DEFAULT NULL,
  p_impersonated_roles text[] DEFAULT NULL,
  p_client_app text DEFAULT NULL,
  p_client_ip inet DEFAULT NULL,
  p_jwt_claims jsonb DEFAULT NULL,
  p_metadata jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  v_txn_id uuid := gen_random_uuid();
  v_claims jsonb;
  v_actor uuid;
  v_identity text;
  v_roles text[];
  v_impersonated text[];
BEGIN
  v_claims := coalesce(p_jwt_claims, app_security.current_claims());
  v_actor := coalesce(p_actor_id, app_security.current_actor_id());
  v_identity := coalesce(p_actor_identity, current_setting('app.actor_identity', true));
  v_roles := app_security.coerce_roles(coalesce(p_effective_roles, app_security.current_roles()));
  v_impersonated := app_security.coerce_roles(p_impersonated_roles);

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
    p_client_app,
    p_client_ip,
    coalesce(p_metadata, '{}'::jsonb)
  );

  PERFORM set_config('app.txn_id', v_txn_id::text, true);
  PERFORM set_config('app.actor_id', COALESCE(v_actor::text, ''), true);
  PERFORM set_config('app.actor_identity', coalesce(v_identity, ''), true);
  PERFORM set_config('app.roles', array_to_string(v_roles, ','), true);
  PERFORM set_config('app.impersonated_roles', array_to_string(v_impersonated, ','), true);
  PERFORM set_config('app.jwt_claims', coalesce(v_claims, '{}'::jsonb)::text, true);

  RETURN v_txn_id;
END;
$$;

CREATE OR REPLACE FUNCTION app_security.pre_request()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
AS $$
DECLARE
  claims jsonb := app_security.current_claims();
  actor uuid;
  roles text[];
  actor_identifier text;
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
END;
$$;
