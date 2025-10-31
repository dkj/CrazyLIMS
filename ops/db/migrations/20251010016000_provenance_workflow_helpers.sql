-- migrate:up
SET client_min_messages = WARNING;

-------------------------------------------------------------------------------
-- Convenience stored procedures for ELN + provenance capture
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_provenance.get_artefact_type_id(p_type_key text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_type_key IS NULL OR trim(p_type_key) = '' THEN
    RETURN NULL;
  END IF;

  SELECT artefact_type_id
    INTO v_id
    FROM app_provenance.artefact_types
   WHERE type_key = lower(p_type_key)
     AND is_active
   LIMIT 1;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION app_provenance.get_process_type_id(p_type_key text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_type_key IS NULL OR trim(p_type_key) = '' THEN
    RETURN NULL;
  END IF;

  SELECT process_type_id
    INTO v_id
    FROM app_provenance.process_types
   WHERE type_key = lower(p_type_key)
     AND is_active
   LIMIT 1;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.get_artefact_type_id(text) TO app_auth, postgrest_authenticator, postgraphile_authenticator;
GRANT EXECUTE ON FUNCTION app_provenance.get_process_type_id(text) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

INSERT INTO app_provenance.process_types (type_key, display_name, description, metadata)
VALUES
  ('process_reagent_application', 'Reagent application', 'Track reagent added in place', jsonb_build_object('source','workflow_helpers')),
  ('process_fragment_plate', 'Plate fragmentation', 'Fragmentation of plates into new labware', jsonb_build_object('source','workflow_helpers')),
  ('process_indexing', 'Index assignment', 'Assign index primers to wells', jsonb_build_object('source','workflow_helpers')),
  ('process_plate_measurement', 'Plate measurement', 'Quantification or QC measurement for plate wells', jsonb_build_object('source','workflow_helpers')),
  ('process_pooling', 'Pooling', 'Pooling of aliquots into a destination', jsonb_build_object('source','workflow_helpers')),
  ('process_demultiplex', 'Demultiplex outputs', 'Demultiplex pooled run outputs into data products', jsonb_build_object('source','workflow_helpers'))
ON CONFLICT (type_key) DO NOTHING;

-------------------------------------------------------------------------------
-- Material loading helper
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_provenance.sp_load_material_into_slot(
  p_slot_id uuid,
  p_material jsonb,
  p_parent_artefact_id uuid DEFAULT NULL,
  p_relationship_type text DEFAULT 'derived_from'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_material jsonb := coalesce(p_material, '{}'::jsonb);
  v_slot RECORD;
  v_type_id uuid;
  v_name text;
  v_status text;
  v_metadata jsonb;
  v_quantity numeric;
  v_quantity_unit text;
  v_external text;
  v_is_virtual boolean := COALESCE((v_material->>'is_virtual')::boolean, false);
  v_container uuid;
  v_slot_name text;
  v_actor uuid := app_security.current_actor_id();
  v_existing uuid;
  v_new uuid;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_material) <> 'object' THEN
    RAISE EXCEPTION 'Material payload must be an object';
  END IF;

  v_name := coalesce(v_material->>'name', v_material->>'display_name');
  IF v_name IS NULL OR trim(v_name) = '' THEN
    RAISE EXCEPTION 'Material name is required';
  END IF;

  v_status := coalesce(v_material->>'status', 'active');
  v_metadata := coalesce(v_material->'metadata', '{}'::jsonb);
  IF jsonb_typeof(v_metadata) <> 'object' THEN
    RAISE EXCEPTION 'Material metadata must be an object';
  END IF;

  v_quantity := NULLIF(v_material->>'quantity', '')::numeric;
  v_quantity_unit := NULLIF(v_material->>'quantity_unit', '');
  v_external := NULLIF(v_material->>'external_identifier', '');

  v_type_id := app_provenance.get_artefact_type_id(coalesce(v_material->>'artefact_type_key', 'material_sample'));
  IF v_type_id IS NULL THEN
    RAISE EXCEPTION 'Unknown material type %', coalesce(v_material->>'artefact_type_key', 'material_sample');
  END IF;

  IF p_slot_id IS NOT NULL THEN
    SELECT cs.container_slot_id,
           cs.container_artefact_id,
           cs.slot_name,
           container.name AS container_name
      INTO v_slot
      FROM app_provenance.container_slots cs
      JOIN app_provenance.artefacts container ON container.artefact_id = cs.container_artefact_id
     WHERE cs.container_slot_id = p_slot_id
     LIMIT 1;

    IF v_slot.container_slot_id IS NULL THEN
      RAISE EXCEPTION 'Container slot % not found', p_slot_id;
    END IF;

    v_container := v_slot.container_artefact_id;
    v_slot_name := v_slot.slot_name;

    SELECT artefact_id INTO v_existing
      FROM app_provenance.artefacts
     WHERE container_slot_id = v_slot.container_slot_id
       AND status IN ('active','reserved')
     ORDER BY updated_at DESC
     LIMIT 1;

    IF v_existing IS NOT NULL THEN
      UPDATE app_provenance.artefacts
         SET status = 'retired',
             updated_at = clock_timestamp(),
             updated_by = v_actor
       WHERE artefact_id = v_existing;
    END IF;
  ELSE
    v_container := NULLIF(v_material->>'container_artefact_id', '')::uuid;
    v_slot_name := v_material->>'container_slot_name';
  END IF;

  INSERT INTO app_provenance.artefacts (
    artefact_type_id,
    name,
    external_identifier,
    status,
    is_virtual,
    quantity,
    quantity_unit,
    metadata,
    container_artefact_id,
    container_slot_id,
    created_by,
    updated_by
  )
  VALUES (
    v_type_id,
    v_name,
    v_external,
    v_status,
    v_is_virtual,
    v_quantity,
    v_quantity_unit,
    v_metadata || jsonb_build_object('source', 'sp_load_material_into_slot', 'container_slot', v_slot_name),
    v_container,
    p_slot_id,
    v_actor,
    v_actor
  )
  RETURNING artefact_id INTO v_new;

  IF p_parent_artefact_id IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_relationships (
      parent_artefact_id,
      child_artefact_id,
      relationship_type,
      metadata,
      created_by
    )
    VALUES (
      p_parent_artefact_id,
      v_new,
      lower(coalesce(p_relationship_type, 'derived_from')),
      jsonb_build_object('source', 'sp_load_material_into_slot'),
      v_actor
    )
    ON CONFLICT ON CONSTRAINT artefact_relationships_parent_artefact_id_child_artefact_id_key DO NOTHING;
  END IF;

  IF v_container IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
    SELECT v_new,
           scope_id,
           relationship,
           v_actor,
           coalesce(metadata, '{}'::jsonb) || jsonb_build_object('source','sp_load_material_into_slot','origin','container')
      FROM app_provenance.artefact_scopes
     WHERE artefact_id = v_container
       AND relationship = 'primary'
    ON CONFLICT ON CONSTRAINT artefact_scopes_pkey DO UPDATE
      SET metadata = coalesce(app_provenance.artefact_scopes.metadata, '{}'::jsonb)
                     || jsonb_build_object('source','sp_load_material_into_slot','origin','container');
  END IF;

  IF p_parent_artefact_id IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
    SELECT v_new,
           scope_id,
           relationship,
           v_actor,
           coalesce(metadata, '{}'::jsonb) || jsonb_build_object('source','sp_load_material_into_slot','origin','parent')
      FROM app_provenance.artefact_scopes
     WHERE artefact_id = p_parent_artefact_id
       AND relationship = 'primary'
    ON CONFLICT ON CONSTRAINT artefact_scopes_pkey DO UPDATE
      SET metadata = coalesce(app_provenance.artefact_scopes.metadata, '{}'::jsonb)
                     || jsonb_build_object('source','sp_load_material_into_slot','origin','parent');
  END IF;

  RETURN v_new;
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_load_material_into_slot(uuid, jsonb, uuid, text) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Virtual manifest and labware helpers
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_provenance.sp_register_virtual_manifest(
  p_scope_id uuid,
  p_manifest jsonb,
  p_default_type_key text DEFAULT 'material_sample'
)
RETURNS TABLE (
  artefact_id uuid,
  artefact_name text,
  external_identifier text,
  was_created boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_manifest jsonb := coalesce(p_manifest, '[]'::jsonb);
  v_entry jsonb;
  v_type_id uuid;
  v_actor uuid := app_security.current_actor_id();
  v_scope uuid := p_scope_id;
  v_existing uuid;
  v_created boolean;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_manifest) <> 'array' THEN
    RAISE EXCEPTION 'Manifest payload must be an array';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_manifest)
  LOOP
    IF jsonb_typeof(v_entry) <> 'object' THEN
      RAISE EXCEPTION 'Manifest entries must be JSON objects';
    END IF;

    IF coalesce(v_entry->>'name', v_entry->>'display_name', '') = '' THEN
      RAISE EXCEPTION 'Manifest entry missing name';
    END IF;

    v_type_id := app_provenance.get_artefact_type_id(coalesce(v_entry->>'artefact_type_key', p_default_type_key));
    IF v_type_id IS NULL THEN
      RAISE EXCEPTION 'Unknown artefact type %', coalesce(v_entry->>'artefact_type_key', p_default_type_key);
    END IF;

    SELECT a.artefact_id
      INTO v_existing
      FROM app_provenance.artefacts a
     WHERE a.external_identifier = NULLIF(v_entry->>'external_identifier','')
        OR (a.name = v_entry->>'name' AND a.is_virtual)
     LIMIT 1;

    v_created := false;

    IF v_existing IS NULL THEN
      INSERT INTO app_provenance.artefacts AS new_art (
        artefact_type_id,
        name,
        external_identifier,
        status,
        is_virtual,
        metadata,
        created_by,
        updated_by
      )
      VALUES (
        v_type_id,
        coalesce(v_entry->>'name', v_entry->>'display_name'),
        NULLIF(v_entry->>'external_identifier',''),
        coalesce(v_entry->>'status', 'active'),
        true,
        coalesce(v_entry->'metadata', '{}'::jsonb) || jsonb_build_object('source', 'sp_register_virtual_manifest'),
        v_actor,
        v_actor
      )
      RETURNING new_art.artefact_id INTO v_existing;
      v_created := true;
    ELSE
      UPDATE app_provenance.artefacts AS upd
         SET artefact_type_id = v_type_id,
             name = coalesce(v_entry->>'name', v_entry->>'display_name'),
             status = coalesce(v_entry->>'status', 'active'),
             metadata = coalesce(upd.metadata, '{}'::jsonb)
                        || coalesce(v_entry->'metadata', '{}'::jsonb)
                        || jsonb_build_object('source', 'sp_register_virtual_manifest', 'updated_at', clock_timestamp()),
             updated_at = clock_timestamp(),
             updated_by = v_actor,
             external_identifier = COALESCE(NULLIF(v_entry->>'external_identifier',''), upd.external_identifier),
             is_virtual = true
       WHERE upd.artefact_id = v_existing;
    END IF;

    IF v_scope IS NOT NULL THEN
      INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
      VALUES (v_existing, v_scope, 'primary', v_actor, jsonb_build_object('source','sp_register_virtual_manifest'))
      ON CONFLICT ON CONSTRAINT artefact_scopes_pkey DO UPDATE
        SET metadata = coalesce(app_provenance.artefact_scopes.metadata, '{}'::jsonb)
                       || jsonb_build_object('source','sp_register_virtual_manifest'),
            assigned_at = clock_timestamp();
    END IF;

    artefact_id := v_existing;
    artefact_name := coalesce(v_entry->>'name', v_entry->>'display_name');
    external_identifier := NULLIF(v_entry->>'external_identifier','');
    was_created := v_created;
    RETURN NEXT;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_register_virtual_manifest(uuid, jsonb, text) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_provenance.sp_register_labware_with_wells(
  p_container_type_key text,
  p_container jsonb,
  p_wells jsonb DEFAULT '[]'::jsonb,
  p_scope_id uuid DEFAULT NULL
)
RETURNS TABLE (
  container_id uuid,
  slot_id uuid,
  slot_name text,
  occupant_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_container jsonb := coalesce(p_container, '{}'::jsonb);
  v_wells jsonb := coalesce(p_wells, '[]'::jsonb);
  v_type_id uuid;
  v_container_id uuid;
  v_actor uuid := app_security.current_actor_id();
  v_scope uuid := p_scope_id;
  v_slot jsonb;
  v_slot_id uuid;
  v_existing uuid;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_container) <> 'object' THEN
    RAISE EXCEPTION 'Container payload must be object';
  END IF;

  IF coalesce(v_container->>'name', v_container->>'display_name', '') = '' THEN
    RAISE EXCEPTION 'Container name is required';
  END IF;

  v_type_id := app_provenance.get_artefact_type_id(p_container_type_key);
  IF v_type_id IS NULL THEN
    RAISE EXCEPTION 'Unknown container type %', p_container_type_key;
  END IF;

  SELECT artefact_id
    INTO v_existing
    FROM app_provenance.artefacts
   WHERE external_identifier = NULLIF(v_container->>'external_identifier','')
     AND artefact_type_id = v_type_id
   LIMIT 1;

  IF v_existing IS NULL THEN
    INSERT INTO app_provenance.artefacts (
      artefact_type_id,
      name,
      external_identifier,
      status,
      metadata,
      created_by,
      updated_by
    )
    VALUES (
      v_type_id,
      coalesce(v_container->>'name', v_container->>'display_name'),
      NULLIF(v_container->>'external_identifier',''),
      coalesce(v_container->>'status', 'active'),
      coalesce(v_container->'metadata', '{}'::jsonb) || jsonb_build_object('source', 'sp_register_labware_with_wells'),
      v_actor,
      v_actor
    )
    RETURNING artefact_id INTO v_container_id;
  ELSE
    UPDATE app_provenance.artefacts
       SET name = coalesce(v_container->>'name', v_container->>'display_name'),
           status = coalesce(v_container->>'status', 'active'),
           metadata = coalesce(metadata, '{}'::jsonb)
                      || coalesce(v_container->'metadata', '{}'::jsonb)
                      || jsonb_build_object('source', 'sp_register_labware_with_wells', 'updated_at', clock_timestamp()),
           updated_at = clock_timestamp(),
           updated_by = v_actor
     WHERE artefact_id = v_existing;
    v_container_id := v_existing;
  END IF;

  IF v_scope IS NOT NULL THEN
    INSERT INTO app_provenance.artefact_scopes (artefact_id, scope_id, relationship, assigned_by, metadata)
    VALUES (v_container_id, v_scope, 'primary', v_actor, jsonb_build_object('source', 'sp_register_labware_with_wells'))
    ON CONFLICT ON CONSTRAINT artefact_scopes_pkey DO UPDATE
      SET metadata = coalesce(app_provenance.artefact_scopes.metadata, '{}'::jsonb)
                     || jsonb_build_object('source', 'sp_register_labware_with_wells'),
          assigned_at = clock_timestamp();
  END IF;

  IF jsonb_typeof(v_wells) <> 'array' THEN
    RAISE EXCEPTION 'Well definitions must be array';
  END IF;

  FOR v_slot IN SELECT value FROM jsonb_array_elements(v_wells)
  LOOP
    IF jsonb_typeof(v_slot) <> 'object' THEN
      RAISE EXCEPTION 'Well definition must be object';
    END IF;

    IF coalesce(v_slot->>'slot_name', '') = '' THEN
      RAISE EXCEPTION 'slot_name required in well definition';
    END IF;

    INSERT INTO app_provenance.container_slots (
      container_artefact_id,
      slot_definition_id,
      slot_name,
      display_name,
      position,
      metadata
    )
    VALUES (
      v_container_id,
      NULL,
      v_slot->>'slot_name',
      v_slot->>'display_name',
      v_slot->'position',
      coalesce(v_slot->'metadata', '{}'::jsonb) || jsonb_build_object('source', 'sp_register_labware_with_wells')
    )
    ON CONFLICT ON CONSTRAINT container_slots_container_artefact_id_slot_name_key DO UPDATE
      SET display_name = COALESCE(EXCLUDED.display_name, app_provenance.container_slots.display_name),
          position = COALESCE(EXCLUDED.position, app_provenance.container_slots.position),
          metadata = coalesce(app_provenance.container_slots.metadata, '{}'::jsonb)
                    || coalesce(EXCLUDED.metadata, '{}'::jsonb)
                    || jsonb_build_object('source', 'sp_register_labware_with_wells')
    RETURNING container_slot_id INTO v_slot_id;

    container_id := v_container_id;
    slot_id := v_slot_id;
    slot_name := v_slot->>'slot_name';

    IF v_slot ? 'occupant' THEN
      occupant_id := app_provenance.sp_load_material_into_slot(
        v_slot_id,
        v_slot->'occupant',
        NULLIF((v_slot->'occupant')->>'parent_artefact_id','')::uuid,
        coalesce((v_slot->'occupant')->>'relationship_type', v_slot->>'relationship_type', 'derived_from')
      );
    ELSE
      occupant_id := NULL;
    END IF;

    RETURN NEXT;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_register_labware_with_wells(text, jsonb, jsonb, uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Process capture helper
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_provenance.sp_record_process_with_io(
  p_process jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_payload jsonb := coalesce(p_process, '{}'::jsonb);
  v_type_id uuid;
  v_name text;
  v_status text;
  v_started timestamptz;
  v_completed timestamptz;
  v_identifier text;
  v_metadata jsonb;
  v_actor uuid := app_security.current_actor_id();
  v_process_id uuid;
  v_item jsonb;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_payload) <> 'object' THEN
    RAISE EXCEPTION 'Process payload must be object';
  END IF;

  v_type_id := app_provenance.get_process_type_id(coalesce(v_payload->>'process_type_key', v_payload->>'type_key'));
  IF v_type_id IS NULL THEN
    RAISE EXCEPTION 'Unknown process type %', coalesce(v_payload->>'process_type_key', v_payload->>'type_key');
  END IF;

  v_name := coalesce(v_payload->>'name', 'Process');
  v_status := coalesce(v_payload->>'status', 'completed');
  v_started := NULLIF(v_payload->>'started_at','')::timestamptz;
  v_completed := NULLIF(v_payload->>'completed_at','')::timestamptz;
  v_identifier := NULLIF(v_payload->>'process_identifier','');
  v_metadata := coalesce(v_payload->'metadata', '{}'::jsonb);
  IF jsonb_typeof(v_metadata) <> 'object' THEN
    RAISE EXCEPTION 'Process metadata must be object';
  END IF;

  INSERT INTO app_provenance.process_instances (
    process_type_id,
    process_identifier,
    name,
    status,
    started_at,
    completed_at,
    executed_by,
    metadata,
    created_by,
    updated_by
  )
  VALUES (
    v_type_id,
    v_identifier,
    v_name,
    v_status,
    v_started,
    v_completed,
    COALESCE(NULLIF(v_payload->>'executed_by','')::uuid, v_actor),
    v_metadata || jsonb_build_object('source', 'sp_record_process_with_io'),
    v_actor,
    v_actor
  )
  RETURNING process_instance_id INTO v_process_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(v_payload->'inputs', '[]'::jsonb))
  LOOP
    INSERT INTO app_provenance.process_io (
      process_instance_id,
      artefact_id,
      direction,
      io_role,
      quantity,
      quantity_unit,
      is_primary,
      multiplex_group,
      metadata
    )
    VALUES (
      v_process_id,
      (v_item->>'artefact_id')::uuid,
      coalesce(v_item->>'direction','input'),
      v_item->>'io_role',
      NULLIF(v_item->>'quantity','')::numeric,
      v_item->>'quantity_unit',
      coalesce((v_item->>'is_primary')::boolean, false),
      v_item->>'multiplex_group',
      coalesce(v_item->'metadata', '{}'::jsonb) || jsonb_build_object('source','sp_record_process_with_io')
    );
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(v_payload->'outputs', '[]'::jsonb))
  LOOP
    INSERT INTO app_provenance.process_io (
      process_instance_id,
      artefact_id,
      direction,
      io_role,
      quantity,
      quantity_unit,
      is_primary,
      multiplex_group,
      metadata
    )
    VALUES (
      v_process_id,
      (v_item->>'artefact_id')::uuid,
      coalesce(v_item->>'direction','output'),
      v_item->>'io_role',
      NULLIF(v_item->>'quantity','')::numeric,
      v_item->>'quantity_unit',
      coalesce((v_item->>'is_primary')::boolean, true),
      v_item->>'multiplex_group',
      coalesce(v_item->'metadata', '{}'::jsonb) || jsonb_build_object('source','sp_record_process_with_io')
    );
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(v_payload->'relationships', '[]'::jsonb))
  LOOP
    INSERT INTO app_provenance.artefact_relationships (
      parent_artefact_id,
      child_artefact_id,
      relationship_type,
      process_instance_id,
      metadata,
      created_by
    )
    VALUES (
      (v_item->>'parent_id')::uuid,
      (v_item->>'child_id')::uuid,
      lower(coalesce(v_item->>'relationship_type','derived_from')),
      v_process_id,
      coalesce(v_item->'metadata', '{}'::jsonb) || jsonb_build_object('source','sp_record_process_with_io'),
      v_actor
    )
    ON CONFLICT ON CONSTRAINT artefact_relationships_parent_artefact_id_child_artefact_id_key DO NOTHING;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(v_payload->'scopes', '[]'::jsonb))
  LOOP
    IF jsonb_typeof(v_item) = 'string' THEN
      INSERT INTO app_provenance.process_scopes (process_instance_id, scope_id, metadata)
      VALUES (v_process_id, (v_item)::text::uuid, jsonb_build_object('source','sp_record_process_with_io'))
      ON CONFLICT DO NOTHING;
    ELSIF jsonb_typeof(v_item) = 'object' THEN
      INSERT INTO app_provenance.process_scopes (process_instance_id, scope_id, metadata)
      VALUES (
        v_process_id,
        (v_item->>'scope_id')::uuid,
        coalesce(v_item->'metadata', '{}'::jsonb) || jsonb_build_object('source','sp_record_process_with_io')
      )
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  WITH referenced AS (
    SELECT DISTINCT (value->>'artefact_id')::uuid AS artefact_id
      FROM jsonb_array_elements(coalesce(v_payload->'inputs', '[]'::jsonb))
     WHERE value ? 'artefact_id'
    UNION
    SELECT DISTINCT (value->>'artefact_id')::uuid AS artefact_id
      FROM jsonb_array_elements(coalesce(v_payload->'outputs', '[]'::jsonb))
     WHERE value ? 'artefact_id'
  )
  INSERT INTO app_provenance.process_scopes (process_instance_id, scope_id, metadata)
  SELECT v_process_id,
         s.scope_id,
         coalesce(s.metadata, '{}'::jsonb) || jsonb_build_object('source','sp_record_process_with_io','origin','artefact')
    FROM referenced r
    JOIN app_provenance.artefact_scopes s
      ON s.artefact_id = r.artefact_id
   WHERE s.relationship = 'primary'
  ON CONFLICT DO NOTHING;

  RETURN v_process_id;
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_record_process_with_io(jsonb) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- Domain-specific wrappers
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app_provenance.sp_apply_reagent_in_place(
  p_target_slot_id uuid,
  p_reagent_artefact_id uuid,
  p_output jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_current uuid;
  v_output jsonb := coalesce(p_output, '{}'::jsonb);
  v_metadata jsonb := coalesce(v_output->'metadata', '{}'::jsonb);
  v_new uuid;
  v_relationship_type text := coalesce(v_output->>'relationship_type','derived_from');
BEGIN
  PERFORM app_security.require_transaction_context();

  SELECT artefact_id INTO v_current
    FROM app_provenance.artefacts
   WHERE container_slot_id = p_target_slot_id
     AND status IN ('active','reserved')
   ORDER BY updated_at DESC
   LIMIT 1;

  IF v_current IS NULL THEN
    RAISE EXCEPTION 'No active artefact in slot %', p_target_slot_id;
  END IF;

  v_new := app_provenance.sp_load_material_into_slot(
    p_target_slot_id,
    jsonb_build_object(
      'name', coalesce(v_output->>'name', 'Reagent treated sample'),
      'artefact_type_key', coalesce(v_output->>'artefact_type_key','material_sample'),
      'status', coalesce(v_output->>'status','active'),
      'metadata', v_metadata
    ),
    v_current,
    v_relationship_type
  );

  UPDATE app_provenance.artefacts
     SET status = 'consumed',
         updated_at = clock_timestamp()
   WHERE artefact_id = v_current;

  PERFORM app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', coalesce(v_output->>'process_type_key','process_reagent_application'),
      'name', coalesce(v_output->>'process_name','Reagent application'),
      'inputs', jsonb_build_array(
        jsonb_build_object('artefact_id', v_current, 'direction', 'input', 'io_role', 'treated_material', 'is_primary', true),
        jsonb_build_object('artefact_id', p_reagent_artefact_id, 'direction', 'input', 'io_role', 'reagent', 'is_primary', false)
      ),
      'outputs', jsonb_build_array(
        jsonb_build_object('artefact_id', v_new, 'direction', 'output', 'io_role', 'treated_output', 'is_primary', true)
      ),
      'relationships', jsonb_build_array(
        jsonb_build_object('parent_id', v_current, 'child_id', v_new, 'relationship_type', v_relationship_type)
      )
    )
  );

  RETURN v_new;
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_apply_reagent_in_place(uuid, uuid, jsonb) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_provenance.sp_fragment_plate(
  p_source_plate_id uuid,
  p_reagent_artefact_id uuid,
  p_destination_plate_id uuid,
  p_mapping jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_map jsonb := coalesce(p_mapping, '[]'::jsonb);
  v_entry jsonb;
  v_source_slot_id uuid;
  v_dest_slot_id uuid;
  v_source_art uuid;
  v_new uuid;
  v_inputs jsonb := '[]'::jsonb;
  v_outputs jsonb := '[]'::jsonb;
  v_relationships jsonb := '[]'::jsonb;
  v_seen uuid[] := ARRAY[]::uuid[];
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_map) <> 'array' THEN
    RAISE EXCEPTION 'Mapping must be array';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_map)
  LOOP
    IF jsonb_typeof(v_entry) <> 'object' THEN
      RAISE EXCEPTION 'Mapping entry must be object';
    END IF;

    SELECT container_slot_id INTO v_source_slot_id
      FROM app_provenance.container_slots
     WHERE container_artefact_id = p_source_plate_id
       AND slot_name = v_entry->>'source_slot'
     LIMIT 1;

    SELECT container_slot_id INTO v_dest_slot_id
      FROM app_provenance.container_slots
     WHERE container_artefact_id = p_destination_plate_id
       AND slot_name = v_entry->>'dest_slot'
     LIMIT 1;

    IF v_source_slot_id IS NULL OR v_dest_slot_id IS NULL THEN
      RAISE EXCEPTION 'Invalid source/destination slot in mapping entry %', v_entry::text;
    END IF;

    SELECT artefact_id INTO v_source_art
      FROM app_provenance.artefacts
     WHERE container_slot_id = v_source_slot_id
     ORDER BY updated_at DESC
     LIMIT 1;

    IF v_source_art IS NULL THEN
      RAISE EXCEPTION 'No artefact found in source slot %', v_entry->>'source_slot';
    END IF;

    v_new := app_provenance.sp_load_material_into_slot(
      v_dest_slot_id,
      jsonb_build_object(
        'name', coalesce(v_entry->>'output_name', format('Fragment %s', v_entry->>'dest_slot')),
        'artefact_type_key', coalesce(v_entry->>'artefact_type_key', 'material_sample'),
        'metadata', coalesce(v_entry->'metadata', '{}'::jsonb)
      ),
      v_source_art,
      coalesce(v_entry->>'relationship_type','derived_from')
    );

    v_outputs := v_outputs
      || jsonb_build_array(
           jsonb_build_object(
             'artefact_id', v_new,
             'direction', 'output',
             'io_role', 'fragment_output'
           )
         );
    v_relationships := v_relationships || jsonb_build_array(jsonb_build_object('parent_id', v_source_art, 'child_id', v_new, 'relationship_type', coalesce(v_entry->>'relationship_type','derived_from')));

    IF NOT (v_source_art = ANY(v_seen)) THEN
      v_inputs := v_inputs || jsonb_build_array(jsonb_build_object('artefact_id', v_source_art, 'direction', 'input', 'io_role', 'source_fragment', 'is_primary', true));
      v_seen := array_append(v_seen, v_source_art);
    END IF;
  END LOOP;

  IF p_reagent_artefact_id IS NOT NULL THEN
    v_inputs := v_inputs || jsonb_build_array(jsonb_build_object('artefact_id', p_reagent_artefact_id, 'direction', 'input', 'io_role', 'reagent', 'is_primary', false));
  END IF;

  RETURN app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', 'process_fragment_plate',
      'name', 'Plate fragmentation',
      'inputs', v_inputs,
      'outputs', v_outputs,
      'relationships', v_relationships,
      'status', 'completed'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_fragment_plate(uuid, uuid, uuid, jsonb) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_provenance.sp_index_libraries(
  p_source_plate_id uuid,
  p_index_manifest jsonb,
  p_destination_plate_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_manifest jsonb := coalesce(p_index_manifest, '[]'::jsonb);
  v_entry jsonb;
  v_source_slot uuid;
  v_dest_slot uuid;
  v_source uuid;
  v_new uuid;
  v_inputs jsonb := '[]'::jsonb;
  v_outputs jsonb := '[]'::jsonb;
  v_relationships jsonb := '[]'::jsonb;
  v_seen uuid[] := ARRAY[]::uuid[];
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_manifest) <> 'array' THEN
    RAISE EXCEPTION 'Index manifest must be array';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_manifest)
  LOOP
    SELECT container_slot_id INTO v_source_slot
      FROM app_provenance.container_slots
     WHERE container_artefact_id = p_source_plate_id
       AND slot_name = v_entry->>'source_slot'
     LIMIT 1;

    SELECT container_slot_id INTO v_dest_slot
      FROM app_provenance.container_slots
     WHERE container_artefact_id = p_destination_plate_id
       AND slot_name = v_entry->>'dest_slot'
     LIMIT 1;

    IF v_source_slot IS NULL OR v_dest_slot IS NULL THEN
      RAISE EXCEPTION 'Invalid source or dest slot for index entry %', v_entry::text;
    END IF;

    SELECT artefact_id INTO v_source
      FROM app_provenance.artefacts
     WHERE container_slot_id = v_source_slot
     ORDER BY updated_at DESC
     LIMIT 1;

    IF v_source IS NULL THEN
      RAISE EXCEPTION 'No artefact in source slot %', v_entry->>'source_slot';
    END IF;

    v_new := app_provenance.sp_load_material_into_slot(
      v_dest_slot,
      jsonb_build_object(
        'name', coalesce(v_entry->>'output_name', format('Library %s', v_entry->>'dest_slot')),
        'metadata', coalesce(v_entry->'metadata', '{}'::jsonb) || jsonb_build_object('index_pair', v_entry->>'index_pair')
      ),
      v_source,
      'derived_from'
    );

    v_outputs := v_outputs
      || jsonb_build_array(
           jsonb_build_object(
             'artefact_id', v_new,
             'direction', 'output',
             'io_role', 'library_output'
           )
         );
    v_relationships := v_relationships || jsonb_build_array(jsonb_build_object(
      'parent_id', v_source,
      'child_id', v_new,
      'relationship_type', 'derived_from',
      'metadata', jsonb_build_object('index_pair', v_entry->>'index_pair')
    ));

    IF NOT (v_source = ANY(v_seen)) THEN
      v_inputs := v_inputs || jsonb_build_array(jsonb_build_object('artefact_id', v_source, 'direction', 'input', 'io_role', 'source_library', 'is_primary', true));
      v_seen := array_append(v_seen, v_source);
    END IF;
  END LOOP;

  RETURN app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', 'process_indexing',
      'name', 'Index assignment',
      'inputs', v_inputs,
      'outputs', v_outputs,
      'relationships', v_relationships,
      'status', 'completed'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_index_libraries(uuid, jsonb, uuid) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_provenance.sp_plate_measurement(
  p_process jsonb,
  p_measurements jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_measurements jsonb := coalesce(p_measurements, '[]'::jsonb);
  v_entry jsonb;
  v_slot uuid;
  v_sample uuid;
  v_traits jsonb;
  v_outputs jsonb := '[]'::jsonb;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_measurements) <> 'array' THEN
    RAISE EXCEPTION 'Measurements must be array';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_measurements)
  LOOP
    SELECT container_slot_id INTO v_slot
      FROM app_provenance.container_slots
     WHERE container_artefact_id = (p_process->>'plate_id')::uuid
       AND slot_name = v_entry->>'slot_name'
     LIMIT 1;

    IF v_slot IS NULL THEN
      RAISE EXCEPTION 'Unknown slot % in measurement set', v_entry->>'slot_name';
    END IF;

    SELECT artefact_id INTO v_sample
      FROM app_provenance.artefacts
     WHERE container_slot_id = v_slot
     ORDER BY updated_at DESC
     LIMIT 1;

    IF v_sample IS NULL THEN
      CONTINUE;
    END IF;

    v_traits := coalesce(v_entry->'traits', '{}'::jsonb);
    IF jsonb_typeof(v_traits) <> 'object' THEN
      RAISE EXCEPTION 'Measurement traits must be object';
    END IF;

    UPDATE app_provenance.artefacts
       SET metadata = coalesce(metadata, '{}'::jsonb) || v_traits || jsonb_build_object('last_measurement_at', clock_timestamp()),
           updated_at = clock_timestamp(),
           updated_by = app_security.current_actor_id()
     WHERE artefact_id = v_sample;

    v_outputs := v_outputs || jsonb_build_array(
      jsonb_build_object(
        'artefact_id', v_sample,
        'direction', 'output',
        'io_role', 'measured_sample',
        'metadata', jsonb_build_object('source','sp_plate_measurement')
      )
    );
  END LOOP;

  RETURN app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', coalesce(p_process->>'process_type_key', 'process_plate_measurement'),
      'name', coalesce(p_process->>'name', 'Plate measurement'),
      'status', coalesce(p_process->>'status', 'completed'),
      'metadata', coalesce(p_process->'metadata', '{}'::jsonb),
      'inputs', coalesce(p_process->'inputs', '[]'::jsonb),
      'outputs', CASE
                   WHEN jsonb_array_length(coalesce(p_process->'outputs', '[]'::jsonb)) > 0 THEN
                     coalesce(p_process->'outputs', '[]'::jsonb)
                   ELSE
                     v_outputs
                 END
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_plate_measurement(jsonb, jsonb) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_provenance.sp_pool_fixed_volume(
  p_input_slots uuid[],
  p_destination_slot_id uuid,
  p_volume_ul numeric,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_meta jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_slot uuid;
  v_inputs jsonb := '[]'::jsonb;
  v_relationships jsonb := '[]'::jsonb;
  v_outputs jsonb;
  v_source_slot uuid;
  v_source uuid;
  v_pool uuid;
  v_total numeric;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF p_destination_slot_id IS NULL THEN
    RAISE EXCEPTION 'Destination slot id required';
  END IF;

  IF p_input_slots IS NULL OR array_length(p_input_slots,1) IS NULL THEN
    RAISE EXCEPTION 'At least one source slot required';
  END IF;

  v_total := coalesce(p_volume_ul, 0) * array_length(p_input_slots,1);

  FOREACH v_source_slot IN ARRAY p_input_slots
  LOOP
    SELECT artefact_id INTO v_source
      FROM app_provenance.artefacts
     WHERE container_slot_id = v_source_slot
     ORDER BY updated_at DESC
     LIMIT 1;

    IF v_source IS NULL THEN
      RAISE EXCEPTION 'No artefact found in source slot %', v_source_slot;
    END IF;

    v_inputs := v_inputs || jsonb_build_array(jsonb_build_object(
      'artefact_id', v_source,
      'direction', 'pooled_input',
      'io_role', 'pool_component',
      'quantity', p_volume_ul,
      'quantity_unit', 'ul',
      'is_primary', true
    ));

    v_relationships := v_relationships || jsonb_build_array(jsonb_build_object('parent_id', v_source, 'relationship_type', 'pooled_from'));
  END LOOP;

  v_pool := app_provenance.sp_load_material_into_slot(
    p_destination_slot_id,
    jsonb_build_object(
      'name', coalesce(v_meta->>'name', 'Pooled sample'),
      'metadata', v_meta,
      'quantity', v_total,
      'quantity_unit', 'ul'
    ),
    NULL,
    'pooled_output'
  );

  v_outputs := jsonb_build_array(jsonb_build_object(
    'artefact_id', v_pool,
    'direction', 'pooled_output',
    'io_role', 'pool',
    'quantity', v_total,
    'quantity_unit', 'ul',
    'is_primary', true
  ));

  -- fill child ids for relationships
  v_relationships := COALESCE(
    (SELECT jsonb_agg(elem || jsonb_build_object('child_id', v_pool)) FROM jsonb_array_elements(v_relationships) elem),
    '[]'::jsonb
  );

  RETURN app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', 'process_pooling',
      'name', 'Fixed volume pooling',
      'metadata', v_meta,
      'inputs', v_inputs,
      'outputs', v_outputs,
      'relationships', v_relationships
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_pool_fixed_volume(uuid[], uuid, numeric, jsonb) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_provenance.sp_demultiplex_outputs(
  p_pool_artefact_id uuid,
  p_run_metadata jsonb,
  p_contributors jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_contrib jsonb := coalesce(p_contributors, '[]'::jsonb);
  v_entry jsonb;
  v_outputs jsonb := '[]'::jsonb;
  v_relationships jsonb := '[]'::jsonb;
  v_new uuid;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_contrib) <> 'array' THEN
    RAISE EXCEPTION 'Contributor map must be array';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_contrib)
  LOOP
    IF jsonb_typeof(v_entry) <> 'object' THEN
      RAISE EXCEPTION 'Contributor entry must be object';
    END IF;

    v_new := app_provenance.sp_load_material_into_slot(
      NULLIF(v_entry->>'slot_id','')::uuid,
      jsonb_build_object(
        'name', coalesce(v_entry->>'name', 'Demultiplexed output'),
        'artefact_type_key', coalesce(v_entry->>'artefact_type_key', 'data_product_sequence'),
        'metadata', coalesce(v_entry->'metadata', '{}'::jsonb)
      ),
      p_pool_artefact_id,
      'produced_output'
    );

    v_outputs := v_outputs || jsonb_build_array(jsonb_build_object('artefact_id', v_new, 'direction', 'output', 'io_role', 'demultiplexed_output'));
    v_relationships := v_relationships || jsonb_build_array(jsonb_build_object('parent_id', p_pool_artefact_id, 'child_id', v_new, 'relationship_type', 'produced_output'));
  END LOOP;

  RETURN app_provenance.sp_record_process_with_io(
    jsonb_build_object(
      'process_type_key', 'process_demultiplex',
      'name', 'Demultiplex outputs',
      'metadata', coalesce(p_run_metadata, '{}'::jsonb),
      'inputs', jsonb_build_array(jsonb_build_object('artefact_id', p_pool_artefact_id, 'direction', 'input', 'io_role', 'pool', 'is_primary', true)),
      'outputs', v_outputs,
      'relationships', v_relationships
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_demultiplex_outputs(uuid, jsonb, jsonb) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

CREATE OR REPLACE FUNCTION app_provenance.sp_record_storage_event(
  p_event jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, app_provenance, app_security, app_core
SET row_security = off
AS $$
DECLARE
  v_payload jsonb := coalesce(p_event, '{}'::jsonb);
  v_actor uuid := app_security.current_actor_id();
  v_event_id uuid;
  v_event_type text;
  v_from uuid;
  v_to uuid;
BEGIN
  PERFORM app_security.require_transaction_context();

  IF jsonb_typeof(v_payload) <> 'object' THEN
    RAISE EXCEPTION 'Storage event payload must be object';
  END IF;

  v_event_type := lower(coalesce(v_payload->>'event_type', 'move'));
  v_from := NULLIF(v_payload->>'from_storage_node_id','')::uuid;
  v_to := NULLIF(v_payload->>'to_storage_node_id','')::uuid;

  IF v_event_type <> 'register' AND v_from IS NULL AND v_to IS NULL THEN
    v_event_type := 'register';
  END IF;

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
  VALUES (
    (v_payload->>'artefact_id')::uuid,
    v_from,
    v_to,
    v_event_type,
    coalesce(NULLIF(v_payload->>'occurred_at','')::timestamptz, clock_timestamp()),
    coalesce(NULLIF(v_payload->>'actor_id','')::uuid, v_actor),
    NULLIF(v_payload->>'process_instance_id','')::uuid,
    v_payload->>'reason',
    coalesce(v_payload->'metadata', '{}'::jsonb) || jsonb_build_object('source', 'sp_record_storage_event')
  )
  RETURNING storage_event_id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

GRANT EXECUTE ON FUNCTION app_provenance.sp_record_storage_event(jsonb) TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-------------------------------------------------------------------------------
-- migrate:down
-------------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION app_provenance.sp_record_storage_event(jsonb) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.sp_demultiplex_outputs(uuid, jsonb, jsonb) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.sp_pool_fixed_volume(uuid[], uuid, numeric, jsonb) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.sp_plate_measurement(jsonb, jsonb) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.sp_index_libraries(uuid, jsonb, uuid) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.sp_fragment_plate(uuid, uuid, uuid, jsonb) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.sp_apply_reagent_in_place(uuid, uuid, jsonb) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.sp_record_process_with_io(jsonb) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.sp_register_labware_with_wells(text, jsonb, jsonb, uuid) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.sp_register_virtual_manifest(uuid, jsonb, text) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.sp_load_material_into_slot(uuid, jsonb, uuid, text) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.get_process_type_id(text) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;
REVOKE EXECUTE ON FUNCTION app_provenance.get_artefact_type_id(text) FROM app_auth, postgrest_authenticator, postgraphile_authenticator;

DROP FUNCTION IF EXISTS app_provenance.sp_record_storage_event(jsonb);
DROP FUNCTION IF EXISTS app_provenance.sp_demultiplex_outputs(uuid, jsonb, jsonb);
DROP FUNCTION IF EXISTS app_provenance.sp_pool_fixed_volume(uuid[], uuid, numeric, jsonb);
DROP FUNCTION IF EXISTS app_provenance.sp_plate_measurement(jsonb, jsonb);
DROP FUNCTION IF EXISTS app_provenance.sp_index_libraries(uuid, jsonb, uuid);
DROP FUNCTION IF EXISTS app_provenance.sp_fragment_plate(uuid, uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS app_provenance.sp_apply_reagent_in_place(uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS app_provenance.sp_record_process_with_io(jsonb);
DROP FUNCTION IF EXISTS app_provenance.sp_register_labware_with_wells(text, jsonb, jsonb, uuid);
DROP FUNCTION IF EXISTS app_provenance.sp_register_virtual_manifest(uuid, jsonb, text);
DROP FUNCTION IF EXISTS app_provenance.sp_load_material_into_slot(uuid, jsonb, uuid, text);
DROP FUNCTION IF EXISTS app_provenance.get_process_type_id(text);
DROP FUNCTION IF EXISTS app_provenance.get_artefact_type_id(text);

DELETE FROM app_provenance.process_types
WHERE metadata ->> 'source' = 'workflow_helpers';
