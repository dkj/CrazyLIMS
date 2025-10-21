-- migrate:up
DO $$
DECLARE
  seed_tag constant text := 'security-redux-story';
  v_admin uuid;
  v_scope_alpha uuid;
  v_scope_beta uuid;
  v_ops_lab_scope uuid;
  v_ops_lib_scope uuid;
  v_ops_quant_scope uuid;
  v_ops_pool_scope uuid;
  v_ops_run_scope uuid;
  v_roberto uuid;
  v_phillipa uuid;
  v_ross uuid;
  v_eric uuid;
  v_lucy uuid;
  v_fred uuid;
  v_instrument uuid;
  v_plate uuid;
  v_id uuid;
  v_parent uuid;
  v_child uuid;
  row_idx int;
  col_idx int;
  idx int;
  well text;
  row_char text;
  donor_idx int;
  plate_idx int;
  user_rec record;
  alpha_donor_ids uuid[] := ARRAY[]::uuid[];
  beta_donor_ids uuid[] := ARRAY[]::uuid[];
  alpha_well_labels text[] := ARRAY[]::text[];
  alpha_p202_ids uuid[] := ARRAY[]::uuid[];
  alpha_d203_ids uuid[] := ARRAY[]::uuid[];
  alpha_l204_ids uuid[] := ARRAY[]::uuid[];
  ops_l204_ids uuid[] := ARRAY[]::uuid[];
  n203_ids uuid[] := ARRAY[]::uuid[];
  n401_ids uuid[] := ARRAY[]::uuid[];
  n402_ids uuid[] := ARRAY[]::uuid[];
  n403_ids uuid[] := ARRAY[]::uuid[];
  pool_inputs uuid[] := ARRAY[]::uuid[];
  data_product_ids uuid[] := ARRAY[]::uuid[];
  row_labels text[] := ARRAY['A','B','C','D','E','F','G','H'];
  ops_row_labels text[] := ARRAY['A','B','C','D','E','F'];
  alpha_donor_names text[] := ARRAY[
    'Alpha Virtual Donor 101','Alpha Virtual Donor 102','Alpha Virtual Donor 103','Alpha Virtual Donor 104',
    'Alpha Virtual Donor 105','Alpha Virtual Donor 106','Alpha Virtual Donor 107','Alpha Virtual Donor 108',
    'Alpha Virtual Donor 109','Alpha Virtual Donor 110','Alpha Virtual Donor 111','Alpha Virtual Donor 112'
  ];
  beta_donor_names text[] := ARRAY[
    'Beta Virtual Donor 201','Beta Virtual Donor 202','Beta Virtual Donor 203','Beta Virtual Donor 204',
    'Beta Virtual Donor 205','Beta Virtual Donor 206','Beta Virtual Donor 207','Beta Virtual Donor 208'
  ];
  ops_plate_labels text[] := ARRAY['L401','L402','L403'];
  ops_norm_labels text[] := ARRAY['N401','N402','N403'];
  v_type_plate uuid;
  v_type_sample uuid;
  v_type_library uuid;
  v_type_pool uuid;
  v_type_data uuid;
  v_pool uuid;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  IF v_admin IS NULL THEN
    RAISE NOTICE 'Admin user missing; skipping story data seed';
    RETURN;
  END IF;

  PERFORM set_config('app.actor_id', v_admin::text, true);
  PERFORM set_config('app.actor_identity', 'admin@example.org', true);
  PERFORM set_config('app.roles', 'app_admin', true);

  IF EXISTS (
    SELECT 1 FROM app_provenance.artefacts WHERE metadata ->> 'seed' = seed_tag
  ) THEN
    RAISE NOTICE 'Security redux story data already present';
    RETURN;
  END IF;

  SELECT scope_id INTO v_scope_alpha FROM app_security.scopes WHERE scope_key = 'project:alpha-study';
  SELECT scope_id INTO v_scope_beta FROM app_security.scopes WHERE scope_key = 'project:beta-study';

  IF v_scope_alpha IS NULL THEN
    INSERT INTO app_security.scopes(scope_key, scope_type, display_name, metadata, created_by)
    VALUES ('project:alpha-study', 'project', 'Project Alpha', jsonb_build_object('seed', seed_tag), v_admin)
    RETURNING scope_id INTO v_scope_alpha;
  END IF;

  IF v_scope_beta IS NULL THEN
    INSERT INTO app_security.scopes(scope_key, scope_type, display_name, metadata, created_by)
    VALUES ('project:beta-study', 'project', 'Project Beta', jsonb_build_object('seed', seed_tag), v_admin)
    RETURNING scope_id INTO v_scope_beta;
  END IF;

  SELECT scope_id INTO v_ops_lab_scope FROM app_security.scopes WHERE scope_key = 'facility:ops-lab';
  IF v_ops_lab_scope IS NULL THEN
    INSERT INTO app_security.scopes(scope_key, scope_type, display_name, metadata, created_by)
    VALUES ('facility:ops-lab', 'facility', 'Ops Lab', jsonb_build_object('seed', seed_tag), v_admin)
    RETURNING scope_id INTO v_ops_lab_scope;
  END IF;

  -- Ops child scopes beneath Alpha
  INSERT INTO app_security.scopes(scope_key, scope_type, display_name, parent_scope_id, metadata, created_by)
  VALUES
    ('ops:alpha-lib', 'ops', 'Alpha Ops Library Intake', v_ops_lab_scope, jsonb_build_object('seed', seed_tag), v_admin),
    ('ops:alpha-quant', 'ops', 'Alpha Ops Quant Normalisation', v_ops_lab_scope, jsonb_build_object('seed', seed_tag), v_admin),
    ('ops:alpha-pool', 'ops', 'Alpha Ops Pooling', v_ops_lab_scope, jsonb_build_object('seed', seed_tag), v_admin),
    ('ops:alpha-run', 'ops', 'Alpha Ops Sequencing Run', v_ops_lab_scope, jsonb_build_object('seed', seed_tag), v_admin)
  ON CONFLICT (scope_key) DO NOTHING;

  SELECT scope_id INTO v_ops_lib_scope FROM app_security.scopes WHERE scope_key = 'ops:alpha-lib';
  SELECT scope_id INTO v_ops_quant_scope FROM app_security.scopes WHERE scope_key = 'ops:alpha-quant';
  SELECT scope_id INTO v_ops_pool_scope FROM app_security.scopes WHERE scope_key = 'ops:alpha-pool';
  SELECT scope_id INTO v_ops_run_scope FROM app_security.scopes WHERE scope_key = 'ops:alpha-run';

  -- Ensure support users
  FOR user_rec IN (
    SELECT * FROM (
      VALUES
        ('roberto@example.org','Roberto Alvarez','app_researcher',false,'Alpha researcher – virtual intake'),
        ('phillipa@example.org','Phillipa Chen','app_researcher',false,'Alpha researcher – lab lead'),
        ('ross@example.org','Ross Imari','app_researcher',false,'Alpha lab technologist'),
        ('eric@example.org','Eric Mallory','app_researcher',false,'Beta project coordinator'),
        ('lucy@example.org','Lucy Fairlie','app_operator',false,'Ops librarian'),
        ('fred@example.org','Fred Kemp','app_operator',false,'Ops normalisation tech'),
        ('instrument-alpha@example.org','Alpha Sequencer','app_automation',true,'Sequencer instrument account')
    ) AS u(email, full_name, default_role, is_service_account, persona)
  ) LOOP
    SELECT id INTO v_id FROM app_core.users WHERE email = user_rec.email;
    IF v_id IS NULL THEN
      INSERT INTO app_core.users (external_id, email, full_name, default_role, is_service_account, metadata)
      VALUES (
        'urn:story:' || replace(user_rec.email, '@', ':'),
        user_rec.email,
        user_rec.full_name,
        user_rec.default_role,
        user_rec.is_service_account,
        jsonb_build_object('seed', seed_tag, 'story_persona', user_rec.persona)
      )
      RETURNING id INTO v_id;
    ELSE
      UPDATE app_core.users
      SET full_name = user_rec.full_name,
          default_role = user_rec.default_role,
          is_service_account = user_rec.is_service_account,
          metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('seed', seed_tag, 'story_persona', user_rec.persona)
      WHERE id = v_id;
    END IF;

    IF user_rec.email = 'roberto@example.org' THEN
      v_roberto := v_id;
    ELSIF user_rec.email = 'phillipa@example.org' THEN
      v_phillipa := v_id;
    ELSIF user_rec.email = 'ross@example.org' THEN
      v_ross := v_id;
    ELSIF user_rec.email = 'eric@example.org' THEN
      v_eric := v_id;
    ELSIF user_rec.email = 'lucy@example.org' THEN
      v_lucy := v_id;
    ELSIF user_rec.email = 'fred@example.org' THEN
      v_fred := v_id;
    ELSIF user_rec.email = 'instrument-alpha@example.org' THEN
      v_instrument := v_id;
    END IF;
  END LOOP;

  -- helper to grant membership with metadata
  WITH params AS (
    SELECT v_scope_alpha AS scope_id, v_roberto AS user_id, 'app_researcher'::text AS role_name, 'alpha virtual intake'::text AS note UNION ALL
    SELECT v_scope_alpha, v_phillipa, 'app_researcher', 'alpha plate builder' UNION ALL
    SELECT v_scope_alpha, v_ross, 'app_researcher', 'alpha lab technologist' UNION ALL
    SELECT v_scope_beta, v_eric, 'app_researcher', 'beta researcher' UNION ALL
    SELECT v_ops_lab_scope, v_lucy, 'app_operator', 'ops lab membership' UNION ALL
    SELECT v_ops_lib_scope, v_lucy, 'app_operator', 'ops library intake' UNION ALL
    SELECT v_ops_quant_scope, v_lucy, 'app_operator', 'ops quant normalisation' UNION ALL
    SELECT v_ops_lab_scope, v_fred, 'app_operator', 'ops lab membership' UNION ALL
    SELECT v_ops_pool_scope, v_fred, 'app_operator', 'ops pooling tech' UNION ALL
    SELECT v_ops_run_scope, v_fred, 'app_operator', 'ops sequencing tech' UNION ALL
    SELECT v_ops_run_scope, v_instrument, 'app_automation', 'sequencer instrument'
  )
  INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, metadata)
  SELECT scope_id, user_id, role_name, jsonb_build_object('seed', seed_tag, 'note', note)
  FROM params
  WHERE scope_id IS NOT NULL AND user_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM app_security.scope_memberships sm
      WHERE sm.scope_id = params.scope_id AND sm.user_id = params.user_id AND sm.role_name = params.role_name
    );

  -- artefact type ids
  SELECT artefact_type_id INTO v_type_plate FROM app_provenance.artefact_types WHERE type_key = 'container_plate_96';
  SELECT artefact_type_id INTO v_type_sample FROM app_provenance.artefact_types WHERE type_key = 'dna_extract';
  SELECT artefact_type_id INTO v_type_library FROM app_provenance.artefact_types WHERE type_key = 'library';
  SELECT artefact_type_id INTO v_type_pool FROM app_provenance.artefact_types WHERE type_key = 'pooled_library';
  SELECT artefact_type_id INTO v_type_data FROM app_provenance.artefact_types WHERE type_key = 'data_product_sequence';

  IF v_type_plate IS NULL OR v_type_sample IS NULL OR v_type_library IS NULL OR v_type_pool IS NULL OR v_type_data IS NULL THEN
    RAISE EXCEPTION 'Required artefact types missing';
  END IF;

  -- helper to tag artefacts with role metadata
  PERFORM 1;

  -- create alpha virtual donors
  FOR idx IN 1..array_length(alpha_donor_names,1) LOOP
    SELECT artefact_id INTO v_id
    FROM app_provenance.artefacts
    WHERE name = alpha_donor_names[idx];

    IF v_id IS NULL THEN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id, name, external_identifier, status, is_virtual, metadata, created_by
      )
      VALUES (
        v_type_sample,
        alpha_donor_names[idx],
        'alpha-virtual-donor-' || lpad(idx::text,3,'0'),
        'active',
        true,
        jsonb_build_object('seed', seed_tag, 'project', 'alpha', 'donor_index', idx),
        v_admin
      )
      RETURNING artefact_id INTO v_id;
    ELSE
      UPDATE app_provenance.artefacts
      SET metadata = coalesce(metadata,'{}') || jsonb_build_object('seed', seed_tag, 'project', 'alpha', 'donor_index', idx)
      WHERE artefact_id = v_id;
    END IF;

    alpha_donor_ids := array_append(alpha_donor_ids, v_id);

    IF v_scope_alpha IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
      SELECT v_id, v_scope_alpha, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'alpha donor manifest'), v_admin
      WHERE NOT EXISTS (
        SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_scope_alpha
      );
    END IF;
  END LOOP;

  -- create beta virtual donors
  FOR idx IN 1..array_length(beta_donor_names,1) LOOP
    SELECT artefact_id INTO v_id
    FROM app_provenance.artefacts
    WHERE name = beta_donor_names[idx];

    IF v_id IS NULL THEN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id, name, external_identifier, status, is_virtual, metadata, created_by
      )
      VALUES (
        v_type_sample,
        beta_donor_names[idx],
        'beta-virtual-donor-' || lpad(idx::text,3,'0'),
        'active',
        true,
        jsonb_build_object('seed', seed_tag, 'project', 'beta', 'donor_index', idx),
        v_admin
      )
      RETURNING artefact_id INTO v_id;
    ELSE
      UPDATE app_provenance.artefacts
      SET metadata = coalesce(metadata,'{}') || jsonb_build_object('seed', seed_tag, 'project', 'beta', 'donor_index', idx)
      WHERE artefact_id = v_id;
    END IF;

    beta_donor_ids := array_append(beta_donor_ids, v_id);

    IF v_scope_beta IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
      SELECT v_id, v_scope_beta, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'beta donor manifest'), v_admin
      WHERE NOT EXISTS (
        SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_scope_beta
      );
    END IF;
  END LOOP;

  -- Alpha plate P202
  SELECT artefact_id INTO v_plate
  FROM app_provenance.artefacts
  WHERE metadata ->> 'seed' = seed_tag AND metadata ->> 'plate' = 'P202';

  IF v_plate IS NULL THEN
    INSERT INTO app_provenance.artefacts (
      artefact_type_id, name, external_identifier, status, metadata, created_by
    )
    VALUES (
      v_type_plate,
      'Alpha Source Plate P202',
      'alpha-plate-p202',
      'active',
      jsonb_build_object('seed', seed_tag, 'barcode', 'P202', 'plate', 'P202', 'description', 'Alpha research intake plate'),
      v_admin
    )
    RETURNING artefact_id INTO v_plate;
  END IF;

  IF v_scope_alpha IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
    SELECT v_plate, v_scope_alpha, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'alpha plate P202'), v_admin
    WHERE NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_plate AND scope_id = v_scope_alpha
    );
  END IF;

  alpha_p202_ids := ARRAY[]::uuid[];
  alpha_well_labels := ARRAY[]::text[];
  idx := 0;
  FOR row_idx IN 1..array_length(row_labels,1) LOOP
    row_char := row_labels[row_idx];
    FOR col_idx IN 1..12 LOOP
      idx := idx + 1;
      well := row_char || lpad(col_idx::text, 2, '0');
      donor_idx := ((idx - 1) % array_length(alpha_donor_ids,1)) + 1;
      v_parent := alpha_donor_ids[donor_idx];
      SELECT artefact_id INTO v_id
      FROM app_provenance.artefacts
      WHERE metadata ->> 'seed' = seed_tag
        AND metadata ->> 'plate' = 'P202'
        AND metadata ->> 'well_position' = well;
      IF v_id IS NULL THEN
        INSERT INTO app_provenance.artefacts (
          artefact_type_id, name, external_identifier, status, container_artefact_id, metadata, created_by
        )
        VALUES (
          v_type_sample,
          'Alpha P202 ' || well,
          'alpha-p202-' || lower(well),
          'active',
          v_plate,
          jsonb_build_object('seed', seed_tag, 'plate', 'P202', 'well_position', well, 'donor_index', donor_idx),
          v_admin
        )
        RETURNING artefact_id INTO v_id;
      END IF;

      alpha_well_labels := array_append(alpha_well_labels, well);
      alpha_p202_ids := array_append(alpha_p202_ids, v_id);

      IF v_scope_alpha IS NOT NULL THEN
        INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
        SELECT v_id, v_scope_alpha, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'alpha P202 well'), v_admin
        WHERE NOT EXISTS (
          SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_scope_alpha
        );
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM app_provenance.artefact_relationships
        WHERE parent_artefact_id = v_parent AND child_artefact_id = v_id
      ) THEN
        INSERT INTO app_provenance.artefact_relationships (
          parent_artefact_id, child_artefact_id, relationship_type, metadata, created_by
        )
        VALUES (
          v_parent, v_id, 'virtual_source', jsonb_build_object('seed', seed_tag, 'plate', 'P202'), v_admin
        );
      END IF;
    END LOOP;
  END LOOP;

  -- Fragmented plate D203
  SELECT artefact_id INTO v_plate
  FROM app_provenance.artefacts
  WHERE metadata ->> 'seed' = seed_tag AND metadata ->> 'plate' = 'D203';
  IF v_plate IS NULL THEN
    INSERT INTO app_provenance.artefacts (
      artefact_type_id, name, external_identifier, status, metadata, created_by
    )
    VALUES (
      v_type_plate,
      'Alpha Fragment Plate D203',
      'alpha-plate-d203',
      'active',
      jsonb_build_object('seed', seed_tag, 'barcode', 'D203', 'plate', 'D203', 'description', 'Fragmented DNA plate'),
      v_admin
    )
    RETURNING artefact_id INTO v_plate;
  END IF;

  IF v_scope_alpha IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
    SELECT v_plate, v_scope_alpha, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'alpha D203 plate'), v_admin
    WHERE NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_plate AND scope_id = v_scope_alpha
    );
  END IF;

  alpha_d203_ids := ARRAY[]::uuid[];
  FOR idx IN 1..array_length(alpha_p202_ids,1) LOOP
    well := alpha_well_labels[idx];
    v_parent := alpha_p202_ids[idx];
    SELECT artefact_id INTO v_id
    FROM app_provenance.artefacts
    WHERE metadata ->> 'seed' = seed_tag
      AND metadata ->> 'plate' = 'D203'
      AND metadata ->> 'well_position' = well;
    IF v_id IS NULL THEN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id, name, external_identifier, status, container_artefact_id, metadata, created_by
      )
      VALUES (
        v_type_sample,
        'Alpha D203 ' || well,
        'alpha-d203-' || lower(well),
        'active',
        v_plate,
        jsonb_build_object('seed', seed_tag, 'plate', 'D203', 'well_position', well),
        v_admin
      )
      RETURNING artefact_id INTO v_id;
    END IF;

    alpha_d203_ids := array_append(alpha_d203_ids, v_id);

    IF v_scope_alpha IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
      SELECT v_id, v_scope_alpha, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'alpha D203 well'), v_admin
      WHERE NOT EXISTS (
        SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_scope_alpha
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_relationships
      WHERE parent_artefact_id = v_parent AND child_artefact_id = v_id
    ) THEN
      INSERT INTO app_provenance.artefact_relationships (
        parent_artefact_id, child_artefact_id, relationship_type, metadata, created_by
      )
      VALUES (
        v_parent, v_id, 'derived_from', jsonb_build_object('seed', seed_tag, 'step', 'fragmentation'), v_admin
      );
    END IF;
  END LOOP;

  -- Library plate L204
  SELECT artefact_id INTO v_plate
  FROM app_provenance.artefacts
  WHERE metadata ->> 'seed' = seed_tag AND metadata ->> 'plate' = 'L204';
  IF v_plate IS NULL THEN
    INSERT INTO app_provenance.artefacts (
      artefact_type_id, name, external_identifier, status, metadata, created_by
    )
    VALUES (
      v_type_plate,
      'Alpha Library Plate L204',
      'alpha-plate-l204',
      'active',
      jsonb_build_object('seed', seed_tag, 'barcode', 'L204', 'plate', 'L204', 'description', 'Indexed library plate'),
      v_admin
    )
    RETURNING artefact_id INTO v_plate;
  END IF;

  IF v_scope_alpha IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
    SELECT v_plate, v_scope_alpha, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'alpha L204 plate'), v_admin
    WHERE NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_plate AND scope_id = v_scope_alpha
    );
  END IF;

  alpha_l204_ids := ARRAY[]::uuid[];
  FOR idx IN 1..array_length(alpha_d203_ids,1) LOOP
    well := alpha_well_labels[idx];
    v_parent := alpha_d203_ids[idx];
    SELECT artefact_id INTO v_id
    FROM app_provenance.artefacts
    WHERE metadata ->> 'seed' = seed_tag
      AND metadata ->> 'plate' = 'L204'
      AND metadata ->> 'well_position' = well;
    IF v_id IS NULL THEN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id, name, external_identifier, status, container_artefact_id, metadata, created_by
      )
      VALUES (
        v_type_library,
        'Alpha Library L204 ' || well,
        'alpha-l204-' || lower(well),
        'active',
        v_plate,
        jsonb_build_object('seed', seed_tag, 'plate', 'L204', 'well_position', well, 'index_pair', format('IDX-%s', well)),
        v_admin
      )
      RETURNING artefact_id INTO v_id;
    END IF;

    alpha_l204_ids := array_append(alpha_l204_ids, v_id);

    IF v_scope_alpha IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
      SELECT v_id, v_scope_alpha, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'alpha library well'), v_admin
      WHERE NOT EXISTS (
        SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_scope_alpha
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_relationships
      WHERE parent_artefact_id = v_parent AND child_artefact_id = v_id
    ) THEN
      INSERT INTO app_provenance.artefact_relationships (
        parent_artefact_id, child_artefact_id, relationship_type, metadata, created_by
      )
      VALUES (
        v_parent, v_id, 'derived_from', jsonb_build_object('seed', seed_tag, 'step', 'library_index'), v_admin
      );
    END IF;
  END LOOP;

  IF v_scope_alpha IS NOT NULL THEN
    PERFORM app_provenance.sp_handover_to_ops(v_scope_alpha, 'ops:alpha-lib', alpha_l204_ids, ARRAY['well_position','index_pair']);
  END IF;

  ops_l204_ids := ARRAY[]::uuid[];
  FOR idx IN 1..array_length(alpha_l204_ids,1) LOOP
    SELECT child_artefact_id INTO v_id
    FROM app_provenance.artefact_relationships
    WHERE parent_artefact_id = alpha_l204_ids[idx]
      AND relationship_type = 'handover_duplicate'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_id IS NOT NULL THEN
      UPDATE app_provenance.artefacts
      SET metadata = coalesce(metadata,'{}') || jsonb_build_object('seed', seed_tag)
      WHERE artefact_id = v_id;

      ops_l204_ids := array_append(ops_l204_ids, v_id);

      IF v_ops_lib_scope IS NOT NULL THEN
        INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
        SELECT v_id, v_ops_lib_scope, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'ops duplicate L204'), v_admin
        WHERE NOT EXISTS (
          SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_ops_lib_scope
        );
      END IF;
    END IF;
  END LOOP;

  -- Ops library plates L401-L403 (approx 270 tubes)
  FOR plate_idx IN 1..array_length(ops_plate_labels,1) LOOP
    SELECT artefact_id INTO v_plate
    FROM app_provenance.artefacts
    WHERE metadata ->> 'seed' = seed_tag AND metadata ->> 'plate' = ops_plate_labels[plate_idx];

    IF v_plate IS NULL THEN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id, name, external_identifier, status, metadata, created_by
      )
      VALUES (
        v_type_plate,
        'Alpha Ops Library ' || ops_plate_labels[plate_idx],
        'alpha-ops-' || lower(ops_plate_labels[plate_idx]),
        'active',
        jsonb_build_object('seed', seed_tag, 'plate', ops_plate_labels[plate_idx], 'description', 'Ops automation intake plate'),
        v_admin
      )
      RETURNING artefact_id INTO v_plate;
    END IF;

    IF v_ops_lib_scope IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
      SELECT v_plate, v_ops_lib_scope, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'ops library plate'), v_admin
      WHERE NOT EXISTS (
        SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_plate AND scope_id = v_ops_lib_scope
      );
    END IF;

    CASE plate_idx
      WHEN 1 THEN n401_ids := ARRAY[]::uuid[];
      WHEN 2 THEN n402_ids := ARRAY[]::uuid[];
      WHEN 3 THEN n403_ids := ARRAY[]::uuid[];
    END CASE;

    idx := 0;
    FOR row_idx IN 1..array_length(ops_row_labels,1) LOOP
      row_char := ops_row_labels[row_idx];
      FOR col_idx IN 1..15 LOOP
        idx := idx + 1;
        well := row_char || lpad(col_idx::text,2,'0');
        donor_idx := ((idx - 1) % array_length(alpha_l204_ids,1)) + 1;
        v_parent := alpha_l204_ids[donor_idx];

        SELECT artefact_id INTO v_id
        FROM app_provenance.artefacts
        WHERE metadata ->> 'seed' = seed_tag
          AND metadata ->> 'plate' = ops_plate_labels[plate_idx]
          AND metadata ->> 'well_position' = well;

        IF v_id IS NULL THEN
          INSERT INTO app_provenance.artefacts (
            artefact_type_id, name, external_identifier, status, container_artefact_id, metadata, created_by
          )
          VALUES (
            v_type_library,
            format('Alpha Ops %s %s', ops_plate_labels[plate_idx], well),
            format('alpha-ops-%s-%s', lower(ops_plate_labels[plate_idx]), lower(well)),
            'active',
            v_plate,
            jsonb_build_object('seed', seed_tag, 'plate', ops_plate_labels[plate_idx], 'well_position', well),
            v_admin
          )
          RETURNING artefact_id INTO v_id;
        END IF;

        IF v_ops_lib_scope IS NOT NULL THEN
          INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
          SELECT v_id, v_ops_lib_scope, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'ops automation tube'), v_admin
          WHERE NOT EXISTS (
            SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_ops_lib_scope
          );
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM app_provenance.artefact_relationships
          WHERE parent_artefact_id = v_parent AND child_artefact_id = v_id
        ) THEN
          INSERT INTO app_provenance.artefact_relationships (
            parent_artefact_id, child_artefact_id, relationship_type, metadata, created_by
          )
          VALUES (
            v_parent, v_id, 'workflow:automation', jsonb_build_object('seed', seed_tag, 'plate', ops_plate_labels[plate_idx]), v_admin
          );
        END IF;

        CASE plate_idx
          WHEN 1 THEN n401_ids := array_append(n401_ids, v_id);
          WHEN 2 THEN n402_ids := array_append(n402_ids, v_id);
          WHEN 3 THEN n403_ids := array_append(n403_ids, v_id);
        END CASE;
      END LOOP;
    END LOOP;
  END LOOP;

  -- Normalised outputs
  SELECT artefact_id INTO v_plate
  FROM app_provenance.artefacts
  WHERE metadata ->> 'seed' = seed_tag AND metadata ->> 'plate' = 'N203';
  IF v_plate IS NULL THEN
    INSERT INTO app_provenance.artefacts (
      artefact_type_id, name, external_identifier, status, metadata, created_by
    )
    VALUES (
      v_type_plate,
      'Alpha Normalised Plate N203',
      'alpha-plate-n203',
      'active',
      jsonb_build_object('seed', seed_tag, 'plate', 'N203', 'description', 'Ops normalised plate'),
      v_admin
    )
    RETURNING artefact_id INTO v_plate;
  END IF;

  IF v_ops_quant_scope IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
    SELECT v_plate, v_ops_quant_scope, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'ops normalised plate'), v_admin
    WHERE NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_plate AND scope_id = v_ops_quant_scope
    );
  END IF;

  n203_ids := ARRAY[]::uuid[];
  FOR idx IN 1..array_length(ops_l204_ids,1) LOOP
    well := alpha_well_labels[idx];
    v_parent := ops_l204_ids[idx];
    SELECT artefact_id INTO v_id
    FROM app_provenance.artefacts
    WHERE metadata ->> 'seed' = seed_tag
      AND metadata ->> 'plate' = 'N203'
      AND metadata ->> 'well_position' = well;
    IF v_id IS NULL THEN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id, name, external_identifier, status, container_artefact_id, metadata, created_by
      )
      VALUES (
        v_type_library,
        'Alpha Normalised N203 ' || well,
        'alpha-n203-' || lower(well),
        'active',
        v_plate,
        jsonb_build_object('seed', seed_tag, 'plate', 'N203', 'well_position', well),
        v_admin
      )
      RETURNING artefact_id INTO v_id;
    END IF;

    n203_ids := array_append(n203_ids, v_id);

    IF v_ops_quant_scope IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
      SELECT v_id, v_ops_quant_scope, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'ops normalised N203'), v_admin
      WHERE NOT EXISTS (
        SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_ops_quant_scope
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_relationships
      WHERE parent_artefact_id = v_parent AND child_artefact_id = v_id
    ) THEN
      INSERT INTO app_provenance.artefact_relationships (
        parent_artefact_id, child_artefact_id, relationship_type, metadata, created_by
      )
      VALUES (
        v_parent, v_id, 'normalized_from', jsonb_build_object('seed', seed_tag, 'step', 'quant'), v_admin
      );
    END IF;
  END LOOP;

  -- Normalised ops plates N401-N403
  FOR plate_idx IN 1..array_length(ops_norm_labels,1) LOOP
    SELECT artefact_id INTO v_plate
    FROM app_provenance.artefacts
    WHERE metadata ->> 'seed' = seed_tag AND metadata ->> 'plate' = ops_norm_labels[plate_idx];
    IF v_plate IS NULL THEN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id, name, external_identifier, status, metadata, created_by
      )
      VALUES (
        v_type_plate,
        'Alpha Normalised Plate ' || ops_norm_labels[plate_idx],
        'alpha-plate-' || lower(ops_norm_labels[plate_idx]),
        'active',
        jsonb_build_object('seed', seed_tag, 'plate', ops_norm_labels[plate_idx], 'description', 'Ops normalised plate'),
        v_admin
      )
      RETURNING artefact_id INTO v_plate;
    END IF;

    IF v_ops_quant_scope IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
      SELECT v_plate, v_ops_quant_scope, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'ops normalised plate'), v_admin
      WHERE NOT EXISTS (
        SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_plate AND scope_id = v_ops_quant_scope
      );
    END IF;

    idx := 0;
    FOR row_idx IN 1..array_length(ops_row_labels,1) LOOP
      row_char := ops_row_labels[row_idx];
      FOR col_idx IN 1..15 LOOP
        idx := idx + 1;
        well := row_char || lpad(col_idx::text,2,'0');
        CASE plate_idx
          WHEN 1 THEN v_parent := n401_ids[idx];
          WHEN 2 THEN v_parent := n402_ids[idx];
          WHEN 3 THEN v_parent := n403_ids[idx];
        END CASE;

        SELECT artefact_id INTO v_id
        FROM app_provenance.artefacts
        WHERE metadata ->> 'seed' = seed_tag
          AND metadata ->> 'plate' = ops_norm_labels[plate_idx]
          AND metadata ->> 'well_position' = well;

        IF v_id IS NULL THEN
          INSERT INTO app_provenance.artefacts (
            artefact_type_id, name, external_identifier, status, container_artefact_id, metadata, created_by
          )
          VALUES (
            v_type_library,
            format('Alpha Normalised %s %s', ops_norm_labels[plate_idx], well),
            format('alpha-%s-%s', lower(ops_norm_labels[plate_idx]), lower(well)),
            'active',
            v_plate,
            jsonb_build_object('seed', seed_tag, 'plate', ops_norm_labels[plate_idx], 'well_position', well),
            v_admin
          )
          RETURNING artefact_id INTO v_id;
        END IF;

        CASE plate_idx
          WHEN 1 THEN n401_ids[idx] := v_id;
          WHEN 2 THEN n402_ids[idx] := v_id;
          WHEN 3 THEN n403_ids[idx] := v_id;
        END CASE;

        IF v_ops_quant_scope IS NOT NULL THEN
          INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
          SELECT v_id, v_ops_quant_scope, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'ops normalised automation'), v_admin
          WHERE NOT EXISTS (
            SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_ops_quant_scope
          );
        END IF;

        IF v_parent IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM app_provenance.artefact_relationships
          WHERE parent_artefact_id = v_parent AND child_artefact_id = v_id
        ) THEN
          INSERT INTO app_provenance.artefact_relationships (
            parent_artefact_id, child_artefact_id, relationship_type, metadata, created_by
          )
          VALUES (
            v_parent, v_id, 'normalized_from', jsonb_build_object('seed', seed_tag, 'step', 'quant'), v_admin
          );
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  -- pool LT5
  SELECT artefact_id INTO v_pool
  FROM app_provenance.artefacts
  WHERE metadata ->> 'seed' = seed_tag AND metadata ->> 'pool' = 'LT5';
  IF v_pool IS NULL THEN
    INSERT INTO app_provenance.artefacts (
      artefact_type_id, name, external_identifier, status, metadata, created_by
    )
    VALUES (
      v_type_pool,
      'Alpha Pool Tube LT5',
      'alpha-pool-lt5',
      'active',
      jsonb_build_object('seed', seed_tag, 'pool', 'LT5'),
      v_admin
    )
    RETURNING artefact_id INTO v_pool;
  END IF;

  IF v_ops_pool_scope IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
    SELECT v_pool, v_ops_pool_scope, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'pooled input'), v_admin
    WHERE NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_pool AND scope_id = v_ops_pool_scope
    );
  END IF;

  pool_inputs := n203_ids || n401_ids || n402_ids || n403_ids;
  FOR idx IN 1..coalesce(array_length(pool_inputs,1),0) LOOP
    v_parent := pool_inputs[idx];
    IF v_parent IS NULL THEN
      CONTINUE;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_relationships
      WHERE parent_artefact_id = v_parent AND child_artefact_id = v_pool
    ) THEN
      INSERT INTO app_provenance.artefact_relationships (
        parent_artefact_id, child_artefact_id, relationship_type, metadata, created_by
      )
      VALUES (
        v_parent, v_pool, 'pooled_input', jsonb_build_object('seed', seed_tag), v_admin
      );
    END IF;
  END LOOP;

  -- Sequencing data products
  data_product_ids := ARRAY[]::uuid[];
  FOR idx IN 1..366 LOOP
    SELECT artefact_id INTO v_id
    FROM app_provenance.artefacts
    WHERE metadata ->> 'seed' = seed_tag
      AND metadata ->> 'pool' = 'LT5'
      AND metadata ->> 'readset_index' = idx::text;
    IF v_id IS NULL THEN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id, name, external_identifier, status, metadata, created_by
      )
      VALUES (
        v_type_data,
        format('Alpha LT5 Readset %03s', idx),
        format('alpha-lt5-read-%03s', idx),
        'active',
        jsonb_build_object('seed', seed_tag, 'pool', 'LT5', 'readset_index', idx),
        v_admin
      )
      RETURNING artefact_id INTO v_id;
    END IF;

    data_product_ids := array_append(data_product_ids, v_id);

    IF v_ops_run_scope IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
      SELECT v_id, v_ops_run_scope, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'ops run output'), v_admin
      WHERE NOT EXISTS (
        SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_ops_run_scope
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_relationships
      WHERE parent_artefact_id = v_pool AND child_artefact_id = v_id
    ) THEN
      INSERT INTO app_provenance.artefact_relationships (
        parent_artefact_id, child_artefact_id, relationship_type, metadata, created_by
      )
      VALUES (
        v_pool, v_id, 'produced_output', jsonb_build_object('seed', seed_tag, 'step', 'sequencing'), v_admin
      );
    END IF;

    PERFORM app_provenance.sp_return_from_ops(v_id, ARRAY[v_scope_alpha]);

    UPDATE app_provenance.artefacts
    SET metadata = coalesce(metadata,'{}') || jsonb_build_object('seed', seed_tag)
    WHERE artefact_id = v_id;
  END LOOP;

  -- Tag transfer_state trait rows for clean rollback
  UPDATE app_provenance.artefact_trait_values
  SET metadata = coalesce(metadata,'{}') || jsonb_build_object('seed', seed_tag)
  WHERE artefact_id = ANY(alpha_l204_ids)
     OR artefact_id = ANY(ops_l204_ids)
     OR artefact_id = ANY(data_product_ids);

  -- Beta physical tubes (no ops involvement)
  FOR idx IN 1..48 LOOP
    donor_idx := ((idx - 1) % array_length(beta_donor_ids,1)) + 1;
    v_parent := beta_donor_ids[donor_idx];
    well := format('BT%03s', idx);
    SELECT artefact_id INTO v_id
    FROM app_provenance.artefacts
    WHERE metadata ->> 'seed' = seed_tag
      AND metadata ->> 'beta_sample' = well;
    IF v_id IS NULL THEN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id, name, external_identifier, status, metadata, created_by
      )
      VALUES (
        v_type_sample,
        format('Beta Research Tube %s', well),
        'beta-tube-' || lower(well),
        'active',
        jsonb_build_object('seed', seed_tag, 'beta_sample', well),
        v_admin
      )
      RETURNING artefact_id INTO v_id;
    END IF;

    beta_donor_ids[donor_idx] := v_parent;

    IF v_scope_beta IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, metadata, assigned_by)
      SELECT v_id, v_scope_beta, 'primary', jsonb_build_object('seed', seed_tag, 'note', 'beta tube'), v_admin
      WHERE NOT EXISTS (
        SELECT 1 FROM app_provenance.artefact_scopes WHERE artefact_id = v_id AND scope_id = v_scope_beta
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM app_provenance.artefact_relationships
      WHERE parent_artefact_id = v_parent AND child_artefact_id = v_id
    ) THEN
      INSERT INTO app_provenance.artefact_relationships (
        parent_artefact_id, child_artefact_id, relationship_type, metadata, created_by
      )
      VALUES (
        v_parent, v_id, 'derived_from', jsonb_build_object('seed', seed_tag, 'note', 'beta intake tube'), v_admin
      );
    END IF;
  END LOOP;
