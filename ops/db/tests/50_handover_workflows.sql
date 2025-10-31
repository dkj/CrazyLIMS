SET ROLE app_admin;

DO $$
DECLARE
  v_admin uuid;
  v_operator uuid;
  v_researcher uuid;
  v_research_scope uuid;
  v_ops_scope uuid;
  v_source uuid;
  v_duplicate uuid;
  v_ops_scope_key text := format('ops:test:%s', replace(gen_random_uuid()::text, '-', ''));
  v_value text;
  v_numeric numeric;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  PERFORM pg_temp.isnt_null(v_admin, 'Admin fixture user present for ops handover');

  PERFORM set_config('app.actor_id', v_admin::text, true);
  PERFORM set_config('app.actor_identity', 'admin@example.org', true);
  PERFORM set_config('app.roles', 'app_admin', true);

  SELECT artefact_id
    INTO v_source
    FROM app_provenance.artefacts
   WHERE external_identifier = 'SAMPLE-GP-001-A';
  PERFORM pg_temp.isnt_null(v_source, 'Source sample artefact available');

  SELECT scope_id
    INTO v_research_scope
    FROM app_security.scopes
   WHERE scope_key = 'dataset:pilot_plasma';
  PERFORM pg_temp.isnt_null(v_research_scope, 'Research dataset scope available');

  v_ops_scope := app_provenance.sp_handover_to_ops(
    p_research_scope_id => v_research_scope,
    p_ops_scope_key     => v_ops_scope_key,
    p_artefact_ids      => ARRAY[v_source],
    p_field_whitelist   => ARRAY['well_volume_ul']
  );

  PERFORM pg_temp.isnt_null(v_ops_scope, 'Handover to ops returned scope id');

  SELECT child_artefact_id
    INTO v_duplicate
    FROM app_provenance.artefact_relationships
   WHERE parent_artefact_id = v_source
     AND relationship_type = 'handover_duplicate'
   ORDER BY created_at DESC
   LIMIT 1;

  PERFORM pg_temp.isnt_null(v_duplicate, 'Handover duplicate artefact created');

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.artefact_scopes
       WHERE artefact_id = v_duplicate
         AND scope_id = v_ops_scope
    ),
    'Ops duplicate assigned to ops scope'
  );

  SELECT metadata ->> 'well_volume_ul'
    INTO v_value
    FROM app_provenance.artefacts
   WHERE artefact_id = v_duplicate;

  PERFORM pg_temp.isnt_null(v_value, 'Ops duplicate retains whitelisted metadata');

  SELECT trim(both '"' FROM tv.value::text)
    INTO v_value
    FROM app_provenance.artefact_trait_values tv
    JOIN app_provenance.artefact_traits t ON t.trait_id = tv.trait_id
   WHERE tv.artefact_id = v_source
    AND t.trait_key = 'transfer_state'
   ORDER BY tv.effective_at DESC
   LIMIT 1;

  PERFORM pg_temp.is(v_value, 'transferred', 'Source artefact marked transferred');

  SELECT metadata ->> 'well_volume_ul'
    INTO v_value
    FROM app_provenance.artefacts
   WHERE artefact_id = v_duplicate;
  v_numeric := (v_value)::numeric;
  PERFORM pg_temp.isnt_null(v_numeric, 'Whitelisted metadata parses to numeric');

  PERFORM set_config('session.handover_source', v_source::text, false);
  PERFORM set_config('session.handover_duplicate', v_duplicate::text, false);
  PERFORM set_config('session.handover_research_scope', v_research_scope::text, false);
  PERFORM set_config('session.handover_ops_scope', v_ops_scope::text, false);
END;
$$;

RESET ROLE;

SET ROLE app_operator;

DO $$
DECLARE
  v_operator uuid := current_setting('session.operator_id', false)::uuid;
  v_duplicate uuid := current_setting('session.handover_duplicate', false)::uuid;
BEGIN
  IF v_operator IS NULL THEN
    PERFORM pg_temp.fail('Operator session id missing');
  END IF;
  IF v_duplicate IS NULL THEN
    PERFORM pg_temp.fail('Handover duplicate id missing');
  END IF;

  PERFORM set_config('app.actor_id', v_operator::text, true);
  PERFORM set_config('app.actor_identity', 'ops@example.org', true);
  PERFORM set_config('app.roles', 'app_operator', true);

  PERFORM pg_temp.ok(
    app_provenance.can_update_handover_metadata(v_duplicate),
    'Operator can adjust ops duplicate metadata before return'
  );
