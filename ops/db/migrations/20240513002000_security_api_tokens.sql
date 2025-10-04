-- migrate:up

-------------------------------------------------------------------------------
-- API clients and token management
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lims.api_clients (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_identifier text UNIQUE NOT NULL,
  display_name   text NOT NULL,
  description    text,
  contact_email  citext,
  allowed_roles  text[] NOT NULL DEFAULT ARRAY[]::text[],
  metadata       jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at     timestamptz NOT NULL DEFAULT now(),
  created_by     uuid REFERENCES lims.users(id),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE TABLE IF NOT EXISTS lims.api_tokens (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  api_client_id  uuid NOT NULL REFERENCES lims.api_clients(id) ON DELETE CASCADE,
  token_digest   text NOT NULL,
  token_hint     text,
  expires_at     timestamptz,
  last_used_at   timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  created_by     uuid REFERENCES lims.users(id),
  metadata       jsonb NOT NULL DEFAULT '{}'::jsonb,
  revoked_at     timestamptz,
  revoked_by     uuid REFERENCES lims.users(id),
  revoked_reason text,
  CHECK (jsonb_typeof(metadata) = 'object'),
  CHECK (token_hint IS NULL OR char_length(token_hint) <= 12)
);

CREATE INDEX IF NOT EXISTS idx_api_tokens_client_digest
  ON lims.api_tokens (api_client_id, token_digest);

CREATE INDEX IF NOT EXISTS idx_api_tokens_active
  ON lims.api_tokens (api_client_id)
  WHERE revoked_at IS NULL;

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

CREATE TRIGGER trg_touch_api_clients
BEFORE UPDATE ON lims.api_clients
FOR EACH ROW
EXECUTE FUNCTION lims.fn_touch_updated_at();

CREATE OR REPLACE FUNCTION lims.create_api_token(
  p_api_client_id uuid,
  p_plain_token text,
  p_expires_at timestamptz DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
DECLARE
  token_hash text;
  token_hint text;
  new_id uuid;
BEGIN
  IF p_plain_token IS NULL OR length(p_plain_token) < 32 THEN
    RAISE EXCEPTION 'API token must be at least 32 characters long';
  END IF;

  IF jsonb_typeof(p_metadata) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'metadata must be a JSON object';
  END IF;

  token_hash := encode(digest(p_plain_token, 'sha256'), 'hex');
  token_hint := right(p_plain_token, 6);

  INSERT INTO lims.api_tokens (
    api_client_id,
    token_digest,
    token_hint,
    expires_at,
    created_by,
    metadata
  )
  VALUES (
    p_api_client_id,
    token_hash,
    token_hint,
    p_expires_at,
    lims.current_user_id(),
    COALESCE(p_metadata, '{}'::jsonb)
  )
  RETURNING id INTO new_id;

  RETURN new_id;
END;
$$;

ALTER FUNCTION lims.create_api_token(uuid, text, timestamptz, jsonb) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION lims.create_api_token(uuid, text, timestamptz, jsonb) TO app_admin;

-------------------------------------------------------------------------------
-- Reporting views
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW lims.v_audit_recent_activity AS
SELECT
  id,
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

CREATE OR REPLACE VIEW lims.v_api_client_overview AS
SELECT
  c.id,
  c.client_identifier,
  c.display_name,
  c.allowed_roles,
  c.created_at,
  c.created_by,
  COALESCE(active_tokens.active_count, 0) AS active_token_count,
  COALESCE(last_usage.last_used_at, NULL) AS last_token_use,
  c.metadata
FROM lims.api_clients c
LEFT JOIN (
  SELECT api_client_id, count(*) AS active_count
  FROM lims.api_tokens
  WHERE revoked_at IS NULL
  GROUP BY api_client_id
) active_tokens ON active_tokens.api_client_id = c.id
LEFT JOIN (
  SELECT api_client_id, max(last_used_at) AS last_used_at
  FROM lims.api_tokens
  GROUP BY api_client_id
) last_usage ON last_usage.api_client_id = c.id;

-------------------------------------------------------------------------------
-- Row level security
-------------------------------------------------------------------------------

ALTER TABLE lims.api_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.api_clients FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.api_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.api_tokens FORCE ROW LEVEL SECURITY;

CREATE POLICY p_api_clients_admin_all
ON lims.api_clients
FOR ALL
TO app_admin
USING (TRUE)
WITH CHECK (TRUE);

CREATE POLICY p_api_clients_read_ops
ON lims.api_clients
FOR SELECT
TO app_operator
USING (TRUE);

CREATE POLICY p_api_tokens_admin_all
ON lims.api_tokens
FOR ALL
TO app_admin
USING (TRUE)
WITH CHECK (TRUE);

-------------------------------------------------------------------------------
-- Grants
-------------------------------------------------------------------------------

GRANT SELECT ON lims.v_audit_recent_activity TO app_admin, app_operator;
GRANT SELECT ON lims.v_api_client_overview TO app_admin, app_operator;

REVOKE ALL ON lims.api_clients FROM app_auth;
REVOKE ALL ON lims.api_tokens FROM app_auth;
REVOKE ALL ON lims.api_clients FROM app_operator;
REVOKE ALL ON lims.api_tokens FROM app_operator;
GRANT SELECT ON lims.api_clients TO app_operator;
GRANT SELECT, INSERT, UPDATE, DELETE ON lims.api_clients TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON lims.api_tokens TO app_admin;

-------------------------------------------------------------------------------
-- Seed data
-------------------------------------------------------------------------------

INSERT INTO lims.api_clients (client_identifier, display_name, description, contact_email, allowed_roles, created_by)
SELECT client_identifier, display_name, description, contact_email, allowed_roles, created_by
FROM (
  SELECT
    'automation-orchestrator'::text AS client_identifier,
    'Automation Orchestrator'::text AS display_name,
    'Service account for automated instrument ingestion.'::text AS description,
    'automation@example.org'::citext AS contact_email,
    ARRAY['app_automation']::text[] AS allowed_roles,
    (SELECT id FROM lims.users WHERE email = 'admin@example.org') AS created_by
) seed
ON CONFLICT (client_identifier) DO UPDATE
SET display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    contact_email = EXCLUDED.contact_email,
    allowed_roles = EXCLUDED.allowed_roles;

-------------------------------------------------------------------------------
-- migrate:down
-------------------------------------------------------------------------------

DROP VIEW IF EXISTS lims.v_api_client_overview;
DROP VIEW IF EXISTS lims.v_audit_recent_activity;

DROP FUNCTION IF EXISTS lims.create_api_token(uuid, text, timestamptz, jsonb);
DROP TRIGGER IF EXISTS trg_touch_api_clients ON lims.api_clients;

DROP TABLE IF EXISTS lims.api_tokens;
DROP TABLE IF EXISTS lims.api_clients;