END;
$$;

-- migrate:down
DO $$
DECLARE
  seed_tag constant text := 'security-redux-story';
  v_scope_id uuid;
  scope_key text;
BEGIN
  -- Remove memberships
  DELETE FROM app_security.scope_memberships
  WHERE metadata ->> 'seed' = seed_tag;

  -- Remove story users
  DELETE FROM app_core.user_roles
  WHERE user_id IN (SELECT id FROM app_core.users WHERE metadata ->> 'seed' = seed_tag);
  DELETE FROM app_core.users WHERE metadata ->> 'seed' = seed_tag;

  -- Remove trait values and relationships tagged by seed
  DELETE FROM app_provenance.artefact_trait_values
  WHERE metadata ->> 'seed' = seed_tag;

  DELETE FROM app_provenance.artefact_relationships
  WHERE metadata ->> 'seed' = seed_tag;

  -- Remove artefact scopes tagged by seed
  DELETE FROM app_provenance.artefact_scopes
  WHERE metadata ->> 'seed' = seed_tag;

  -- Remove artefacts tagged by seed
  DELETE FROM app_provenance.artefacts
  WHERE metadata ->> 'seed' = seed_tag;

  -- Remove ops scopes created for story
  FOR scope_key IN SELECT unnest(ARRAY['ops:alpha-lib','ops:alpha-quant','ops:alpha-pool','ops:alpha-run']) LOOP
    SELECT scope_id INTO v_scope_id FROM app_security.scopes WHERE scope_key = scope_key AND metadata ->> 'seed' = seed_tag;
    IF v_scope_id IS NOT NULL THEN
      DELETE FROM app_security.scopes WHERE scope_id = v_scope_id;
    END IF;
  END LOOP;
END;
$$;