END;
$$;

RESET ROLE;

SET ROLE app_researcher;

DO $$
DECLARE
  v_researcher uuid := current_setting('session.researcher_id', false)::uuid;
  v_duplicate uuid := current_setting('session.handover_duplicate', false)::uuid;
  v_allowed boolean;
BEGIN
  IF v_researcher IS NULL THEN
    SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';
  END IF;
  IF v_researcher IS NULL THEN
    PERFORM pg_temp.fail('Researcher session id missing');
  END IF;
  IF v_duplicate IS NULL THEN
    PERFORM pg_temp.fail('Handover duplicate id missing for researcher check');
  END IF;

  PERFORM set_config('app.actor_id', v_researcher::text, true);
  PERFORM set_config('app.actor_identity', 'alice@example.org', true);
  PERFORM set_config('app.roles', 'app_researcher', true);

  SELECT app_provenance.can_access_artefact(v_duplicate)
    INTO v_allowed;
  PERFORM pg_temp.ok(COALESCE(v_allowed, false), 'Researcher can view ops duplicate via lineage');

  SELECT app_provenance.can_update_handover_metadata(v_duplicate)
    INTO v_allowed;
  PERFORM pg_temp.ok(NOT COALESCE(v_allowed, false), 'Researcher cannot update ops duplicate metadata');
END;
$$;

RESET ROLE;

SET ROLE app_admin;

DO $$
DECLARE
  v_admin uuid;
  v_source uuid := current_setting('session.handover_source', false)::uuid;
  v_duplicate uuid := current_setting('session.handover_duplicate', false)::uuid;
  v_research_scope uuid := current_setting('session.handover_research_scope', false)::uuid;
  v_value text;
  v_numeric numeric;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  PERFORM pg_temp.isnt_null(v_admin, 'Admin fixture present for propagation phase');
  PERFORM pg_temp.ok(v_source IS NOT NULL AND v_duplicate IS NOT NULL AND v_research_scope IS NOT NULL, 'Handover context available for propagation');

  PERFORM set_config('app.actor_id', v_admin::text, true);
  PERFORM set_config('app.actor_identity', 'admin@example.org', true);
  PERFORM set_config('app.roles', 'app_admin', true);

  UPDATE app_provenance.artefacts
     SET metadata = (metadata - 'well_volume_ul') || jsonb_build_object('well_volume_ul', 432)
   WHERE artefact_id = v_source;

  SELECT (metadata ->> 'well_volume_ul')::numeric
    INTO v_numeric
    FROM app_provenance.artefacts
   WHERE artefact_id = v_duplicate;

  PERFORM pg_temp.is(v_numeric, 432, 'Whitelisted metadata propagated to ops duplicate');

  UPDATE app_provenance.artefacts
     SET metadata = metadata || jsonb_build_object('sensitive_note', 'keep private')
   WHERE artefact_id = v_source;

  PERFORM pg_temp.ok(
    NOT EXISTS (
      SELECT 1
        FROM app_provenance.artefacts
       WHERE artefact_id = v_duplicate
         AND metadata ? 'sensitive_note'
    ),
    'Non-whitelisted metadata blocked from propagation'
  );

  PERFORM app_provenance.sp_return_from_ops(v_duplicate, ARRAY[v_research_scope]);

  SELECT trim(both '"' FROM tv.value::text)
    INTO v_value
    FROM app_provenance.artefact_trait_values tv
    JOIN app_provenance.artefact_traits t ON t.trait_id = tv.trait_id
   WHERE tv.artefact_id = v_duplicate
     AND t.trait_key = 'transfer_state'
   ORDER BY tv.effective_at DESC
   LIMIT 1;

  PERFORM pg_temp.is(v_value, 'returned', 'Ops artefact marked returned after sp_return_from_ops');

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.artefact_scopes
       WHERE artefact_id = v_duplicate
         AND scope_id = v_research_scope
    ),
    'Returned ops artefact regains research scope membership'
  );
END;
$$;

RESET ROLE;

SET ROLE app_operator;

DO $$
DECLARE
  v_operator uuid := current_setting('session.operator_id', false)::uuid;
  v_duplicate uuid := current_setting('session.handover_duplicate', false)::uuid;
  v_allowed boolean;
