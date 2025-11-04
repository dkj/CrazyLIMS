-------------------------------------------------------------------------------
-- Notebook entry lifecycle and access control
-------------------------------------------------------------------------------

SET ROLE app_researcher;

DO $$
DECLARE
  v_actor uuid;
  v_scope uuid;
  v_entry uuid;
  v_version integer;
  v_checksum text;
  v_submitted_at timestamptz;
  v_submitted_by uuid;
BEGIN
  EXECUTE format('SET app.roles = %L', 'app_admin');
  SELECT id INTO v_actor FROM app_core.users WHERE email = 'alice@example.org';
  EXECUTE format('SET app.roles = %L', 'app_researcher');
  PERFORM pg_temp.isnt_null(v_actor, 'Researcher Alice fixture present');

  SELECT scope_id INTO v_scope
  FROM app_security.scopes
  WHERE scope_key = 'dataset:pilot_plasma';
  PERFORM pg_temp.isnt_null(v_scope, 'Dataset pilot_plasma scope present');

  EXECUTE format('SET app.actor_id = %L', v_actor::text);
  EXECUTE format('SET app.actor_identity = %L', 'alice@example.org');
  EXECUTE format('SET app.roles = %L', 'app_researcher');

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
      FROM app_security.actor_accessible_scopes(ARRAY['dataset'])
      WHERE scope_id = v_scope
        AND role_name = 'app_researcher'
    ),
    'Accessible scopes helper surfaces dataset membership'
  );

  PERFORM pg_temp.ok(
    app_security.actor_has_scope(
      v_scope,
      ARRAY['app_researcher','app_operator','app_admin']
    ),
    'Actor resolves dataset scope for notebook insert'
  );

  PERFORM app_security.require_transaction_context();

  INSERT INTO app_eln.notebook_entries (title, description, primary_scope_id)
  VALUES ('Research Notes – QC Run', 'Automated regression entry', v_scope)
  RETURNING entry_id INTO v_entry;

  PERFORM pg_temp.isnt_null(v_entry, 'Notebook entry inserted');

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
      FROM app_eln.notebook_entry_scopes s
      WHERE s.entry_id = v_entry
        AND s.scope_id = v_scope
        AND s.relationship = 'primary'
    ),
    'Primary scope automatically assigned to notebook entry'
  );

  INSERT INTO app_eln.notebook_entry_versions (entry_id, note, notebook_json)
  VALUES (
    v_entry,
    'Draft v1',
    jsonb_build_object(
      'cells', jsonb_build_array(
        jsonb_build_object(
          'cell_type','markdown',
          'metadata','{}'::jsonb,
          'source', jsonb_build_array('## Observations', 'Run captured in automated regression test.')
        )
      ),
      'metadata', jsonb_build_object(
        'kernelspec', jsonb_build_object('name','python3')
      ),
      'nbformat', 4,
      'nbformat_minor', 5
    )
  )
  RETURNING version_number, checksum INTO v_version, v_checksum;

  PERFORM pg_temp.is(v_version, 1, 'First notebook version auto-numbered to 1');
  PERFORM pg_temp.isnt_null(v_checksum, 'Notebook checksum populated');

  INSERT INTO app_eln.notebook_entry_versions (entry_id, note, notebook_json)
  VALUES (
    v_entry,
    'Draft v2',
    jsonb_build_object(
      'cells', jsonb_build_array(
        jsonb_build_object(
          'cell_type','code',
          'metadata','{}'::jsonb,
          'execution_count', NULL,
          'source', jsonb_build_array('print("hello from regression")'),
          'outputs', jsonb_build_array()
        )
      ),
      'metadata', jsonb_build_object(
        'kernelspec', jsonb_build_object('name','python3')
      ),
      'nbformat', 4,
      'nbformat_minor', 5
    )
  )
  RETURNING version_number INTO v_version;

  PERFORM pg_temp.is(v_version, 2, 'Second notebook version auto-numbered to 2');

  UPDATE app_eln.notebook_entries
  SET status = 'submitted'
  WHERE entry_id = v_entry
  RETURNING submitted_at, submitted_by
  INTO v_submitted_at, v_submitted_by;

  PERFORM pg_temp.isnt_null(v_submitted_at, 'Submission timestamp populated');
  PERFORM pg_temp.is(v_submitted_by, v_actor, 'Submission attributed to researcher persona');

  BEGIN
    INSERT INTO app_eln.notebook_entry_versions (entry_id, note, notebook_json)
    VALUES (
      v_entry,
      'Draft after submission',
      jsonb_build_object('cells', jsonb_build_array(), 'metadata','{}'::jsonb, 'nbformat',4, 'nbformat_minor',5)
    );
    PERFORM pg_temp.fail('Unexpectedly inserted notebook version after submission');
  EXCEPTION
    WHEN others THEN
      PERFORM pg_temp.ok(SQLSTATE IN ('55000','42501'), 'Prevented version insert once submitted');
  END;

  BEGIN
    UPDATE app_eln.notebook_entries
    SET description = 'Mutated after submission'
    WHERE entry_id = v_entry;
    PERFORM pg_temp.fail('Unexpectedly mutated submitted notebook entry');
  EXCEPTION
    WHEN others THEN
      PERFORM pg_temp.ok(SQLSTATE IN ('55000','42501'), 'Blocked mutation on submitted entry without status change');
  END;

  BEGIN
    UPDATE app_eln.notebook_entries
    SET status = 'draft'
    WHERE entry_id = v_entry;
    PERFORM pg_temp.fail('Researcher reverted submission without admin role');
  EXCEPTION
    WHEN others THEN
      PERFORM pg_temp.ok(SQLSTATE IN ('42501','55000'), 'Researcher prevented from reverting submission');
  END;

  EXECUTE format('SET app.roles = %L', 'app_admin');
  PERFORM app_security.require_transaction_context();

  UPDATE app_eln.notebook_entries
  SET status = 'draft'
  WHERE entry_id = v_entry;

  PERFORM pg_temp.is(
    (SELECT status FROM app_eln.notebook_entries WHERE entry_id = v_entry),
    'draft',
    'Administrator reverted notebook to draft'
  );

  PERFORM pg_temp.is(
    (SELECT submitted_at IS NULL FROM app_eln.notebook_entries WHERE entry_id = v_entry),
    true,
    'Submission timestamp cleared when reverting to draft'
  );

  UPDATE app_eln.notebook_entries
  SET status = 'submitted'
  WHERE entry_id = v_entry;

  UPDATE app_eln.notebook_entries
  SET status = 'locked'
  WHERE entry_id = v_entry;

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
      FROM app_eln.notebook_entries
      WHERE entry_id = v_entry
        AND status = 'locked'
        AND locked_at IS NOT NULL
        AND locked_by IS NOT NULL
    ),
    'Lock transition recorded lock metadata'
  );

  BEGIN
    UPDATE app_eln.notebook_entries
    SET description = 'Should remain locked'
    WHERE entry_id = v_entry;
    PERFORM pg_temp.fail('Unexpectedly mutated locked entry');
  EXCEPTION
    WHEN others THEN
      PERFORM pg_temp.ok(SQLSTATE IN ('55000','42501'), 'Locked entry remained immutable');
  END;

  EXECUTE format('SET app.roles = %L', 'app_researcher');

  PERFORM set_config('session.eln_entry_id', v_entry::text, false);
