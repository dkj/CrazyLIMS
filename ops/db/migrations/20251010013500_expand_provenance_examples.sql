-- migrate:up
DO $$
DECLARE
  v_seed_tag constant text := 'redux-provenance';
  v_admin uuid;
  v_operator uuid;
  v_alice uuid;
  v_carol uuid;
  v_diego uuid;
  v_bob uuid;
  v_external uuid;
  v_automation uuid;
  v_txn uuid;
  v_facility_scope uuid;
  v_project_prj001 uuid;
  v_project_prj002 uuid;
  v_project_prj003 uuid;
  v_facility_node uuid;
  v_freezer_node uuid;
  v_shelf_node uuid;
  v_type_id uuid;
  v_project_id uuid;
  v_creator_id uuid;
  v_sample_id uuid;
  v_container_id uuid;
  v_external_id text;
  type_rec RECORD;
  container_type_rec RECORD;
  sample_rec RECORD;
  rel_rec RECORD;
  container_rec RECORD;
  assign_rec RECORD;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';
  SELECT id INTO v_operator FROM app_core.users WHERE email = 'ops@example.org';
  SELECT id INTO v_alice FROM app_core.users WHERE email = 'alice@example.org';

  IF v_admin IS NULL THEN
    RAISE NOTICE 'Skipping provenance seed expansion: admin user missing.';
    RETURN;
  END IF;

  v_txn := app_security.start_transaction_context(
    p_actor_id => v_admin,
    p_actor_identity => 'migration:redux_provenance_seed',
    p_effective_roles => ARRAY['app_admin'],
    p_client_app => 'dbmate:migration',
    p_metadata => jsonb_build_object('seed', v_seed_tag)
  );

  PERFORM set_config('app.actor_id', v_admin::text, true);
  PERFORM set_config('app.actor_identity', 'migration:redux_provenance_seed', true);
  PERFORM set_config('app.roles', 'app_admin', true);

  UPDATE app_security.transaction_contexts
  SET actor_id = v_admin,
      actor_identity = 'migration:redux_provenance_seed'
  WHERE txn_id = v_txn;

  ---------------------------------------------------------------------------
  -- Ensure researcher personas exist
  ---------------------------------------------------------------------------

  SELECT id INTO v_carol FROM app_core.users WHERE email = 'carol@example.org';
  IF v_carol IS NULL THEN
    INSERT INTO app_core.users (external_id, email, full_name, default_role, metadata, created_by)
    VALUES ('urn:app:user:carol', 'carol@example.org', 'Carol Cellwright', 'app_researcher', jsonb_build_object('seed', v_seed_tag), v_admin)
    RETURNING id INTO v_carol;
  ELSE
    UPDATE app_core.users
    SET full_name = 'Carol Cellwright',
        default_role = 'app_researcher',
        is_active = true
    WHERE id = v_carol;
  END IF;

  SELECT id INTO v_diego FROM app_core.users WHERE email = 'diego@example.org';
  IF v_diego IS NULL THEN
    INSERT INTO app_core.users (external_id, email, full_name, default_role, metadata, created_by)
    VALUES ('urn:app:user:diego', 'diego@example.org', 'Diego Datawright', 'app_researcher', jsonb_build_object('seed', v_seed_tag), v_admin)
    RETURNING id INTO v_diego;
  ELSE
    UPDATE app_core.users
    SET full_name = 'Diego Datawright',
        default_role = 'app_researcher',
        is_active = true
    WHERE id = v_diego;
  END IF;

  SELECT id INTO v_bob FROM app_core.users WHERE email = 'bob@example.org';
  IF v_bob IS NULL THEN
    INSERT INTO app_core.users (external_id, email, full_name, default_role, metadata, created_by)
    VALUES ('urn:app:user:bob', 'bob@example.org', 'Bob Neutralizer', 'app_researcher', jsonb_build_object('seed', v_seed_tag), v_admin)
    RETURNING id INTO v_bob;
  ELSE
    UPDATE app_core.users
    SET full_name = 'Bob Neutralizer',
        default_role = 'app_researcher',
        is_active = true
    WHERE id = v_bob;
  END IF;

  SELECT id INTO v_external FROM app_core.users WHERE email = 'external@example.org';
  IF v_external IS NULL THEN
    INSERT INTO app_core.users (external_id, email, full_name, default_role, metadata, created_by)
    VALUES ('urn:app:user:external', 'external@example.org', 'External Collaborator', 'app_external', jsonb_build_object('seed', v_seed_tag), v_admin)
    RETURNING id INTO v_external;
  ELSE
    UPDATE app_core.users
    SET full_name = 'External Collaborator',
        default_role = 'app_external',
        is_active = true
    WHERE id = v_external;
  END IF;

  SELECT id INTO v_automation FROM app_core.users WHERE email = 'automation@example.org';
  IF v_automation IS NULL THEN
    INSERT INTO app_core.users (external_id, email, full_name, default_role, is_service_account, metadata, created_by)
    VALUES ('urn:app:user:automation', 'automation@example.org', 'Automation Service', 'app_automation', true, jsonb_build_object('seed', v_seed_tag), v_admin)
    RETURNING id INTO v_automation;
  ELSE
    UPDATE app_core.users
    SET full_name = 'Automation Service',
        default_role = 'app_automation',
        is_service_account = true,
        is_active = true
    WHERE id = v_automation;
  END IF;

  INSERT INTO app_core.user_roles (user_id, role_name, granted_by)
  VALUES
    (v_carol, 'app_researcher', v_admin),
    (v_diego, 'app_researcher', v_admin),
    (v_bob, 'app_researcher', v_admin),
    (v_external, 'app_external', v_admin),
    (v_automation, 'app_automation', v_admin)
  ON CONFLICT (user_id, role_name) DO NOTHING;

  ---------------------------------------------------------------------------
  -- Ensure facility and project scopes exist
  ---------------------------------------------------------------------------

  SELECT scope_id INTO v_facility_scope FROM app_security.scopes WHERE scope_key = 'facility:main_biolab';
  IF v_facility_scope IS NULL THEN
    INSERT INTO app_security.scopes (
      scope_key,
      scope_type,
      display_name,
      description,
      metadata,
      created_by
    )
    VALUES (
      'facility:main_biolab',
      'facility',
      'Main BioLab Facility',
      'Legacy facility bootstrap for provenance demos',
      jsonb_build_object('seed', v_seed_tag),
      v_admin
    )
    RETURNING scope_id INTO v_facility_scope;
  END IF;

  SELECT scope_id INTO v_project_prj001 FROM app_security.scopes WHERE scope_key = 'project:prj-001';
  IF v_project_prj001 IS NULL THEN
    INSERT INTO app_security.scopes (
      scope_key,
      scope_type,
      display_name,
      description,
      metadata,
      created_by
    )
    VALUES (
      'project:prj-001',
      'project',
      'PRJ-001 Organoid Therapeutics',
      'Legacy project covering organoid and PBMC workflows',
      jsonb_build_object('seed', v_seed_tag, 'code', 'PRJ-001'),
      v_admin
    )
    RETURNING scope_id INTO v_project_prj001;
  END IF;

  SELECT scope_id INTO v_project_prj002 FROM app_security.scopes WHERE scope_key = 'project:prj-002';
  IF v_project_prj002 IS NULL THEN
    INSERT INTO app_security.scopes (
      scope_key,
      scope_type,
      display_name,
      description,
      metadata,
      created_by
    )
    VALUES (
      'project:prj-002',
      'project',
      'PRJ-002 Multi-Omics Campaign',
      'Legacy project focused on multi-omic sequencing workflows',
      jsonb_build_object('seed', v_seed_tag, 'code', 'PRJ-002'),
      v_admin
    )
    RETURNING scope_id INTO v_project_prj002;
  END IF;

  SELECT scope_id INTO v_project_prj003 FROM app_security.scopes WHERE scope_key = 'project:prj-003';
  IF v_project_prj003 IS NULL THEN
    INSERT INTO app_security.scopes (
      scope_key,
      scope_type,
      display_name,
      description,
      metadata,
      created_by
    )
    VALUES (
      'project:prj-003',
      'project',
      'PRJ-003 Neutralization Panel',
      'Legacy project representing neutralization assay panels',
      jsonb_build_object('seed', v_seed_tag, 'code', 'PRJ-003'),
      v_admin
    )
    RETURNING scope_id INTO v_project_prj003;
  END IF;

  ---------------------------------------------------------------------------
  -- Ensure personas are members of their projects
  ---------------------------------------------------------------------------

  IF v_project_prj001 IS NOT NULL THEN
    INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, granted_by, metadata)
    VALUES (v_project_prj001, v_carol, 'app_researcher', v_admin, jsonb_build_object('seed', v_seed_tag, 'relationship', 'member'))
    ON CONFLICT DO NOTHING;

    INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, granted_by, metadata)
    VALUES (v_project_prj001, v_diego, 'app_researcher', v_admin, jsonb_build_object('seed', v_seed_tag, 'relationship', 'viewer'))
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_project_prj002 IS NOT NULL THEN
    INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, granted_by, metadata)
    VALUES (v_project_prj002, v_carol, 'app_researcher', v_admin, jsonb_build_object('seed', v_seed_tag, 'relationship', 'member'))
    ON CONFLICT DO NOTHING;

    INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, granted_by, metadata)
    VALUES (v_project_prj002, v_diego, 'app_researcher', v_admin, jsonb_build_object('seed', v_seed_tag, 'relationship', 'member'))
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_project_prj003 IS NOT NULL THEN
    INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, granted_by, metadata)
    VALUES (v_project_prj003, v_bob, 'app_researcher', v_admin, jsonb_build_object('seed', v_seed_tag, 'relationship', 'member'))
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_alice IS NOT NULL THEN
    IF v_project_prj001 IS NOT NULL THEN
      INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, granted_by, metadata)
      VALUES (v_project_prj001, v_alice, 'app_researcher', v_admin, jsonb_build_object('seed', v_seed_tag, 'relationship', 'member'))
      ON CONFLICT DO NOTHING;
    END IF;

    IF v_project_prj002 IS NOT NULL THEN
      INSERT INTO app_security.scope_memberships (scope_id, user_id, role_name, granted_by, metadata)
      VALUES (v_project_prj002, v_alice, 'app_researcher', v_admin, jsonb_build_object('seed', v_seed_tag, 'relationship', 'member'))
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  ---------------------------------------------------------------------------
  -- Artefact trait catalog and process types for seeded examples
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.artefact_traits (trait_key, display_name, data_type, description, metadata, created_by)
  VALUES
    ('volume_ml', 'Volume (mL)', 'numeric', 'Volume of material in milliliters', jsonb_build_object('seed', v_seed_tag), v_admin)
  ON CONFLICT (trait_key) DO UPDATE
    SET display_name = EXCLUDED.display_name;

  INSERT INTO app_provenance.artefact_traits (trait_key, display_name, data_type, description, metadata, created_by)
  VALUES
    ('cell_count', 'Cell Count', 'integer', 'Approximate viable cell count', jsonb_build_object('seed', v_seed_tag), v_admin)
  ON CONFLICT (trait_key) DO UPDATE
    SET display_name = EXCLUDED.display_name;

  INSERT INTO app_provenance.artefact_traits (trait_key, display_name, data_type, description, metadata, created_by)
  VALUES
    ('divisible', 'Divisible', 'boolean', 'Whether the artefact can be split without consuming identity', jsonb_build_object('seed', v_seed_tag), v_admin)
  ON CONFLICT (trait_key) DO UPDATE
    SET display_name = EXCLUDED.display_name;

  INSERT INTO app_provenance.artefact_traits (trait_key, display_name, data_type, description, metadata, created_by)
  VALUES
    ('storage_temperature_c', 'Storage Temperature (°C)', 'numeric', 'Nominal storage temperature requirement', jsonb_build_object('seed', v_seed_tag), v_admin)
  ON CONFLICT (trait_key) DO UPDATE
    SET display_name = EXCLUDED.display_name;

  INSERT INTO app_provenance.artefact_traits (trait_key, display_name, data_type, description, metadata, created_by)
  VALUES
    ('concentration_mg_ml', 'Concentration (mg/mL)', 'numeric', 'Mass concentration for material or reagent', jsonb_build_object('seed', v_seed_tag), v_admin)
  ON CONFLICT (trait_key) DO UPDATE
    SET display_name = EXCLUDED.display_name;

  ---------------------------------------------------------------------------
  -- Process types
  ---------------------------------------------------------------------------

  INSERT INTO app_provenance.process_types (type_key, display_name, description, metadata, created_by)
  VALUES
    ('blood_draw', 'Blood Draw', 'Collection of whole blood from subject', jsonb_build_object('seed', v_seed_tag), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name;

  INSERT INTO app_provenance.process_types (type_key, display_name, description, metadata, created_by)
  VALUES
    ('plasma_processing', 'Plasma Processing', 'Spin down plasma and aliquot', jsonb_build_object('seed', v_seed_tag), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name;

  INSERT INTO app_provenance.process_types (type_key, display_name, description, metadata, created_by)
  VALUES
    ('sequencing_run', 'Sequencing Run', 'Next-generation sequencing run', jsonb_build_object('seed', v_seed_tag), v_admin)
  ON CONFLICT (type_key) DO UPDATE
    SET display_name = EXCLUDED.display_name;

  ---------------------------------------------------------------------------
  -- Material and container artefact types required for the legacy data
  ---------------------------------------------------------------------------

  FOR type_rec IN
    SELECT *
    FROM (
      VALUES
        ('blood_draw','Whole Blood Draw','material','Whole blood collected from participant'),
        ('buffy_coat','Buffy Coat Fraction','material','Buffy coat layer following centrifugation'),
        ('plasma_fraction','Plasma Fraction','material','Plasma fraction prepared for downstream assays'),
        ('metabolite_extract','Metabolite Extract','material','Metabolite-rich extract for LCMS'),
        ('dna_extract','DNA Extract','material','Isolated genomic DNA aliquot'),
        ('cell','Cell Suspension','material','General cell suspension'),
        ('t_cell_enriched','T Cell Enriched Fraction','material','T cell enriched cell suspension'),
        ('rna_extract','RNA Extract','material','Isolated RNA material'),
        ('protein_lysate','Protein Lysate','material','Protein lysate derived from cells'),
        ('multiomics_library','Multi-Omics Library','material','Library prepared for multi-omic sequencing'),
        ('organoid','Organoid Culture','material','Organoid culture batch'),
        ('organoid_passage','Organoid Passage','material','Organoid culture passage'),
        ('analysis_panel','Analysis Panel','material','Analyte panel prepared for LCMS run'),
        ('qc_mix','QC Mix','material','Quality control spike-in mixture'),
        ('pooled_library','Sequencing Pool','material','Pooled sequencing library'),
        ('library','Sequencing Library','material','Indexed sequencing library'),
        ('serum_control','Serum Control','material','Serum control sample'),
        ('neutralizing_panel','Neutralizing Panel','material','Neutralizing assay panel sample')
    ) AS t(type_key, display_name, kind, description)
  LOOP
    INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
    VALUES (
      type_rec.type_key,
      type_rec.display_name,
      type_rec.kind,
      type_rec.description,
      jsonb_build_object('seed', v_seed_tag),
      v_admin
    )
    ON CONFLICT (type_key) DO NOTHING;

    -- Update description if we inserted with a generic label
    UPDATE app_provenance.artefact_types
    SET display_name = type_rec.display_name,
        description = COALESCE(NULLIF(description, ''), type_rec.description)
    WHERE type_key = type_rec.type_key;
  END LOOP;

  -- Ensure container types exist (fall back to defaults if already seeded elsewhere)
  FOR container_type_rec IN
    SELECT *
    FROM (
      VALUES
        ('container_generic','Container','container','Generic container artefact'),
        ('container_plate_96','96 Well Plate','container','Standard 96-well SBS plate'),
        ('container_cryovial_2ml','2 mL Cryovial','container','Cryovial for frozen aliquots')
    ) AS t(type_key, display_name, kind, description)
  LOOP
    INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
    VALUES (
      container_type_rec.type_key,
      container_type_rec.display_name,
      container_type_rec.kind,
      container_type_rec.description,
      jsonb_build_object('seed', v_seed_tag),
      v_admin
    )
    ON CONFLICT (type_key) DO NOTHING;
  END LOOP;

  ---------------------------------------------------------------------------
  -- Insert artefacts representing the legacy sample set
  ---------------------------------------------------------------------------

  CREATE TEMP TABLE tmp_seed_samples (
    name text PRIMARY KEY,
    artefact_id uuid
  ) ON COMMIT DROP;

  FOR sample_rec IN
    SELECT *
    FROM (
      VALUES
        ('Participant 001 Blood Draw', 'blood_draw', 'project:prj-001', 'alice@example.org', 45, 'active'),
        ('Participant 001 Blood Draw - Buffy Coat Fraction', 'buffy_coat', 'project:prj-001', 'alice@example.org', 44, 'active'),
        ('Participant 001 Blood Draw - Plasma Fraction', 'plasma_fraction', 'project:prj-001', 'alice@example.org', 44, 'active'),
        ('Participant 001 Blood Draw - Plasma Fraction - LCMS Prep', 'metabolite_extract', 'project:prj-002', 'diego@example.org', 40, 'active'),
        ('DNA Intake Batch 001 - Donor 101', 'dna_extract', 'project:prj-001', 'alice@example.org', 38, 'active'),
        ('DNA Intake Batch 001 - Donor 102', 'dna_extract', 'project:prj-001', 'alice@example.org', 38, 'active'),
        ('DNA Intake Batch 001 - Donor 103', 'dna_extract', 'project:prj-001', 'alice@example.org', 38, 'active'),
        ('DNA Intake Batch 002 - Donor 201', 'dna_extract', 'project:prj-001', 'alice@example.org', 31, 'active'),
        ('DNA Intake Batch 002 - Donor 202', 'dna_extract', 'project:prj-001', 'alice@example.org', 31, 'active'),
        ('DNA Intake Batch 002 - Donor 203', 'dna_extract', 'project:prj-001', 'alice@example.org', 31, 'active'),
        ('PBMC Batch 001', 'cell', 'project:prj-001', 'carol@example.org', 28, 'active'),
        ('PBMC Aliquot A', 'cell', 'project:prj-001', 'carol@example.org', 27, 'active'),
        ('PBMC Batch 001 - Aliquot A', 'cell', 'project:prj-001', 'carol@example.org', 27, 'active'),
        ('PBMC Batch 001 - Aliquot A - Cryovial 1', 'cell', 'project:prj-001', 'carol@example.org', 26, 'active'),
        ('PBMC Batch 001 - Aliquot B', 'cell', 'project:prj-001', 'carol@example.org', 27, 'active'),
        ('PBMC Batch 001 - Aliquot B - T Cell Enrichment', 't_cell_enriched', 'project:prj-001', 'carol@example.org', 25, 'active'),
        ('PBMC Batch 001 - T Cell RNA', 'rna_extract', 'project:prj-001', 'carol@example.org', 24, 'active'),
        ('PBMC Batch 001 - T Cell Protein Lysate', 'protein_lysate', 'project:prj-001', 'carol@example.org', 24, 'active'),
        ('PBMC Batch 001 - Multi-Omics Library', 'multiomics_library', 'project:prj-001', 'carol@example.org', 23, 'active'),
        ('Organoid Expansion Batch RDX-01', 'organoid', 'project:prj-002', 'carol@example.org', 21, 'active'),
        ('Organoid Expansion Batch RDX-01 Passage 1', 'organoid_passage', 'project:prj-002', 'carol@example.org', 20, 'active'),
        ('Organoid Expansion Batch RDX-01 Passage 1 - RNA Extract', 'rna_extract', 'project:prj-002', 'carol@example.org', 19, 'active'),
        ('Organoid Expansion Batch RDX-01 Passage 1 - Protein Lysate', 'protein_lysate', 'project:prj-002', 'carol@example.org', 19, 'active'),
        ('Organoid Expansion Batch RDX-01 Cryo Backup', 'organoid', 'project:prj-002', 'carol@example.org', 19, 'active'),
        ('LCMS Run 042 Analyte Panel', 'analysis_panel', 'project:prj-002', 'diego@example.org', 18, 'active'),
        ('Viral Challenge Mix Lot 12', 'qc_mix', 'project:prj-002', 'diego@example.org', 17, 'active'),
        ('Sequencing Pool Run 001', 'pooled_library', 'project:prj-002', 'diego@example.org', 16, 'active'),
        ('Indexed Library Batch 001 - Donor 101', 'library', 'project:prj-002', 'diego@example.org', 15, 'active'),
        ('Indexed Library Batch 001 - Donor 102', 'library', 'project:prj-002', 'diego@example.org', 15, 'active'),
        ('Indexed Library Batch 001 - Donor 103', 'library', 'project:prj-002', 'diego@example.org', 15, 'active'),
        ('Indexed Library Batch 002 - Donor 201', 'library', 'project:prj-002', 'diego@example.org', 14, 'active'),
        ('Indexed Library Batch 002 - Donor 202', 'library', 'project:prj-002', 'diego@example.org', 14, 'active'),
        ('Indexed Library Batch 002 - Donor 203', 'library', 'project:prj-002', 'diego@example.org', 14, 'active'),
        ('Serum QC Control Sample', 'serum_control', 'project:prj-002', 'diego@example.org', 12, 'active'),
        ('Neutralizing Panel B', 'neutralizing_panel', 'project:prj-003', 'bob@example.org', 10, 'active')
    ) AS s(name, type_key, project_key, creator_email, age_days, sample_status)
  LOOP
    SELECT artefact_type_id INTO v_type_id
    FROM app_provenance.artefact_types
    WHERE type_key = sample_rec.type_key;

    IF v_type_id IS NULL THEN
      RAISE NOTICE 'Skipping sample % because artefact type % is missing', sample_rec.name, sample_rec.type_key;
      CONTINUE;
    END IF;

    SELECT scope_id INTO v_project_id
    FROM app_security.scopes
    WHERE scope_key = sample_rec.project_key;

    IF v_project_id IS NULL THEN
      RAISE NOTICE 'Skipping sample % because project scope % is missing', sample_rec.name, sample_rec.project_key;
      CONTINUE;
    END IF;

    SELECT id INTO v_creator_id
    FROM app_core.users
    WHERE email = sample_rec.creator_email;

    IF v_creator_id IS NULL THEN
      v_creator_id := v_admin;
    END IF;

    v_external_id := 'seed:sample:' || substring(encode(digest(sample_rec.name || ':' || sample_rec.type_key, 'sha256'), 'hex'), 1, 24);

    BEGIN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id,
        name,
        external_identifier,
        status,
        metadata,
        created_by
      )
      VALUES (
        v_type_id,
        sample_rec.name,
        v_external_id,
        sample_rec.sample_status,
        jsonb_build_object('seed', v_seed_tag, 'project_scope', sample_rec.project_key),
        v_creator_id
      )
      RETURNING artefact_id INTO v_sample_id;
    EXCEPTION
      WHEN unique_violation THEN
        SELECT artefact_id INTO v_sample_id
        FROM app_provenance.artefacts
        WHERE external_identifier = v_external_id;
    END;

    IF v_sample_id IS NULL THEN
      CONTINUE;
    END IF;

    INSERT INTO tmp_seed_samples (name, artefact_id)
    VALUES (sample_rec.name, v_sample_id)
    ON CONFLICT (name) DO UPDATE
      SET artefact_id = EXCLUDED.artefact_id;

    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
    VALUES (v_sample_id, v_project_id, 'primary', v_admin, jsonb_build_object('seed', v_seed_tag))
    ON CONFLICT DO NOTHING;

    IF v_facility_scope IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
      VALUES (v_sample_id, v_facility_scope, 'facility', v_admin, jsonb_build_object('seed', v_seed_tag))
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
  ---------------------------------------------------------------------------
  -- Lineage relationships mirroring the legacy dataset
  ---------------------------------------------------------------------------

  FOR rel_rec IN
    SELECT *
    FROM (
      VALUES
        ('Organoid Expansion Batch RDX-01', 'Organoid Expansion Batch RDX-01 Passage 1', 'culture:passage'),
        ('Organoid Expansion Batch RDX-01 Passage 1', 'Organoid Expansion Batch RDX-01 Passage 1 - RNA Extract', 'extraction:rna'),
        ('Organoid Expansion Batch RDX-01 Passage 1', 'Organoid Expansion Batch RDX-01 Passage 1 - Protein Lysate', 'extraction:protein'),
        ('Organoid Expansion Batch RDX-01', 'Organoid Expansion Batch RDX-01 Cryo Backup', 'culture:cryopreserve'),
        ('Viral Challenge Mix Lot 12', 'LCMS Run 042 Analyte Panel', 'analysis:spike_in'),
        ('Participant 001 Blood Draw - Plasma Fraction - LCMS Prep', 'LCMS Run 042 Analyte Panel', 'analysis:panel_build'),
        ('PBMC Batch 001 - Aliquot B', 'PBMC Batch 001 - Aliquot B - T Cell Enrichment', 'workflow:tcell_enrichment'),
        ('PBMC Batch 001 - Aliquot B - T Cell Enrichment', 'PBMC Batch 001 - T Cell RNA', 'extraction:rna'),
        ('PBMC Batch 001 - Aliquot B - T Cell Enrichment', 'PBMC Batch 001 - T Cell Protein Lysate', 'extraction:protein'),
        ('PBMC Batch 001 - T Cell RNA', 'PBMC Batch 001 - Multi-Omics Library', 'workflow:multiomics_build'),
        ('PBMC Batch 001 - T Cell Protein Lysate', 'PBMC Batch 001 - Multi-Omics Library', 'workflow:multiomics_build')
    ) AS r(parent_name, child_name, relationship_type)
  LOOP
    SELECT artefact_id INTO v_sample_id
    FROM tmp_seed_samples
    WHERE name = rel_rec.parent_name;

    IF v_sample_id IS NULL THEN
      CONTINUE;
    END IF;

    SELECT artefact_id INTO v_container_id
    FROM tmp_seed_samples
    WHERE name = rel_rec.child_name;

    IF v_container_id IS NULL THEN
      CONTINUE;
    END IF;

    INSERT INTO app_provenance.artefact_relationships (
      parent_artefact_id,
      child_artefact_id,
      relationship_type,
      metadata,
      created_by
    )
    VALUES (
      v_sample_id,
      v_container_id,
      rel_rec.relationship_type,
      jsonb_build_object('seed', v_seed_tag),
      v_admin
    )
    ON CONFLICT DO NOTHING;
  END LOOP;
  ---------------------------------------------------------------------------
  -- Container artefacts and assignments
  ---------------------------------------------------------------------------

  CREATE TEMP TABLE tmp_seed_containers (
    barcode text PRIMARY KEY,
    artefact_id uuid
  ) ON COMMIT DROP;

  FOR container_rec IN
    SELECT *
    FROM (
      VALUES
        ('Legacy DNA Intake Plate 001', 'PLATE-DNA-0001', 'container_plate_96', 'project:prj-001'),
        ('Legacy DNA Intake Plate 002', 'PLATE-DNA-0002', 'container_plate_96', 'project:prj-001'),
        ('Organoid Expansion Holding Plate', 'PLATE-0001', 'container_plate_96', 'project:prj-002'),
        ('Library Prep Plate 001', 'PLATE-LIB-0001', 'container_plate_96', 'project:prj-002'),
        ('Sequencing Pool Rack', 'POOL-SEQ-0001', 'container_generic', 'project:prj-002'),
        ('Cryovial Reserve', 'TUBE-0001', 'container_cryovial_2ml', 'project:prj-001'),
        ('Neutralizing Panel Tube', 'TUBE-0002', 'container_cryovial_2ml', 'project:prj-003')
    ) AS c(name, barcode, type_key, project_key)
  LOOP
    SELECT artefact_type_id INTO v_type_id
    FROM app_provenance.artefact_types
    WHERE type_key = container_rec.type_key;

    IF v_type_id IS NULL THEN
      INSERT INTO app_provenance.artefact_types (type_key, display_name, kind, description, metadata, created_by)
      VALUES (container_rec.type_key, initcap(replace(container_rec.type_key, '_', ' ')), 'container', 'Legacy container type', jsonb_build_object('seed', v_seed_tag), v_admin)
      ON CONFLICT (type_key) DO NOTHING;

      SELECT artefact_type_id INTO v_type_id
      FROM app_provenance.artefact_types
      WHERE type_key = container_rec.type_key;
    END IF;

    IF v_type_id IS NULL THEN
      CONTINUE;
    END IF;

    v_external_id := 'seed:labware:' || lower(replace(container_rec.barcode, '-', '_'));

    BEGIN
      INSERT INTO app_provenance.artefacts (
        artefact_type_id,
        name,
        external_identifier,
        status,
        metadata,
        created_by
      )
      VALUES (
        v_type_id,
        container_rec.name,
        v_external_id,
        'active',
        jsonb_build_object('seed', v_seed_tag, 'barcode', container_rec.barcode),
        v_admin
      )
      RETURNING artefact_id INTO v_container_id;
    EXCEPTION
      WHEN unique_violation THEN
        SELECT artefact_id INTO v_container_id
        FROM app_provenance.artefacts
        WHERE external_identifier = v_external_id;
    END;

    IF v_container_id IS NULL THEN
      CONTINUE;
    END IF;

    INSERT INTO tmp_seed_containers (barcode, artefact_id)
    VALUES (container_rec.barcode, v_container_id)
    ON CONFLICT (barcode) DO UPDATE
      SET artefact_id = EXCLUDED.artefact_id;

    IF container_rec.project_key IS NOT NULL THEN
      SELECT scope_id INTO v_project_id
      FROM app_security.scopes
      WHERE scope_key = container_rec.project_key;

      IF v_project_id IS NOT NULL THEN
        INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
        VALUES (v_container_id, v_project_id, 'supplementary', v_admin, jsonb_build_object('seed', v_seed_tag))
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;

    IF v_facility_scope IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
      VALUES (v_container_id, v_facility_scope, 'facility', v_admin, jsonb_build_object('seed', v_seed_tag))
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
  -- Map samples into labware for inventory-style views
  FOR assign_rec IN
    SELECT *
    FROM (
      VALUES
        ('DNA Intake Batch 001 - Donor 101', 'PLATE-DNA-0001'),
        ('DNA Intake Batch 001 - Donor 102', 'PLATE-DNA-0001'),
        ('DNA Intake Batch 001 - Donor 103', 'PLATE-DNA-0001'),
        ('DNA Intake Batch 002 - Donor 201', 'PLATE-DNA-0002'),
        ('DNA Intake Batch 002 - Donor 202', 'PLATE-DNA-0002'),
        ('DNA Intake Batch 002 - Donor 203', 'PLATE-DNA-0002'),
        ('Organoid Expansion Batch RDX-01', 'PLATE-0001'),
        ('Organoid Expansion Batch RDX-01 Passage 1', 'PLATE-0001'),
        ('Organoid Expansion Batch RDX-01 Passage 1 - RNA Extract', 'PLATE-0001'),
        ('Organoid Expansion Batch RDX-01 Passage 1 - Protein Lysate', 'PLATE-0001'),
        ('Organoid Expansion Batch RDX-01 Cryo Backup', 'TUBE-0001'),
        ('Serum QC Control Sample', 'TUBE-0001'),
        ('Viral Challenge Mix Lot 12', 'POOL-SEQ-0001'),
        ('LCMS Run 042 Analyte Panel', 'POOL-SEQ-0001'),
        ('Sequencing Pool Run 001', 'POOL-SEQ-0001'),
        ('Indexed Library Batch 001 - Donor 101', 'PLATE-LIB-0001'),
        ('Indexed Library Batch 001 - Donor 102', 'PLATE-LIB-0001'),
        ('Indexed Library Batch 001 - Donor 103', 'PLATE-LIB-0001'),
        ('Indexed Library Batch 002 - Donor 201', 'POOL-SEQ-0001'),
        ('Indexed Library Batch 002 - Donor 202', 'POOL-SEQ-0001'),
        ('Indexed Library Batch 002 - Donor 203', 'POOL-SEQ-0001'),
        ('PBMC Batch 001 - Multi-Omics Library', 'PLATE-LIB-0001'),
        ('Neutralizing Panel B', 'TUBE-0002')
    ) AS a(sample_name, container_barcode)
  LOOP
    SELECT artefact_id INTO v_sample_id
    FROM tmp_seed_samples
    WHERE name = assign_rec.sample_name;

    IF v_sample_id IS NULL THEN
      CONTINUE;
    END IF;

    SELECT artefact_id INTO v_container_id
    FROM tmp_seed_containers
    WHERE barcode = assign_rec.container_barcode;

    IF v_container_id IS NULL THEN
      CONTINUE;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM app_provenance.artefacts a
      WHERE a.artefact_id = v_sample_id
        AND a.container_artefact_id IS NOT NULL
    ) THEN
      CONTINUE;
    END IF;

    UPDATE app_provenance.artefacts
    SET container_artefact_id = v_container_id
    WHERE artefact_id = v_sample_id
      AND container_artefact_id IS NULL;
  END LOOP;
  ---------------------------------------------------------------------------
  -- Storage hierarchy touch-up for legacy shelf references
  ---------------------------------------------------------------------------

  SELECT storage_node_id INTO v_facility_node
  FROM app_provenance.storage_nodes
  WHERE node_key = 'facility:main_biolab';

  SELECT storage_node_id INTO v_freezer_node
  FROM app_provenance.storage_nodes
  WHERE node_key = 'unit:freezer_nf1';

  IF v_freezer_node IS NULL THEN
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
    VALUES (
      'unit:freezer_nf1',
      'unit',
      'Freezer NF-1',
      'Legacy -80°C freezer for seeded data',
      v_facility_node,
      v_facility_scope,
      jsonb_build_object('seed', v_seed_tag),
      v_admin
    )
    RETURNING storage_node_id INTO v_freezer_node;
  END IF;

  SELECT storage_node_id INTO v_shelf_node
  FROM app_provenance.storage_nodes
  WHERE node_key = 'sublocation:main_biolab:shelf_1';

  IF v_shelf_node IS NULL THEN
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
    VALUES (
      'sublocation:main_biolab:shelf_1',
      'sublocation',
      'Shelf 1',
      'Legacy storage shelf for seeded labware',
      COALESCE(v_freezer_node, v_facility_node),
      v_facility_scope,
      jsonb_build_object('seed', v_seed_tag),
      v_admin
    )
    RETURNING storage_node_id INTO v_shelf_node;
  END IF;

  IF v_shelf_node IS NOT NULL THEN
    FOR container_rec IN
      SELECT artefact_id
      FROM tmp_seed_containers
    LOOP
      IF NOT EXISTS (
        SELECT 1
        FROM app_provenance.artefact_storage_events
        WHERE artefact_id = container_rec.artefact_id
          AND metadata ->> 'seed' = v_seed_tag
      ) THEN
        INSERT INTO app_provenance.artefact_storage_events (
          artefact_id,
          from_storage_node_id,
          to_storage_node_id,
          event_type,
          occurred_at,
          actor_id,
          reason,
          metadata
        )
        VALUES (
          container_rec.artefact_id,
          NULL,
          v_shelf_node,
          'check_in',
          clock_timestamp() - interval '2 days',
          COALESCE(v_operator, v_admin),
          'Seed placement for legacy demo',
          jsonb_build_object('seed', v_seed_tag)
        );
      END IF;
    END LOOP;
  END IF;

  PERFORM app_security.finish_transaction_context(v_txn, 'committed', 'redux provenance catalog');
