-- migrate:up
CREATE TABLE app_security.audit_log (
  audit_id        bigserial PRIMARY KEY,
  txn_id          uuid NOT NULL REFERENCES app_security.transaction_contexts(txn_id) ON DELETE CASCADE,
  schema_name     text NOT NULL,
  table_name      text NOT NULL,
  operation       text NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  primary_key_data jsonb,
  row_before      jsonb,
  row_after       jsonb,
  actor_id        uuid,
  actor_identity  text,
  actor_roles     text[] NOT NULL DEFAULT ARRAY[]::text[],
  performed_at    timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX idx_audit_log_txn ON app_security.audit_log(txn_id);
CREATE INDEX idx_audit_log_table ON app_security.audit_log(schema_name, table_name);
CREATE INDEX idx_audit_log_actor ON app_security.audit_log(actor_id);

-------------------------------------------------------------------------------
-- Helper utilities
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_security.extract_primary_key(
  p_schema text,
  p_table text,
  p_row jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security
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

GRANT EXECUTE ON FUNCTION app_security.extract_primary_key(text, text, jsonb) TO app_auth;

CREATE OR REPLACE FUNCTION app_security.record_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_security, app_core
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

-------------------------------------------------------------------------------
-- Apply audit triggers to core tables
-------------------------------------------------------------------------------

CREATE TRIGGER trg_audit_app_core_roles
AFTER INSERT OR UPDATE OR DELETE ON app_core.roles
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_app_core_users
AFTER INSERT OR UPDATE OR DELETE ON app_core.users
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_app_core_user_roles
AFTER INSERT OR UPDATE OR DELETE ON app_core.user_roles
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_api_clients
AFTER INSERT OR UPDATE OR DELETE ON app_security.api_clients
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

CREATE TRIGGER trg_audit_api_tokens
AFTER INSERT OR UPDATE OR DELETE ON app_security.api_tokens
FOR EACH ROW
EXECUTE FUNCTION app_security.record_audit();

GRANT SELECT ON app_security.audit_log TO app_admin;

ALTER TABLE app_security.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_security.audit_log FORCE ROW LEVEL SECURITY;

CREATE POLICY audit_log_admin_read ON app_security.audit_log
  FOR SELECT
  USING (app_security.has_role('app_admin'));

-- migrate:down
DROP POLICY IF EXISTS audit_log_admin_read ON app_security.audit_log;
ALTER TABLE app_security.audit_log DISABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_audit_api_tokens ON app_security.api_tokens;
DROP TRIGGER IF EXISTS trg_audit_api_clients ON app_security.api_clients;
DROP TRIGGER IF EXISTS trg_audit_app_core_user_roles ON app_core.user_roles;
DROP TRIGGER IF EXISTS trg_audit_app_core_users ON app_core.users;
DROP TRIGGER IF EXISTS trg_audit_app_core_roles ON app_core.roles;

DROP FUNCTION IF EXISTS app_security.record_audit();
REVOKE EXECUTE ON FUNCTION app_security.extract_primary_key(text, text, jsonb) FROM app_auth;
DROP FUNCTION IF EXISTS app_security.extract_primary_key(text, text, jsonb);

REVOKE SELECT ON app_security.audit_log FROM app_admin;
DROP TABLE IF EXISTS app_security.audit_log;
