-- migrate:up

-- Support service accounts directly in lims.users
ALTER TABLE lims.users
  ADD COLUMN IF NOT EXISTS is_service_account boolean NOT NULL DEFAULT false;

-- Table to store API tokens bound to users
CREATE TABLE IF NOT EXISTS lims.user_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES lims.users(id) ON DELETE CASCADE,
  token_digest text NOT NULL,
  allowed_roles text[] NOT NULL DEFAULT ARRAY[]::text[],
  token_hint text,
  expires_at timestamptz,
  last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES lims.users(id),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  revoked_at timestamptz,
  revoked_by uuid REFERENCES lims.users(id),
  revoked_reason text,
  CHECK (jsonb_typeof(metadata) = 'object'),
  CHECK (token_hint IS NULL OR char_length(token_hint) <= 12)
);

CREATE INDEX IF NOT EXISTS idx_user_tokens_user_digest
  ON lims.user_tokens (user_id, token_digest);

CREATE INDEX IF NOT EXISTS idx_user_tokens_active
  ON lims.user_tokens (user_id)
  WHERE revoked_at IS NULL;

-- Migrate existing API clients into service-account users
DO $$
DECLARE
  admin_id uuid := (SELECT id FROM lims.users WHERE email = 'admin@example.org');
  client_record RECORD;
  inserted_user_id uuid;
BEGIN
  FOR client_record IN SELECT * FROM lims.api_clients LOOP
    -- Determine or create user backing this client
    inserted_user_id := (
      SELECT id
      FROM lims.users
      WHERE external_id = concat('urn:lims:service:', client_record.client_identifier)
      OR email = COALESCE(client_record.contact_email::text, concat(client_record.client_identifier, '@service.local'))
      LIMIT 1
    );

    IF inserted_user_id IS NULL THEN
      INSERT INTO lims.users (
        external_id,
        email,
        full_name,
        default_role,
        is_active,
        metadata,
        is_service_account
      )
      VALUES (
        concat('urn:lims:service:', client_record.client_identifier),
        COALESCE(client_record.contact_email::text, concat(client_record.client_identifier, '@service.local')),
        client_record.display_name,
        COALESCE(client_record.allowed_roles[1], 'app_automation'),
        true,
        jsonb_build_object('origin', 'api_clients', 'api_client_id', client_record.id),
        true
      )
      RETURNING id INTO inserted_user_id;
    ELSE
      UPDATE lims.users
      SET
        full_name = COALESCE(full_name, client_record.display_name),
        default_role = COALESCE(default_role, client_record.allowed_roles[1], 'app_automation'),
        is_service_account = true
      WHERE id = inserted_user_id;
    END IF;

    -- Ensure service account has the allowed roles as user_roles for convenience
    IF client_record.allowed_roles IS NOT NULL THEN
      INSERT INTO lims.user_roles(user_id, role_name, granted_by)
      SELECT inserted_user_id, role_name, admin_id
      FROM UNNEST(client_record.allowed_roles) AS role_name
      ON CONFLICT (user_id, role_name) DO NOTHING;
    END IF;

    -- Migrate tokens for this client
    INSERT INTO lims.user_tokens (
      user_id,
      token_digest,
      token_hint,
      allowed_roles,
      expires_at,
      last_used_at,
      created_at,
      created_by,
      metadata,
      revoked_at,
      revoked_by,
      revoked_reason
    )
    SELECT
      inserted_user_id,
      t.token_digest,
      t.token_hint,
      client_record.allowed_roles,
      t.expires_at,
      t.last_used_at,
      t.created_at,
      t.created_by,
      t.metadata,
      t.revoked_at,
      t.revoked_by,
      t.revoked_reason
    FROM lims.api_tokens t
    WHERE t.api_client_id = client_record.id;
  END LOOP;
END;
$$;

-- Replace token creation function to operate on users
DROP FUNCTION IF EXISTS lims.create_api_token(uuid, text, timestamptz, jsonb);

CREATE OR REPLACE FUNCTION lims.create_api_token(
  p_user_id uuid,
  p_plain_token text,
  p_allowed_roles text[] DEFAULT NULL,
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

GRANT EXECUTE ON FUNCTION lims.create_api_token(uuid, text, text[], timestamptz, jsonb) TO app_admin;

-- Views & reporting updated to user-centric tokens
CREATE OR REPLACE VIEW lims.v_api_token_overview AS
SELECT
  u.id AS user_id,
  u.email,
  u.full_name,
  u.default_role,
  u.is_service_account,
  u.metadata,
  COALESCE(active_tokens.active_count, 0) AS active_token_count,
  COALESCE(last_usage.last_used_at, NULL) AS last_token_use
FROM lims.users u
LEFT JOIN (
  SELECT user_id, count(*) AS active_count
  FROM lims.user_tokens
  WHERE revoked_at IS NULL
  GROUP BY user_id
) active_tokens ON active_tokens.user_id = u.id
LEFT JOIN (
  SELECT user_id, max(last_used_at) AS last_used_at
  FROM lims.user_tokens
  GROUP BY user_id
) last_usage ON last_usage.user_id = u.id;

-- RLS for user_tokens
ALTER TABLE lims.user_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.user_tokens FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_user_tokens_admin_all ON lims.user_tokens;
CREATE POLICY p_user_tokens_admin_all
ON lims.user_tokens
FOR ALL
TO app_admin
USING (TRUE)
WITH CHECK (TRUE);

CREATE POLICY p_user_tokens_owner_select
ON lims.user_tokens
FOR SELECT
TO app_auth
USING (user_id = lims.current_user_id());

-- Permissions
GRANT SELECT ON lims.v_api_token_overview TO app_admin, app_operator;
REVOKE ALL ON lims.user_tokens FROM app_auth;
GRANT SELECT ON lims.user_tokens TO app_auth;
GRANT SELECT, INSERT, UPDATE, DELETE ON lims.user_tokens TO app_admin;

-- Drop legacy structures
DROP VIEW IF EXISTS lims.v_api_client_overview;
DROP TABLE IF EXISTS lims.api_tokens;
DROP TABLE IF EXISTS lims.api_clients;

-- migrate:down

DROP VIEW IF EXISTS lims.v_api_token_overview;
DROP FUNCTION IF EXISTS lims.create_api_token(uuid, text, text[], timestamptz, jsonb);
DROP TABLE IF EXISTS lims.user_tokens;
ALTER TABLE lims.users DROP COLUMN IF EXISTS is_service_account;
-- legacy tables/functions intentionally not recreated in down migration.