END;
$$;

-- migrate:down
DO $$
DECLARE
  v_seed_tag constant text := 'redux-provenance';
  v_admin uuid;
  v_txn uuid;
BEGIN
  SELECT id INTO v_admin FROM app_core.users WHERE email = 'admin@example.org';

  v_txn := app_security.start_transaction_context(
    p_actor_id => COALESCE(v_admin, app_security.current_actor_id()),
    p_actor_identity => 'migration:redux_provenance_seed:down',
    p_effective_roles => ARRAY['app_admin'],
    p_client_app => 'dbmate:migration',
    p_metadata => jsonb_build_object('seed', v_seed_tag, 'direction', 'down')
  );

  PERFORM set_config('app.actor_id', COALESCE(v_admin, app_security.current_actor_id())::text, true);
  PERFORM set_config('app.actor_identity', 'migration:redux_provenance_seed:down', true);
  PERFORM set_config('app.roles', 'app_admin', true);

  DELETE FROM app_provenance.artefact_storage_events WHERE metadata ->> 'seed' = v_seed_tag;
  UPDATE app_provenance.artefacts
  SET container_slot_id = NULL,
      container_artefact_id = NULL
  WHERE metadata ->> 'seed' = v_seed_tag;
  DELETE FROM app_provenance.artefact_scopes WHERE metadata ->> 'seed' = v_seed_tag;
  DELETE FROM app_provenance.artefact_relationships WHERE metadata ->> 'seed' = v_seed_tag;
  DELETE FROM app_provenance.artefacts WHERE metadata ->> 'seed' = v_seed_tag;
  DELETE FROM app_provenance.artefact_types WHERE metadata ->> 'seed' = v_seed_tag;

  DELETE FROM app_security.scope_memberships WHERE metadata ->> 'seed' = v_seed_tag;
  DELETE FROM app_security.scopes WHERE metadata ->> 'seed' = v_seed_tag;

  DELETE FROM app_core.user_roles
  WHERE user_id IN (
    SELECT id FROM app_core.users WHERE metadata ->> 'seed' = v_seed_tag
  );

  DELETE FROM app_core.users WHERE metadata ->> 'seed' = v_seed_tag;

  PERFORM app_security.finish_transaction_context(v_txn, 'committed', 'rollback redux provenance catalog');
END;
$$;
