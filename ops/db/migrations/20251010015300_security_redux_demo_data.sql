-- migrate:up
DO $$
DECLARE
  v_admin uuid;
  v_ops uuid;
  v_alice uuid;
  v_bob uuid;
  v_scope_prj1 uuid;
  v_scope_prj2 uuid;
  v_ops_scope_pending uuid;
  v_ops_scope_returned uuid;
  v_src uuid;
  v_duplicate uuid;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  SELECT id INTO v_ops FROM app_core.users WHERE email = 'ops@example.org';
  SELECT id INTO v_alice FROM app_core.users WHERE email = 'alice@example.org';
  SELECT id INTO v_bob FROM app_core.users WHERE email = 'bob@example.org';

  SELECT scope_id INTO v_scope_prj1 FROM app_security.scopes WHERE scope_key = 'project:prj-001';
  SELECT scope_id INTO v_scope_prj2 FROM app_security.scopes WHERE scope_key = 'project:prj-002';

  IF v_admin IS NULL THEN
    RAISE NOTICE 'Admin user missing; skipping security demo seed';
    RETURN;
  END IF;

  PERFORM set_config('app.actor_id', v_admin::text, true);
  PERFORM set_config('app.actor_identity', 'admin@example.org', true);
  PERFORM set_config('app.roles', 'app_admin', true);

  IF v_scope_prj1 IS NOT NULL AND v_alice IS NOT NULL THEN
    INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, metadata)
    VALUES (v_scope_prj1, v_alice, 'app_researcher', jsonb_build_object('seed', 'security-redux', 'note', 'demo-membership'))
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_scope_prj2 IS NOT NULL AND v_bob IS NOT NULL THEN
    INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, metadata)
    VALUES (v_scope_prj2, v_bob, 'app_researcher', jsonb_build_object('seed', 'security-redux', 'note', 'demo-membership'))
    ON CONFLICT DO NOTHING;
  END IF;

  -- Create a pending handover for project PRJ-001
  SELECT artefact_id INTO v_src
  FROM app_provenance.artefacts
  WHERE name = 'DNA Intake Batch 001 - Donor 101';

  IF v_src IS NOT NULL AND v_scope_prj1 IS NOT NULL THEN
    PERFORM app_provenance.sp_handover_to_ops(
      p_research_scope_id => v_scope_prj1,
      p_ops_scope_key     => 'ops:demo:pending',
      p_artefact_ids      => ARRAY[v_src],
      p_field_whitelist   => ARRAY['barcode','well_volume_ul']
    );
  END IF;

  SELECT scope_id INTO v_ops_scope_pending
  FROM app_security.scopes
  WHERE scope_key = 'ops:demo:pending';

  IF v_ops_scope_pending IS NOT NULL AND v_ops IS NOT NULL THEN
    INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, metadata)
    VALUES (v_ops_scope_pending, v_ops, 'app_operator', jsonb_build_object('seed', 'security-redux', 'note', 'demo-pending'))
    ON CONFLICT DO NOTHING;
  END IF;

  -- Create a handover that has been returned
  SELECT artefact_id INTO v_src
  FROM app_provenance.artefacts
  WHERE name = 'DNA Intake Batch 001 - Donor 102';

  IF v_src IS NOT NULL AND v_scope_prj1 IS NOT NULL THEN
    PERFORM app_provenance.sp_handover_to_ops(
      p_research_scope_id => v_scope_prj1,
      p_ops_scope_key     => 'ops:demo:returned',
      p_artefact_ids      => ARRAY[v_src],
      p_field_whitelist   => ARRAY['barcode','well_volume_ul']
    );

    SELECT scope_id INTO v_ops_scope_returned
    FROM app_security.scopes
    WHERE scope_key = 'ops:demo:returned';

    IF v_ops_scope_returned IS NOT NULL AND v_ops IS NOT NULL THEN
      INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, metadata)
      VALUES (v_ops_scope_returned, v_ops, 'app_operator', jsonb_build_object('seed', 'security-redux', 'note', 'demo-returned'))
      ON CONFLICT DO NOTHING;
    END IF;

    SELECT rel.child_artefact_id
      INTO v_duplicate
      FROM app_provenance.artefact_relationships rel
      WHERE rel.parent_artefact_id = v_src
        AND rel.relationship_type = 'handover_duplicate'
      ORDER BY rel.created_at DESC
      LIMIT 1;

    IF v_duplicate IS NOT NULL THEN
      PERFORM app_provenance.sp_return_from_ops(
        p_ops_artefact_id    => v_duplicate,
        p_research_scope_ids => ARRAY[v_scope_prj1]
      );
    END IF;
  END IF;
END;
$$;

-- migrate:down
DO $$
DECLARE
  v_scope_id uuid;
  v_user_id uuid;
  v_key text;
BEGIN
  FOR v_key IN SELECT unnest(ARRAY['ops:demo:pending','ops:demo:returned']) LOOP
    SELECT scope_id INTO v_scope_id
    FROM app_security.scopes
    WHERE scope_key = v_key;

    IF v_scope_id IS NULL THEN
      CONTINUE;
    END IF;

    DELETE FROM app_security.scope_memberships
    WHERE scope_id = v_scope_id
      AND metadata ->> 'seed' = 'security-redux';

    DELETE FROM app_provenance.artefact_trait_values
    WHERE metadata ->> 'scope' = v_key;

    DELETE FROM app_provenance.artefact_scopes
    WHERE scope_id = v_scope_id
      AND metadata ->> 'source' IN ('app_provenance.sp_handover_to_ops', 'app_provenance.sp_return_from_ops');

    DELETE FROM app_provenance.artefact_relationships
    WHERE relationship_type = 'handover_duplicate'
      AND child_artefact_id IN (
        SELECT artefact_id
        FROM app_provenance.artefacts
        WHERE metadata ->> 'handover_scope_key' = v_key
      );

    DELETE FROM app_provenance.artefacts
    WHERE metadata ->> 'handover_scope_key' = v_key;

    DELETE FROM app_security.scopes
    WHERE scope_id = v_scope_id;
  END LOOP;

  DELETE FROM app_security.scope_memberships
  WHERE metadata ->> 'seed' = 'security-redux'
    AND scope_id IN (
      SELECT scope_id
      FROM app_security.scopes
      WHERE scope_key IN ('project:prj-001','project:prj-002')
    );
END;
$$;
