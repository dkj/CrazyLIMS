-- migrate:up
GRANT SELECT ON app_core.v_handover_overview TO app_auth;

-- migrate:down
REVOKE SELECT ON app_core.v_handover_overview FROM app_auth;
