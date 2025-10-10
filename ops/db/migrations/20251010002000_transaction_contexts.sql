-- migrate:up
CREATE TABLE app_security.transaction_contexts (
  txn_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id           uuid REFERENCES app_core.users(id),
  actor_identity     text,
  actor_roles        text[] NOT NULL DEFAULT ARRAY[]::text[],
  impersonated_roles text[] NOT NULL DEFAULT ARRAY[]::text[],
  jwt_claims         jsonb NOT NULL DEFAULT '{}'::jsonb,
  client_app         text,
  client_ip          inet,
  metadata           jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at         timestamptz NOT NULL DEFAULT clock_timestamp(),
  finished_at        timestamptz,
  finished_status    text,
  finished_reason    text,
  finished_by        uuid REFERENCES app_core.users(id),
  CHECK (jsonb_typeof(jwt_claims) = 'object'),
  CHECK (jsonb_typeof(metadata) = 'object'),
  CHECK (finished_status IS NULL OR finished_status IN ('committed','rolled_back','cancelled'))
);

CREATE INDEX idx_transaction_contexts_actor_id ON app_security.transaction_contexts(actor_id);
CREATE INDEX idx_transaction_contexts_started_at ON app_security.transaction_contexts(started_at);
CREATE INDEX idx_transaction_contexts_finished_at ON app_security.transaction_contexts(finished_at);

GRANT SELECT ON app_security.transaction_contexts TO app_admin;

-------------------------------------------------------------------------------
-- Helper utilities for transaction metadata
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_security.coerce_roles(p_roles text[])
RETURNS text[]
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

GRANT EXECUTE ON FUNCTION app_security.coerce_roles(text[]) TO app_auth;

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

GRANT EXECUTE ON FUNCTION app_security.start_transaction_context(uuid, text, text[], text[], text, inet, jsonb, jsonb) TO app_admin, app_operator, postgrest_authenticator, postgraphile_authenticator;

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

GRANT EXECUTE ON FUNCTION app_security.finish_transaction_context(uuid, text, text) TO app_admin, app_operator, postgrest_authenticator, postgraphile_authenticator;

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

GRANT EXECUTE ON FUNCTION app_security.require_transaction_context() TO app_auth;

-- migrate:down
REVOKE EXECUTE ON FUNCTION app_security.require_transaction_context() FROM app_auth;
DROP FUNCTION IF EXISTS app_security.require_transaction_context();

REVOKE EXECUTE ON FUNCTION app_security.finish_transaction_context(uuid, text, text) FROM app_admin, app_operator, postgrest_authenticator, postgraphile_authenticator;
DROP FUNCTION IF EXISTS app_security.finish_transaction_context(uuid, text, text);

REVOKE EXECUTE ON FUNCTION app_security.start_transaction_context(uuid, text, text[], text[], text, inet, jsonb, jsonb) FROM app_admin, app_operator, postgrest_authenticator, postgraphile_authenticator;
DROP FUNCTION IF EXISTS app_security.start_transaction_context(uuid, text, text[], text[], text, inet, jsonb, jsonb);

REVOKE EXECUTE ON FUNCTION app_security.coerce_roles(text[]) FROM app_auth;
DROP FUNCTION IF EXISTS app_security.coerce_roles(text[]);

REVOKE SELECT ON app_security.transaction_contexts FROM app_admin;
DROP TABLE IF EXISTS app_security.transaction_contexts;