END;
$$;

RESET ROLE;

-------------------------------------------------------------------------------
-- Researcher without scope cannot access the notebook
-------------------------------------------------------------------------------

SET ROLE app_researcher;

DO $$
DECLARE
  v_entry uuid := NULLIF(current_setting('session.eln_entry_id', true), '')::uuid;
  v_actor uuid;
  v_count integer;
BEGIN
  PERFORM pg_temp.isnt_null(v_entry, 'Notebook entry id carried across test session');

  EXECUTE format('SET app.roles = %L', 'app_admin');
  SELECT id INTO v_actor FROM app_core.users WHERE email = 'bob@example.org';
  EXECUTE format('SET app.roles = %L', 'app_researcher');
  PERFORM pg_temp.isnt_null(v_actor, 'Researcher Bob fixture present');

  EXECUTE format('SET app.actor_id = %L', v_actor::text);
  EXECUTE format('SET app.actor_identity = %L', 'bob@example.org');
  EXECUTE format('SET app.roles = %L', 'app_researcher');

  SELECT count(*)
    INTO v_count
    FROM app_eln.notebook_entries
   WHERE entry_id = v_entry;

  PERFORM pg_temp.is(v_count, 0, 'Researcher without scope cannot view notebook entry');
END;
$$;

RESET ROLE;