BEGIN
  IF v_operator IS NULL OR v_duplicate IS NULL THEN
    PERFORM pg_temp.fail('Operator post-return context missing');
  END IF;

  PERFORM set_config('app.actor_id', v_operator::text, true);
  PERFORM set_config('app.actor_identity', 'ops@example.org', true);
  PERFORM set_config('app.roles', 'app_operator', true);

  SELECT app_provenance.can_update_handover_metadata(v_duplicate)
    INTO v_allowed;
  PERFORM pg_temp.ok(NOT COALESCE(v_allowed, false), 'Operator cannot update metadata after return');
END;
$$;

RESET ROLE;

SET ROLE app_researcher;

DO $$
DECLARE
  v_researcher uuid := current_setting('session.researcher_id', false)::uuid;
  v_duplicate uuid := current_setting('session.handover_duplicate', false)::uuid;
  v_allowed boolean;
BEGIN
  IF v_researcher IS NULL THEN
    SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';
  END IF;
  IF v_duplicate IS NULL THEN
    PERFORM pg_temp.fail('Researcher post-return duplicate id missing');
  END IF;

  PERFORM set_config('app.actor_id', v_researcher::text, true);
  PERFORM set_config('app.actor_identity', 'alice@example.org', true);
  PERFORM set_config('app.roles', 'app_researcher', true);

  SELECT app_provenance.can_access_artefact(v_duplicate)
    INTO v_allowed;
  PERFORM pg_temp.ok(COALESCE(v_allowed, false), 'Researcher retains visibility after return');
END;
$$;

RESET ROLE;

SET ROLE app_admin;

DO $$
DECLARE
  v_admin uuid;
  v_source uuid := current_setting('session.handover_source', true)::uuid;
  v_research_scope uuid := current_setting('session.handover_research_scope', true)::uuid;
  v_collab_scope uuid;
  v_duplicate uuid;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  PERFORM pg_temp.isnt_null(v_admin, 'Admin fixture present for generalised handover tests');

  IF v_source IS NULL THEN
    SELECT artefact_id INTO v_source
      FROM app_provenance.artefacts
     WHERE external_identifier = 'SAMPLE-GP-001-A';
  END IF;
  PERFORM pg_temp.isnt_null(v_source, 'Generalised handover source artefact present');

  IF v_research_scope IS NULL THEN
    SELECT scope_id INTO v_research_scope
      FROM app_security.scopes
     WHERE scope_key = 'dataset:pilot_plasma';
  END IF;
  PERFORM pg_temp.isnt_null(v_research_scope, 'Research scope available for generalised handover tests');

  v_collab_scope := app_provenance.sp_transfer_between_scopes(
    p_source_scope_id      => v_research_scope,
    p_target_scope_key     => 'project:pilot-collab',
    p_target_scope_type    => 'project',
    p_artefact_ids         => ARRAY[v_source],
    p_field_whitelist      => ARRAY['well_volume_ul'],
    p_allowed_roles        => ARRAY['app_researcher'],
    p_relationship_metadata => jsonb_build_object('test_case', 'generalised-collab')
  );

  PERFORM pg_temp.isnt_null(v_collab_scope, 'Collaborative transfer returned scope id');

  SELECT child_artefact_id
    INTO v_duplicate
    FROM app_provenance.artefact_relationships rel
   WHERE rel.parent_artefact_id = v_source
     AND rel.relationship_type = 'handover_duplicate'
   ORDER BY rel.created_at DESC
   LIMIT 1;

  PERFORM pg_temp.isnt_null(v_duplicate, 'Generalised handover duplicate created');

  PERFORM set_config('session.collab_scope', v_collab_scope::text, false);
  PERFORM set_config('session.collab_duplicate', v_duplicate::text, false);

  INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, granted_by, metadata)
  VALUES (
    v_collab_scope,
    (SELECT id FROM app_core.users WHERE email = 'alice@example.org'),
    'app_researcher',
    v_admin,
    jsonb_build_object('test', 'generalised')
  )
  ON CONFLICT (scope_id, user_id, role_name) DO NOTHING;
END;
$$;

RESET ROLE;

SET ROLE app_researcher;

DO $$
DECLARE
  v_researcher uuid := current_setting('session.researcher_id', true)::uuid;
  v_duplicate uuid := current_setting('session.collab_duplicate', true)::uuid;
  v_roles text[];
  v_allowed boolean;
  v_view record;
