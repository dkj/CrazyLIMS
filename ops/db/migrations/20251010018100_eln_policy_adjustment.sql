-- migrate:up
ALTER TABLE app_eln.notebook_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notebook_entries_select ON app_eln.notebook_entries;

CREATE POLICY notebook_entries_select ON app_eln.notebook_entries
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_eln.can_access_entry(entry_id)
    OR app_security.actor_has_scope(primary_scope_id)
  );

-- migrate:down
DROP POLICY IF EXISTS notebook_entries_select ON app_eln.notebook_entries;

CREATE POLICY notebook_entries_select ON app_eln.notebook_entries
  FOR SELECT
  USING (
    app_security.has_role('app_admin')
    OR app_eln.can_access_entry(entry_id)
  );
