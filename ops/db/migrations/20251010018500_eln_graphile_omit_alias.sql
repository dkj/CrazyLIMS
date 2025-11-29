-- migrate:up
COMMENT ON VIEW app_core.v_notebook_entry_overview IS
  E'@omit';

-- migrate:down
COMMENT ON VIEW app_core.v_notebook_entry_overview IS NULL;
