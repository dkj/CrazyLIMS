-- migrate:up
CREATE OR REPLACE VIEW app_core.v_transaction_context_activity AS
SELECT * FROM app_security.v_transaction_context_activity;

CREATE OR REPLACE VIEW app_core.v_audit_recent_activity AS
SELECT * FROM app_security.v_audit_recent_activity;

GRANT SELECT ON app_core.v_transaction_context_activity TO app_admin;
GRANT SELECT ON app_core.v_audit_recent_activity TO app_admin;
GRANT SELECT ON app_core.v_transaction_context_activity TO postgrest_authenticator;
GRANT SELECT ON app_core.v_audit_recent_activity TO postgrest_authenticator;

-- migrate:down
REVOKE SELECT ON app_core.v_audit_recent_activity FROM postgrest_authenticator;
REVOKE SELECT ON app_core.v_transaction_context_activity FROM postgrest_authenticator;
REVOKE SELECT ON app_core.v_audit_recent_activity FROM app_admin;
REVOKE SELECT ON app_core.v_transaction_context_activity FROM app_admin;

DROP VIEW IF EXISTS app_core.v_audit_recent_activity;
DROP VIEW IF EXISTS app_core.v_transaction_context_activity;
