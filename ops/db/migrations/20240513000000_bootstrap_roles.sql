-- migrate:up
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'web_anon') THEN
    CREATE ROLE web_anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_auth') THEN
    CREATE ROLE app_auth NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgrest_authenticator') THEN
    CREATE ROLE postgrest_authenticator NOINHERIT LOGIN PASSWORD 'postgrestpass';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgraphile_authenticator') THEN
    CREATE ROLE postgraphile_authenticator NOINHERIT LOGIN PASSWORD 'postgraphilepass';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dev') THEN
    CREATE ROLE dev LOGIN PASSWORD 'devpass';
  END IF;
END $$;

GRANT web_anon TO postgrest_authenticator;
GRANT app_auth TO postgrest_authenticator;
GRANT web_anon TO postgraphile_authenticator;
GRANT app_auth TO postgraphile_authenticator;
GRANT web_anon TO dev;
GRANT app_auth TO dev;

-- migrate:down
REVOKE app_auth FROM dev;
REVOKE web_anon FROM dev;
REVOKE app_auth FROM postgraphile_authenticator;
REVOKE web_anon FROM postgraphile_authenticator;
REVOKE app_auth FROM postgrest_authenticator;
REVOKE web_anon FROM postgrest_authenticator;
DROP ROLE IF EXISTS dev;
DROP ROLE IF EXISTS postgraphile_authenticator;
DROP ROLE IF EXISTS postgrest_authenticator;
DROP ROLE IF EXISTS app_auth;
DROP ROLE IF EXISTS web_anon;
