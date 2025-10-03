CREATE ROLE web_anon NOLOGIN;
CREATE ROLE app_auth NOLOGIN;

-- Service accounts for API surfacing layers (authenticator roles only set other roles)
CREATE ROLE postgrest_authenticator NOINHERIT LOGIN PASSWORD 'postgrestpass';
CREATE ROLE postgraphile_authenticator NOINHERIT LOGIN PASSWORD 'postgraphilepass';

-- Developer convenience role for Phase0 tinkering
CREATE ROLE dev LOGIN PASSWORD 'devpass';

GRANT web_anon TO postgrest_authenticator;
GRANT app_auth TO postgrest_authenticator;
GRANT web_anon TO postgraphile_authenticator;
GRANT app_auth TO postgraphile_authenticator;

-- Ensure dev can manage schema during Phase0
GRANT web_anon TO dev;
GRANT app_auth TO dev;
