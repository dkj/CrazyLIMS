-- migrate:up
CREATE OR REPLACE VIEW app_security.v_transaction_context_activity AS
SELECT
  date_trunc('hour', started_at) AS started_hour,
  coalesce(client_app, 'unknown') AS client_app,
  coalesce(finished_status, 'pending') AS finished_status,
  count(*) AS context_count,
  count(*) FILTER (WHERE finished_status IS NULL) AS open_contexts
FROM app_security.transaction_contexts
GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW app_security.v_audit_recent_activity AS
SELECT
  audit_id,
  performed_at,
  schema_name,
  table_name,
  operation,
  txn_id,
  actor_id,
  actor_identity,
  actor_roles
FROM app_security.audit_log
ORDER BY performed_at DESC
LIMIT 200;

GRANT SELECT ON app_security.v_transaction_context_activity TO app_admin;
GRANT SELECT ON app_security.v_audit_recent_activity TO app_admin;

-- migrate:down
REVOKE SELECT ON app_security.v_audit_recent_activity FROM app_admin;
REVOKE SELECT ON app_security.v_transaction_context_activity FROM app_admin;
DROP VIEW IF EXISTS app_security.v_audit_recent_activity;
DROP VIEW IF EXISTS app_security.v_transaction_context_activity;
