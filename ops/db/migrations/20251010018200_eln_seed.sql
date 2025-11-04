-- migrate:up
DO $$
DECLARE
  v_admin uuid;
  v_scope uuid;
  v_entry uuid;
  v_txn uuid;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  SELECT scope_id INTO v_scope FROM app_security.scopes WHERE scope_key = 'dataset:pilot_plasma';

  IF v_admin IS NULL OR v_scope IS NULL THEN
    RAISE NOTICE 'Skipping ELN seed – required fixtures missing';
    RETURN;
  END IF;

  v_txn := app_security.start_transaction_context(
    p_actor_id => v_admin,
    p_actor_identity => 'seed:eln',
    p_effective_roles => ARRAY['app_admin'],
    p_client_app => 'dbmate:migration',
    p_metadata => jsonb_build_object('seed','eln-demo')
  );

  INSERT INTO app_eln.notebook_entries (
    entry_key,
    title,
    description,
    primary_scope_id,
    metadata,
    created_by
  )
  VALUES (
    'eln:pilot_plasma:baseline',
    'Pilot Plasma Day 1 Notebook',
    'Demonstration notebook entry seeded for the ELN workflow',
    v_scope,
    jsonb_build_object('seed','eln-demo'),
    v_admin
  )
  ON CONFLICT (entry_key) DO UPDATE
    SET title = EXCLUDED.title,
        description = EXCLUDED.description,
        primary_scope_id = EXCLUDED.primary_scope_id,
        metadata = app_eln.notebook_entries.metadata || jsonb_build_object('seed','eln-demo')
  RETURNING entry_id INTO v_entry;

  IF v_entry IS NULL THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM app_eln.notebook_entry_versions WHERE entry_id = v_entry
  ) THEN
    INSERT INTO app_eln.notebook_entry_versions (
      entry_id,
      note,
      notebook_json,
      metadata,
      created_by
    )
    VALUES (
      v_entry,
      'Initial seeded notebook',
      jsonb_build_object(
        'cells', jsonb_build_array(
          jsonb_build_object(
            'cell_type','markdown',
            'metadata','{}'::jsonb,
            'source', jsonb_build_array(
              '# Pilot Plasma Run',
              '',
              'Seeded ELN entry demonstrating notebook capture.',
              '',
              '* Project scope: Genomics Pilot',
              '* Dataset scope: Pilot Plasma'
            )
          ),
          jsonb_build_object(
            'cell_type','code',
            'metadata','{}'::jsonb,
            'execution_count', NULL,
            'source', jsonb_build_array(
              'import math',
              'samples = 8',
              'yield_ratio = 0.85',
              'print(f"Processed {samples} samples at {yield_ratio*100:.1f}% yield")'
            ),
            'outputs', jsonb_build_array()
          )
        ),
        'metadata', jsonb_build_object(
          'kernelspec', jsonb_build_object(
            'display_name','Python 3 (Pyodide)',
            'language','python',
            'name','python3'
          ),
          'language_info', jsonb_build_object(
            'name','python',
            'version','3.11'
          ),
          'crazylims', jsonb_build_object(
            'seed','eln-demo',
            'project_scope','project:genomics_pilot'
          )
        ),
        'nbformat', 4,
        'nbformat_minor', 5
      ),
      jsonb_build_object('seed','eln-demo'),
      v_admin
    );
  END IF;

  PERFORM app_security.finish_transaction_context(v_txn, 'committed', 'eln seed');
END;
$$;

-- migrate:down
DO $$
BEGIN
  DELETE FROM app_eln.notebook_entry_versions
  WHERE metadata ->> 'seed' = 'eln-demo';

  DELETE FROM app_eln.notebook_entry_scopes
  WHERE entry_id IN (
    SELECT entry_id
    FROM app_eln.notebook_entries
    WHERE metadata ->> 'seed' = 'eln-demo'
  );

  DELETE FROM app_eln.notebook_entries
  WHERE metadata ->> 'seed' = 'eln-demo';
END;
$$;
