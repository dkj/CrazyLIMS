-- migrate:up
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'web_anon') THEN
    CREATE ROLE web_anon NOLOGIN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_auth') THEN
    CREATE ROLE app_auth NOLOGIN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_admin') THEN
    CREATE ROLE app_admin NOLOGIN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_operator') THEN
    CREATE ROLE app_operator NOLOGIN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_researcher') THEN
    CREATE ROLE app_researcher NOLOGIN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_external') THEN
    CREATE ROLE app_external NOLOGIN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_automation') THEN
    CREATE ROLE app_automation NOLOGIN;
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

-- Establish the hierarchy for authenticated roles.
GRANT app_auth TO app_admin;
GRANT app_auth TO app_operator;
GRANT app_auth TO app_researcher;
GRANT app_auth TO app_external;
GRANT app_auth TO app_automation;

-- Allow authenticators to assume application roles based on JWT claims.
GRANT web_anon TO postgrest_authenticator;
GRANT app_auth TO postgrest_authenticator;
GRANT app_admin TO postgrest_authenticator;
GRANT app_operator TO postgrest_authenticator;
GRANT app_researcher TO postgrest_authenticator;
GRANT app_external TO postgrest_authenticator;
GRANT app_automation TO postgrest_authenticator;

GRANT web_anon TO postgraphile_authenticator;
GRANT app_auth TO postgraphile_authenticator;
GRANT app_admin TO postgraphile_authenticator;
GRANT app_operator TO postgraphile_authenticator;
GRANT app_researcher TO postgraphile_authenticator;
GRANT app_external TO postgraphile_authenticator;
GRANT app_automation TO postgraphile_authenticator;

-- Developer role inherits administrator privileges for local workflows.
GRANT web_anon TO dev;
GRANT app_auth TO dev;
GRANT app_admin TO dev;
GRANT app_operator TO dev;
GRANT app_researcher TO dev;
GRANT app_external TO dev;
GRANT app_automation TO dev;

-- migrate:down
REVOKE app_automation FROM dev;
REVOKE app_external FROM dev;
REVOKE app_researcher FROM dev;
REVOKE app_operator FROM dev;
REVOKE app_admin FROM dev;
REVOKE app_auth FROM dev;
REVOKE web_anon FROM dev;

REVOKE app_automation FROM postgraphile_authenticator;
REVOKE app_external FROM postgraphile_authenticator;
REVOKE app_researcher FROM postgraphile_authenticator;
REVOKE app_operator FROM postgraphile_authenticator;
REVOKE app_admin FROM postgraphile_authenticator;
REVOKE app_auth FROM postgraphile_authenticator;
REVOKE web_anon FROM postgraphile_authenticator;

REVOKE app_automation FROM postgrest_authenticator;
REVOKE app_external FROM postgrest_authenticator;
REVOKE app_researcher FROM postgrest_authenticator;
REVOKE app_operator FROM postgrest_authenticator;
REVOKE app_admin FROM postgrest_authenticator;
REVOKE app_auth FROM postgrest_authenticator;
REVOKE web_anon FROM postgrest_authenticator;

REVOKE app_auth FROM app_automation;
REVOKE app_auth FROM app_external;
REVOKE app_auth FROM app_researcher;
REVOKE app_auth FROM app_operator;
REVOKE app_auth FROM app_admin;

DROP ROLE IF EXISTS dev;
DROP ROLE IF EXISTS postgraphile_authenticator;
DROP ROLE IF EXISTS postgrest_authenticator;
DROP ROLE IF EXISTS app_automation;
DROP ROLE IF EXISTS app_external;
DROP ROLE IF EXISTS app_researcher;
DROP ROLE IF EXISTS app_operator;
DROP ROLE IF EXISTS app_admin;
DROP ROLE IF EXISTS app_auth;
DROP ROLE IF EXISTS web_anon;
