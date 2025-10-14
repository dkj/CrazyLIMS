-- migrate:up
DO $$
DECLARE
  v_txn uuid;
  v_admin uuid;
  v_operator uuid;
  v_researcher uuid;

  v_facility_scope uuid;
  v_project_scope uuid;
  v_dataset_scope uuid;
  v_workflow_scope uuid;

  v_subject_type uuid;
  v_material_type uuid;
  v_reagent_type uuid;
  v_data_product_type uuid;
  v_instrument_run_type uuid;
  v_container_generic_type uuid;
  v_container_plate_type uuid;
  v_container_cryovial_type uuid;

  v_trait_divisible uuid;
  v_trait_storage_temp uuid;
  v_trait_concentration uuid;

  v_process_type_draw uuid;
  v_process_type_processing uuid;
  v_process_type_sequencing uuid;

  v_process_draw uuid;
  v_process_processing uuid;
  v_process_sequencing uuid;

  v_subject uuid;
  v_sample uuid;
  v_reagent uuid;
  v_plate_container uuid;
  v_vial_container uuid;
  v_data_product uuid;
  v_instrument_run uuid;

  v_facility_node uuid;
  v_freezer_node uuid;
  v_shelf_node uuid;

  v_slot_a1 uuid;
  v_slot_a2 uuid;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  SELECT id INTO v_operator FROM app_core.users WHERE email = 'ops@example.org';
  SELECT id INTO v_researcher FROM app_core.users WHERE email = 'alice@example.org';

  IF v_admin IS NULL OR v_operator IS NULL OR v_researcher IS NULL THEN
    RAISE EXCEPTION 'Baseline users missing – run Phase 1 seeds first';
  END IF;

  v_txn := app_security.start_transaction_context(
    p_actor_id => v_admin,
    p_actor_identity => 'seed:phase2-redux',
    p_effective_roles => ARRAY['app_admin'],
    p_client_app => 'dbmate:migration',
    p_metadata => jsonb_build_object('seed', 'phase2-redux')
  );

  PERFORM set_config('app.actor_id', v_admin::text, true);
  PERFORM set_config('app.actor_identity', 'seed:phase2-redux', true);
  PERFORM set_config('app.roles', 'app_admin', true);

  UPDATE app_security.transaction_contexts
  SET actor_id = v_admin,
      actor_identity = 'seed:phase2-redux'
  WHERE txn_id = v_txn;

  ---------------------------------------------------------------------------
  -- Scope role inheritance defaults
  ---------------------------------------------------------------------------

  INSERT INTO app_security.scope_role_inheritance (
    parent_scope_type,
    child_scope_type,
    parent_role_name,
    child_role_name,
    is_active
  )
  SELECT *
  FROM (
    VALUES
      ('project','dataset','app_admin','app_admin',true),
      ('project','dataset','app_operator','app_operator',true),
      ('project','dataset','app_researcher','app_researcher',true),
      ('project','dataset','app_automation','app_automation',true),
      ('dataset','workflow_run','app_admin','app_admin',true),
      ('dataset','workflow_run','app_operator','app_operator',true),
      ('dataset','workflow_run','app_researcher','app_researcher',true),
      ('dataset','workflow_run','app_automation','app_automation',true),
      ('project','facility','app_admin','app_admin',true),
      ('project','facility','app_operator','app_operator',true)
  ) AS seed(parent_scope_type, child_scope_type, parent_role_name, child_role_name, is_active)
  ON CONFLICT (parent_scope_type, child_scope_type, parent_role_name, child_role_name)
  DO UPDATE SET is_active = EXCLUDED.is_active;

  ---------------------------------------------------------------------------
  -- Scopes
  ---------------------------------------------------------------------------

  INSERT INTO app_security.scopes (
    scope_key,
    scope_type,
    display_name,
    description,
    metadata,
    created_by
  )
  VALUES
    ('facility:main_biolab', 'facility', 'Main BioLab Facility', 'Primary wet lab facility', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (scope_key) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        description = EXCLUDED.description
  RETURNING scope_id INTO v_facility_scope;

  INSERT INTO app_security.scopes (
    scope_key,
    scope_type,
    display_name,
    description,
    parent_scope_id,
    metadata,
    created_by
  )
  VALUES
    ('project:genomics_pilot', 'project', 'Genomics Pilot Project', 'Pilot programme for sequencing pipeline', NULL, jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (scope_key) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        description = EXCLUDED.description
  RETURNING scope_id INTO v_project_scope;

  INSERT INTO app_security.scopes (
    scope_key,
    scope_type,
    display_name,
    description,
    parent_scope_id,
    metadata,
    created_by
  )
  VALUES
    ('dataset:pilot_plasma', 'dataset', 'Pilot Plasma Dataset', 'Synthetic dataset covering pilot plasma samples', v_project_scope, jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (scope_key) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        description = EXCLUDED.description,
        parent_scope_id = EXCLUDED.parent_scope_id
  RETURNING scope_id INTO v_dataset_scope;

  INSERT INTO app_security.scopes (
    scope_key,
    scope_type,
    display_name,
    description,
    parent_scope_id,
    metadata,
    created_by
  )
  VALUES
    ('workflow:pilot_run_2025w40', 'workflow_run', 'Pilot Sequencing Run W40', 'Sequencing run for pilot samples (week 40)', v_dataset_scope, jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (scope_key) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        description = EXCLUDED.description,
        parent_scope_id = EXCLUDED.parent_scope_id
  RETURNING scope_id INTO v_workflow_scope;

  ---------------------------------------------------------------------------
  -- Scope memberships
  ---------------------------------------------------------------------------

  INSERT INTO app_security.scope_memberships (
    scope_id,
    user_id,
    role_name,
    granted_by,
    metadata
  )
  VALUES
    (v_project_scope, v_admin, 'app_admin', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_project_scope, v_operator, 'app_operator', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_project_scope, v_researcher, 'app_researcher', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_facility_scope, v_operator, 'app_operator', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_dataset_scope, v_researcher, 'app_researcher', v_admin, jsonb_build_object('seed','phase2-redux'))
  ON CONFLICT (scope_id, user_id, role_name) DO UPDATE
    SET is_active = true,
        expires_at = NULL,
        metadata = jsonb_set(coalesce(app_security.scope_memberships.metadata, '{}'::jsonb), '{seed}', to_jsonb('phase2-redux'::text), true);

  ---------------------------------------------------------------------------
  -- Artefact types
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
  VALUES
    ('subject', 'Subject', 'subject', 'Human or animal subject tracked as provenance root', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING artefact_type_id INTO v_subject_type;

  INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
  VALUES
    ('material_sample', 'Material Sample', 'material', 'Primary or derivative material sample', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING artefact_type_id INTO v_material_type;

  INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
  VALUES
    ('reagent_buffer', 'Buffer Reagent', 'reagent', 'Buffer reagent lot for plasma prep', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING artefact_type_id INTO v_reagent_type;

  INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
  VALUES
    ('data_product_sequence', 'Sequencing Data Product', 'data_product', 'Sequencing output with provenance trace', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING artefact_type_id INTO v_data_product_type;

  INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
  VALUES
    ('instrument_run_flowcell', 'Flowcell Run', 'instrument_run', 'Instrument run artefact for tracking sequencing hardware state', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING artefact_type_id INTO v_instrument_run_type;

  INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
  VALUES
    ('container_generic', 'Generic Container', 'container', 'Generic container without predefined layout', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING artefact_type_id INTO v_container_generic_type;

  INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
  VALUES
    ('container_plate_96', '96 Well Plate', 'container', '96-well SBS plate layout', jsonb_build_object('seed','phase2-redux','grid','8x12'), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        metadata = EXCLUDED.metadata
  RETURNING artefact_type_id INTO v_container_plate_type;

  INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
  VALUES
    ('container_cryovial_2ml', '2 mL Cryovial', 'container', 'Cryovial for frozen aliquots', jsonb_build_object('seed','phase2-redux','volume_ml',2), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        metadata = EXCLUDED.metadata
  RETURNING artefact_type_id INTO v_container_cryovial_type;

  ---------------------------------------------------------------------------
  -- Traits
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.artefact_traits (trait_key, display_name, data_type, description, metadata, created_by)
  VALUES
    ('divisible', 'Divisible', 'boolean', 'Whether the artefact can be split without consuming identity', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (trait_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING trait_id INTO v_trait_divisible;

  INSERT INTO app_provenance.artefact_traits (trait_key, display_name, data_type, description, metadata, created_by)
  VALUES
    ('storage_temperature_c', 'Storage Temperature (°C)', 'numeric', 'Nominal storage temperature requirement', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (trait_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING trait_id INTO v_trait_storage_temp;

  INSERT INTO app_provenance.artefact_traits (trait_key, display_name, data_type, description, metadata, created_by)
  VALUES
    ('concentration_mg_ml', 'Concentration (mg/mL)', 'numeric', 'Mass concentration for material or reagent', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (trait_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING trait_id INTO v_trait_concentration;

  ---------------------------------------------------------------------------
  -- Process types
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.process_types (type_key, display_name, description, metadata, created_by)
  VALUES
    ('blood_draw', 'Blood Draw', 'Collection of whole blood from subject', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING process_type_id INTO v_process_type_draw;

  INSERT INTO app_provenance.process_types (type_key, display_name, description, metadata, created_by)
  VALUES
    ('plasma_processing', 'Plasma Processing', 'Spin down plasma and aliquot', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING process_type_id INTO v_process_type_processing;

  INSERT INTO app_provenance.process_types (type_key, display_name, description, metadata, created_by)
  VALUES
    ('sequencing_run', 'Sequencing Run', 'Next-generation sequencing run', jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name
  RETURNING process_type_id INTO v_process_type_sequencing;

  ---------------------------------------------------------------------------
  -- Storage nodes
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.storage_nodes (
    node_key,
    node_type,
    display_name,
    description,
    scope_id,
    metadata,
    created_by
  )
  VALUES
    ('facility:main_biolab', 'facility', 'Main BioLab', 'Primary laboratory building', v_facility_scope, jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (node_key) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        scope_id = EXCLUDED.scope_id
  RETURNING storage_node_id INTO v_facility_node;

  INSERT INTO app_provenance.storage_nodes (
    node_key,
    node_type,
    display_name,
    description,
    parent_storage_node_id,
    scope_id,
    metadata,
    created_by
  )
  VALUES
    ('unit:freezer_nf1', 'unit', 'Freezer NF-1', 'Ultra-low freezer (-80°C)', v_facility_node, v_facility_scope, jsonb_build_object('seed','phase2-redux','temperature_c',-80), v_admin)
  ON CONFLICT (node_key) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        parent_storage_node_id = EXCLUDED.parent_storage_node_id
  RETURNING storage_node_id INTO v_freezer_node;

  INSERT INTO app_provenance.storage_nodes (
    node_key,
    node_type,
    display_name,
    description,
    parent_storage_node_id,
    scope_id,
    metadata,
    created_by
  )
  VALUES
    ('sublocation:freezer_nf1:shelf_a', 'sublocation', 'Shelf A', 'Top shelf of Freezer NF-1', v_freezer_node, v_facility_scope, jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (node_key) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        parent_storage_node_id = EXCLUDED.parent_storage_node_id
  RETURNING storage_node_id INTO v_shelf_node;

  ---------------------------------------------------------------------------
  -- Process instances
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.process_instances (
    process_type_id,
    process_identifier,
    name,
    status,
    started_at,
    completed_at,
    executed_by,
    metadata,
    created_by
  )
  VALUES
    (v_process_type_draw, 'DRAW-0001', 'Blood Draw 0001', 'completed', clock_timestamp() - interval '14 days', clock_timestamp() - interval '14 days' + interval '2 hours', v_operator, jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (process_identifier) DO UPDATE
    SET process_type_id = EXCLUDED.process_type_id
  RETURNING process_instance_id INTO v_process_draw;

  INSERT INTO app_provenance.process_instances (
    process_type_id,
    process_identifier,
    name,
    status,
    started_at,
    completed_at,
    executed_by,
    metadata,
    created_by
  )
  VALUES
    (v_process_type_processing, 'PROC-PLASMA-0001', 'Plasma Processing 0001', 'completed', clock_timestamp() - interval '13 days', clock_timestamp() - interval '13 days' + interval '3 hours', v_operator, jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (process_identifier) DO UPDATE
    SET process_type_id = EXCLUDED.process_type_id
  RETURNING process_instance_id INTO v_process_processing;

  INSERT INTO app_provenance.process_instances (
    process_type_id,
    process_identifier,
    name,
    status,
    started_at,
    completed_at,
    executed_by,
    metadata,
    created_by
  )
  VALUES
    (v_process_type_sequencing, 'SEQ-RUN-0001', 'Sequencing Run 0001', 'completed', clock_timestamp() - interval '6 days', clock_timestamp() - interval '6 days' + interval '1 day', v_operator, jsonb_build_object('seed','phase2-redux'), v_admin)
  ON CONFLICT (process_identifier) DO UPDATE
    SET process_type_id = EXCLUDED.process_type_id
  RETURNING process_instance_id INTO v_process_sequencing;

  ---------------------------------------------------------------------------
  -- Artefacts
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.artefacts (
    artefact_type_id,
    name,
    external_identifier,
    status,
    is_virtual,
    metadata,
    created_by,
    origin_process_instance_id
  )
  VALUES
    (v_subject_type, 'Subject GP-001', 'SUBJ-GP-001', 'active', false, jsonb_build_object('seed','phase2-redux','subject_code','GP-001'), v_admin, v_process_draw)
  ON CONFLICT (external_identifier) DO UPDATE
    SET artefact_type_id = EXCLUDED.artefact_type_id
  RETURNING artefact_id INTO v_subject;

  INSERT INTO app_provenance.artefacts (
    artefact_type_id,
    name,
    external_identifier,
    status,
    quantity,
    quantity_unit,
    metadata,
    created_by,
    origin_process_instance_id
  )
  VALUES
    (v_material_type, 'Plasma Aliquot GP-001-A', 'SAMPLE-GP-001-A', 'active', 1.2, 'mL', jsonb_build_object('seed','phase2-redux','lot','ALIQUOT-A'), v_admin, v_process_processing)
  ON CONFLICT (external_identifier) DO UPDATE
    SET artefact_type_id = EXCLUDED.artefact_type_id
  RETURNING artefact_id INTO v_sample;

  INSERT INTO app_provenance.artefacts (
    artefact_type_id,
    name,
    external_identifier,
    status,
    quantity,
    quantity_unit,
    metadata,
    created_by
  )
  VALUES
    (v_reagent_type, 'Plasma Prep Buffer Lot 42', 'REAGENT-BUF-042', 'active', 500, 'mL', jsonb_build_object('seed','phase2-redux','lot','BUF-42'), v_admin)
  ON CONFLICT (external_identifier) DO UPDATE
    SET artefact_type_id = EXCLUDED.artefact_type_id
  RETURNING artefact_id INTO v_reagent;

  INSERT INTO app_provenance.artefacts (
    artefact_type_id,
    name,
    external_identifier,
    status,
    metadata,
    created_by
  )
  VALUES
    (v_container_plate_type, '96-Well Plate PLT-0007', 'PLATE-0007', 'active', jsonb_build_object('seed','phase2-redux','manufacturer','LabPlates Inc.'), v_admin)
  ON CONFLICT (external_identifier) DO UPDATE
    SET artefact_type_id = EXCLUDED.artefact_type_id
  RETURNING artefact_id INTO v_plate_container;

  INSERT INTO app_provenance.artefacts (
    artefact_type_id,
    name,
    external_identifier,
    status,
    metadata,
    created_by
  )
  VALUES
    (v_container_cryovial_type, 'Cryovial CV-8831', 'CRYO-8831', 'active', jsonb_build_object('seed','phase2-redux','barcode','CRYO8831'), v_admin)
  ON CONFLICT (external_identifier) DO UPDATE
    SET artefact_type_id = EXCLUDED.artefact_type_id
  RETURNING artefact_id INTO v_vial_container;

  INSERT INTO app_provenance.artefacts (
    artefact_type_id,
    name,
    external_identifier,
    status,
    is_virtual,
    metadata,
    created_by,
    origin_process_instance_id
  )
  VALUES
    (v_data_product_type, 'FASTQ Bundle GP-001-A', 'DATA-GP-001-A', 'active', true, jsonb_build_object('seed','phase2-redux','uri','s3://pilot-datasets/gp-001-a'), v_admin, v_process_sequencing)
  ON CONFLICT (external_identifier) DO UPDATE
    SET artefact_type_id = EXCLUDED.artefact_type_id
  RETURNING artefact_id INTO v_data_product;

  INSERT INTO app_provenance.artefacts (
    artefact_type_id,
    name,
    external_identifier,
    status,
    metadata,
    created_by,
    origin_process_instance_id
  )
  VALUES
    (v_instrument_run_type, 'NovaSeq Run NV-221', 'RUN-NV-221', 'completed', jsonb_build_object('seed','phase2-redux','instrument','NovaSeq 6000'), v_admin, v_process_sequencing)
  ON CONFLICT (external_identifier) DO UPDATE
    SET artefact_type_id = EXCLUDED.artefact_type_id
  RETURNING artefact_id INTO v_instrument_run;

  ---------------------------------------------------------------------------
  -- Artefact scopes
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
  VALUES
    (v_subject, v_project_scope, 'primary', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_sample, v_dataset_scope, 'primary', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_sample, v_facility_scope, 'facility', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_reagent, v_facility_scope, 'primary', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_plate_container, v_facility_scope, 'primary', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_vial_container, v_facility_scope, 'primary', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_data_product, v_dataset_scope, 'primary', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_data_product, v_project_scope, 'supplementary', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_instrument_run, v_workflow_scope, 'primary', v_admin, jsonb_build_object('seed','phase2-redux'))
  ON CONFLICT DO NOTHING;

  ---------------------------------------------------------------------------
  -- Process scopes
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.process_scopes (process_instance_id, scope_id, relationship, assigned_by, metadata)
  VALUES
    (v_process_draw, v_project_scope, 'primary', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_process_processing, v_dataset_scope, 'primary', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_process_processing, v_facility_scope, 'facility', v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_process_sequencing, v_workflow_scope, 'primary', v_admin, jsonb_build_object('seed','phase2-redux'))
  ON CONFLICT DO NOTHING;

  ---------------------------------------------------------------------------
  -- Trait values
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.artefact_trait_values (artefact_id, trait_id, value, recorded_by, metadata)
  VALUES
    (v_sample, v_trait_divisible, to_jsonb(true), v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_sample, v_trait_storage_temp, to_jsonb(-80), v_admin, jsonb_build_object('seed','phase2-redux')),
    (v_reagent, v_trait_concentration, to_jsonb(25), v_admin, jsonb_build_object('seed','phase2-redux'))
  ON CONFLICT DO NOTHING;

  ---------------------------------------------------------------------------
  -- Container slot definitions and slots
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.container_slot_definitions (artefact_type_id, slot_name, display_name, position, metadata)
  VALUES
    (v_container_plate_type, 'A1', 'A1', jsonb_build_object('row','A','column',1), jsonb_build_object('seed','phase2-redux')),
    (v_container_plate_type, 'A2', 'A2', jsonb_build_object('row','A','column',2), jsonb_build_object('seed','phase2-redux'))
  ON CONFLICT (artefact_type_id, slot_name) DO NOTHING;

  INSERT INTO app_provenance.container_slots (container_artefact_id, slot_definition_id, slot_name, display_name, position, metadata)
  SELECT
    v_plate_container,
    csd.slot_definition_id,
    csd.slot_name,
    csd.display_name,
    csd.position,
    jsonb_build_object('seed','phase2-redux')
  FROM app_provenance.container_slot_definitions csd
  WHERE csd.artefact_type_id = v_container_plate_type
    AND NOT EXISTS (
      SELECT 1
      FROM app_provenance.container_slots cs
      WHERE cs.container_artefact_id = v_plate_container
        AND cs.slot_name = csd.slot_name
    );

  SELECT container_slot_id INTO v_slot_a1
  FROM app_provenance.container_slots
  WHERE container_artefact_id = v_plate_container AND slot_name = 'A1'
  LIMIT 1;

  SELECT container_slot_id INTO v_slot_a2
  FROM app_provenance.container_slots
  WHERE container_artefact_id = v_plate_container AND slot_name = 'A2'
  LIMIT 1;

  ---------------------------------------------------------------------------
  -- Process IO
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.process_io (
    process_instance_id,
    artefact_id,
    direction,
    io_role,
    is_primary,
    metadata
  )
  VALUES
    (v_process_draw, v_subject, 'output', 'collected_subject', true, jsonb_build_object('seed','phase2-redux')),
    (v_process_processing, v_subject, 'input', 'whole_blood', true, jsonb_build_object('seed','phase2-redux')),
    (v_process_processing, v_reagent, 'input', 'buffer', false, jsonb_build_object('seed','phase2-redux')),
    (v_process_processing, v_sample, 'output', 'plasma_aliquot', true, jsonb_build_object('seed','phase2-redux')),
    (v_process_sequencing, v_sample, 'input', 'library', true, jsonb_build_object('seed','phase2-redux')),
    (v_process_sequencing, v_data_product, 'output', 'sequence_bundle', true, jsonb_build_object('seed','phase2-redux')),
    (v_process_sequencing, v_instrument_run, 'output', 'instrument_run', false, jsonb_build_object('seed','phase2-redux'))
  ON CONFLICT DO NOTHING;

  ---------------------------------------------------------------------------
  -- Artefact relationships (lineage)
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.artefact_relationships (
    parent_artefact_id,
    child_artefact_id,
    relationship_type,
    process_instance_id,
    metadata,
    created_by
  )
  VALUES
    (v_subject, v_sample, 'derived_from', v_process_processing, jsonb_build_object('seed','phase2-redux','method','plasma_spin'), v_admin),
    (v_sample, v_data_product, 'produced_output', v_process_sequencing, jsonb_build_object('seed','phase2-redux','format','FASTQ'), v_admin)
  ON CONFLICT DO NOTHING;

  ---------------------------------------------------------------------------
  -- Container assignments and storage events
  ---------------------------------------------------------------------------

  UPDATE app_provenance.artefacts
  SET
    container_artefact_id = v_plate_container,
    container_slot_id = v_slot_a1,
    metadata = metadata || jsonb_build_object('well_volume_ul', 1200)
  WHERE artefact_id = v_sample;

  UPDATE app_provenance.artefacts
  SET
    container_artefact_id = v_plate_container,
    container_slot_id = v_slot_a2,
    metadata = metadata || jsonb_build_object('well_volume_ul', 20000)
  WHERE artefact_id = v_reagent;

  INSERT INTO app_provenance.artefact_storage_events (
    artefact_id,
    from_storage_node_id,
    to_storage_node_id,
    event_type,
    occurred_at,
    actor_id,
    process_instance_id,
    reason,
    metadata
  )
  VALUES
    (v_plate_container, NULL, v_shelf_node, 'check_in', clock_timestamp() - interval '15 days', v_operator, v_process_processing, 'Initial placement after processing', jsonb_build_object('seed','phase2-redux')),
    (v_sample, NULL, v_shelf_node, 'check_in', clock_timestamp() - interval '12 days', v_operator, v_process_processing, 'Assigned to shelf', jsonb_build_object('seed','phase2-redux')),
    (v_sample, v_shelf_node, NULL, 'check_out', clock_timestamp() - interval '6 days' - interval '2 hours', v_operator, v_process_sequencing, 'Pulled for sequencing run', jsonb_build_object('seed','phase2-redux')),
    (v_sample, NULL, v_shelf_node, 'check_in', clock_timestamp() - interval '5 days', v_operator, v_process_sequencing, 'Returned post sequencing', jsonb_build_object('seed','phase2-redux')),
    (v_data_product, NULL, NULL, 'register', clock_timestamp() - interval '6 days', v_operator, v_process_sequencing, 'Registered logical storage location', jsonb_build_object('seed','phase2-redux','uri','s3://pilot-datasets/gp-001-a'))
  ON CONFLICT DO NOTHING;

  PERFORM app_security.finish_transaction_context(v_txn, 'committed', 'phase2 redux seed');
END;
$$;

-- migrate:down
DO $$
BEGIN
  DELETE FROM app_provenance.artefact_storage_events WHERE metadata ->> 'seed' = 'phase2-redux';
  UPDATE app_provenance.artefacts
  SET container_slot_id = NULL,
      container_artefact_id = NULL
  WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.container_slots WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.container_slot_definitions WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.artefact_trait_values WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.artefact_relationships WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.process_io WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.process_scopes WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.artefact_scopes WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.artefacts WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.process_instances WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.process_types WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.artefact_traits WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.artefact_types WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_provenance.storage_nodes WHERE metadata ->> 'seed' = 'phase2-redux';

  DELETE FROM app_security.scope_memberships WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_security.scopes WHERE metadata ->> 'seed' = 'phase2-redux';
  DELETE FROM app_security.scope_role_inheritance
  WHERE (parent_scope_type, child_scope_type, parent_role_name, child_role_name) IN (
    ('project','dataset','app_admin','app_admin'),
    ('project','dataset','app_operator','app_operator'),
    ('project','dataset','app_researcher','app_researcher'),
    ('project','dataset','app_automation','app_automation'),
    ('dataset','workflow_run','app_admin','app_admin'),
    ('dataset','workflow_run','app_operator','app_operator'),
    ('dataset','workflow_run','app_researcher','app_researcher'),
    ('dataset','workflow_run','app_automation','app_automation'),
    ('project','facility','app_admin','app_admin'),
    ('project','facility','app_operator','app_operator')
  );
END;
$$;
