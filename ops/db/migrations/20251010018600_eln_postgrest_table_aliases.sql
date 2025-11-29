-- migrate:up
CREATE OR REPLACE VIEW app_core.notebook_entries AS
SELECT * FROM app_eln.notebook_entries;

CREATE OR REPLACE VIEW app_core.notebook_entry_versions AS
SELECT * FROM app_eln.notebook_entry_versions;

COMMENT ON VIEW app_core.notebook_entries IS '@omit';
COMMENT ON VIEW app_core.notebook_entry_versions IS '@omit';

GRANT SELECT ON app_core.notebook_entries TO app_auth;
GRANT INSERT, UPDATE ON app_core.notebook_entries TO app_admin, app_operator, app_researcher;
GRANT DELETE ON app_core.notebook_entries TO app_admin;

GRANT SELECT ON app_core.notebook_entry_versions TO app_auth;
GRANT INSERT ON app_core.notebook_entry_versions TO app_admin, app_operator, app_researcher;
GRANT DELETE ON app_core.notebook_entry_versions TO app_admin;

-- migrate:down
REVOKE DELETE ON app_core.notebook_entry_versions FROM app_admin;
REVOKE INSERT ON app_core.notebook_entry_versions FROM app_admin, app_operator, app_researcher;
REVOKE SELECT ON app_core.notebook_entry_versions FROM app_auth;

REVOKE DELETE ON app_core.notebook_entries FROM app_admin;
REVOKE INSERT, UPDATE ON app_core.notebook_entries FROM app_admin, app_operator, app_researcher;
REVOKE SELECT ON app_core.notebook_entries FROM app_auth;

DROP VIEW IF EXISTS app_core.notebook_entry_versions;
DROP VIEW IF EXISTS app_core.notebook_entries;
