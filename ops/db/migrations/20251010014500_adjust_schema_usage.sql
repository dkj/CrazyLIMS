-- migrate:up
GRANT USAGE ON SCHEMA app_security TO web_anon;
GRANT USAGE ON SCHEMA app_provenance TO web_anon;

-- migrate:down
REVOKE USAGE ON SCHEMA app_provenance FROM web_anon;
REVOKE USAGE ON SCHEMA app_security FROM web_anon;