BEGIN
  IF v_researcher IS NULL THEN
    SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';
  END IF;
  IF v_researcher IS NULL THEN
    PERFORM pg_temp.fail('Researcher session id missing for generalised handover tests');
  END IF;
  IF v_duplicate IS NULL THEN
    PERFORM pg_temp.fail('Collaborative duplicate id missing for researcher test');
  END IF;

  PERFORM set_config('app.actor_id', v_researcher::text, true);
  PERFORM set_config('app.actor_identity', 'alice@example.org', true);
  PERFORM set_config('app.roles', 'app_researcher', true);

  v_roles := app_provenance.transfer_allowed_roles(v_duplicate);
  PERFORM pg_temp.ok(array_length(v_roles, 1) = 1 AND v_roles[1] = 'app_researcher', 'transfer_allowed_roles restricts to researcher');

  SELECT app_provenance.can_update_handover_metadata(v_duplicate)
    INTO v_allowed;
  PERFORM pg_temp.ok(COALESCE(v_allowed, false), 'Researcher can update collaborative duplicate metadata');

  SELECT allowed_roles, relationship_type
    INTO v_view
    FROM app_core.v_scope_transfer_overview
   WHERE target_artefact_id = v_duplicate;

  PERFORM pg_temp.is(v_view.relationship_type, 'handover_duplicate', 'Scope transfer overview relationship type correct');
  PERFORM pg_temp.ok(v_view.allowed_roles @> ARRAY['app_researcher'], 'Scope transfer overview exposes researcher role');
END;
$$;

RESET ROLE;

SET ROLE app_operator;

DO $$
DECLARE
  v_operator uuid := current_setting('session.operator_id', true)::uuid;
  v_duplicate uuid := current_setting('session.collab_duplicate', true)::uuid;
BEGIN
  IF v_operator IS NULL THEN
    SELECT id INTO v_operator FROM app_core.users WHERE email = 'ops@example.org';
  END IF;
  IF v_duplicate IS NULL THEN
    PERFORM pg_temp.fail('Collaborative duplicate id missing for operator check');
  END IF;

  PERFORM set_config('app.actor_id', v_operator::text, true);
  PERFORM set_config('app.actor_identity', 'ops@example.org', true);
  PERFORM set_config('app.roles', 'app_operator', true);

  PERFORM pg_temp.ok(
    NOT app_provenance.can_update_handover_metadata(v_duplicate),
    'Operator cannot update collaborative duplicate metadata'
  );
END;
$$;

RESET ROLE;

SET ROLE app_researcher;

DO $$
DECLARE
  v_researcher uuid := current_setting('session.researcher_id', true)::uuid;
  v_duplicate uuid := current_setting('session.collab_duplicate', true)::uuid;
  v_collab_scope uuid := current_setting('session.collab_scope', true)::uuid;
  v_return_scope uuid := current_setting('session.handover_research_scope', true)::uuid;
  v_state text;
BEGIN
  IF v_researcher IS NULL THEN
    SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';
  END IF;
  IF v_researcher IS NULL THEN
    PERFORM pg_temp.fail('Researcher context missing for completion test');
  END IF;
  IF v_duplicate IS NULL OR v_collab_scope IS NULL THEN
    PERFORM pg_temp.fail('Collaborative context missing for completion test');
  END IF;
  IF v_return_scope IS NULL THEN
    PERFORM pg_temp.fail('Research scope missing for completion test');
  END IF;

  PERFORM set_config('app.actor_id', v_researcher::text, true);
  PERFORM set_config('app.actor_identity', 'alice@example.org', true);
  PERFORM set_config('app.roles', 'app_researcher', true);

  PERFORM app_provenance.sp_complete_transfer(
    p_target_artefact_id => v_duplicate,
    p_return_scope_ids   => ARRAY[v_return_scope]
  );

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.artefact_scopes
       WHERE artefact_id = v_duplicate
         AND scope_id = v_return_scope
         AND relationship = 'derived_from'
    ),
    'Collaborative duplicate gains research derived_from scope after completion'
  );

  SELECT trim(both '"' FROM tv.value::text)
    INTO v_state
    FROM app_provenance.artefact_trait_values tv
    JOIN app_provenance.artefact_traits t ON t.trait_id = tv.trait_id
   WHERE tv.artefact_id = v_duplicate
     AND t.trait_key = 'transfer_state'
   ORDER BY tv.effective_at DESC
   LIMIT 1;

  PERFORM pg_temp.is(v_state, 'returned', 'Collaborative duplicate marked returned after completion');

  PERFORM pg_temp.ok(
    NOT app_provenance.can_update_handover_metadata(v_duplicate),
    'Researcher cannot update metadata after collaborative handover completes'
  );
END;
$$;

RESET ROLE;
