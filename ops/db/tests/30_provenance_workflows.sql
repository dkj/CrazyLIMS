SET ROLE app_admin;
DO $$
BEGIN
  PERFORM set_config(
    'session.roberto_id',
    (SELECT id::text FROM app_core.users WHERE email = 'roberto@example.org'),
    false
  );
END;
$$;
RESET ROLE;

SET ROLE app_researcher;

DO $$
DECLARE
  v_researcher uuid := current_setting('session.roberto_id', true)::uuid;
  v_scope uuid;
  v_result RECORD;
  v_virtual_ids uuid[] := ARRAY[]::uuid[];
  v_plate_id uuid;
  v_slot_a01 uuid;
  v_slot_a02 uuid;
  v_dest_plate uuid;
  v_dest_slot uuid;
  v_library_plate uuid;
  v_library_slot uuid;
  v_reagent uuid;
  v_treated uuid;
  v_reagent_process uuid;
  v_fragment_process uuid;
  v_fragment_output uuid;
  v_index_process uuid;
  v_measure_process uuid;
  v_pool_slot uuid;
  v_pool_process uuid;
  v_pool_output uuid;
  v_demux_process uuid;
  v_storage_event uuid;
  v_library_output uuid;
  v_types text[];
BEGIN
  PERFORM pg_temp.isnt_null(v_researcher, 'Alpha researcher fixture session id present');

  EXECUTE format('SET app.actor_id = %L', v_researcher::text);
  EXECUTE format('SET app.actor_identity = %L', 'roberto@example.org');
  EXECUTE format('SET app.roles = %L', 'app_researcher');

  SELECT scope_id INTO v_scope FROM app_security.scopes WHERE scope_key = 'project:alpha-study';
  PERFORM pg_temp.isnt_null(v_scope, 'Alpha project scope present');

  PERFORM app_security.require_transaction_context();

  SELECT array_agg(type_key ORDER BY type_key)
    INTO v_types
    FROM app_provenance.process_types
   WHERE type_key = ANY(ARRAY[
         'process_demultiplex',
         'process_fragment_plate',
         'process_indexing',
         'process_plate_measurement',
         'process_pooling',
         'process_reagent_application'
       ]);

  PERFORM pg_temp.ok(v_types IS NOT NULL AND array_length(v_types, 1) = 6, 'Workflow helper process types seeded');
  PERFORM pg_temp.ok(
    NOT EXISTS (
      SELECT 1
        FROM app_provenance.process_types
       WHERE type_key = ANY(v_types)
         AND NOT is_active
    ),
    'Workflow helper process types all active'
  );

  FOR v_result IN
    SELECT *
    FROM app_provenance.sp_register_virtual_manifest(
      v_scope,
      jsonb_build_array(
        jsonb_build_object('name','Alpha Virtual Donor 1','external_identifier','virt-donor-1','metadata', jsonb_build_object('study','alpha')),
        jsonb_build_object('name','Alpha Virtual Donor 2','external_identifier','virt-donor-2','metadata', jsonb_build_object('study','alpha'))
      )
    )
  LOOP
    v_virtual_ids := array_append(v_virtual_ids, v_result.artefact_id);
  END LOOP;

  PERFORM pg_temp.is(array_length(v_virtual_ids,1), 2, 'Virtual manifest registration created two artefacts');

  FOR v_result IN
    SELECT *
    FROM app_provenance.sp_register_labware_with_wells(
      'container_plate_96',
      jsonb_build_object('name','Alpha Source Plate','external_identifier','alpha-plate-src','metadata', jsonb_build_object('barcode','AP-SRC')),
      jsonb_build_array(
        jsonb_build_object('slot_name','A01','occupant', jsonb_build_object('name','Alpha A01','artefact_type_key','material_sample','parent_artefact_id', v_virtual_ids[1])),
        jsonb_build_object('slot_name','A02')
      ),
      v_scope
    )
  LOOP
    v_plate_id := v_result.container_id;
    IF v_result.slot_name = 'A01' THEN
      v_slot_a01 := v_result.slot_id;
    ELSIF v_result.slot_name = 'A02' THEN
      v_slot_a02 := v_result.slot_id;
    END IF;
  END LOOP;

  PERFORM pg_temp.ok(
    v_plate_id IS NOT NULL AND v_slot_a01 IS NOT NULL AND v_slot_a02 IS NOT NULL,
    'Source plate registration returned expected slots'
  );

  PERFORM app_provenance.sp_load_material_into_slot(
    v_slot_a02,
    jsonb_build_object('name','Alpha A02','metadata', jsonb_build_object('volume_ul', 50)),
    v_virtual_ids[2],
    'derived_from'
  );

  v_reagent := app_provenance.sp_load_material_into_slot(
    NULL,
    jsonb_build_object('name','Alpha Buffer Reagent','artefact_type_key','reagent_buffer','metadata', jsonb_build_object('lot','BR-001'))
  );

  v_treated := app_provenance.sp_apply_reagent_in_place(
    v_slot_a02,
    v_reagent,
    jsonb_build_object('name','Alpha A02 Treated')
  );

  PERFORM pg_temp.isnt_null(v_treated, 'Reagent application returned treated artefact');

  SELECT pi.process_instance_id
    INTO v_reagent_process
    FROM app_provenance.process_instances pi
    JOIN app_provenance.process_io io ON io.process_instance_id = pi.process_instance_id
   WHERE io.artefact_id = v_treated
     AND io.direction = 'output'
   ORDER BY pi.created_at DESC
   LIMIT 1;

  PERFORM pg_temp.isnt_null(v_reagent_process, 'Reagent application recorded process instance');

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.process_io
       WHERE process_instance_id = v_reagent_process
         AND artefact_id = v_reagent
         AND io_role = 'reagent'
         AND direction = 'input'
    ),
    'Reagent application recorded reagent input IO'
  );

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.process_io
       WHERE process_instance_id = v_reagent_process
         AND artefact_id = v_treated
         AND direction = 'output'
         AND io_role = 'treated_output'
    ),
    'Reagent application recorded treated output IO'
  );

  FOR v_result IN
    SELECT *
    FROM app_provenance.sp_register_labware_with_wells(
      'container_plate_96',
      jsonb_build_object('name','Alpha Fragment Plate','external_identifier','alpha-plate-frag'),
      jsonb_build_array(jsonb_build_object('slot_name','A01')),
      v_scope
    )
  LOOP
    v_dest_plate := v_result.container_id;
    IF v_result.slot_name = 'A01' THEN
      v_dest_slot := v_result.slot_id;
    END IF;
  END LOOP;

  v_fragment_process := app_provenance.sp_fragment_plate(
    v_plate_id,
    v_reagent,
    v_dest_plate,
    jsonb_build_array(jsonb_build_object('source_slot','A02','dest_slot','A01','output_name','Fragment A01'))
  );

  PERFORM pg_temp.isnt_null(v_fragment_process, 'Fragmentation helper returned process instance');

  SELECT artefact_id INTO v_fragment_output
    FROM app_provenance.artefacts
   WHERE container_slot_id = v_dest_slot
   ORDER BY updated_at DESC
   LIMIT 1;

  PERFORM pg_temp.isnt_null(v_fragment_output, 'Fragment destination well produced artefact');

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.process_io
       WHERE process_instance_id = v_fragment_process
         AND artefact_id = v_fragment_output
         AND direction = 'output'
         AND io_role = 'fragment_output'
    ),
    'Fragment process recorded output IO'
  );

  PERFORM pg_temp.is(
    (
      SELECT direction
        FROM app_provenance.process_io
       WHERE process_instance_id = v_fragment_process
         AND artefact_id = v_fragment_output
         AND io_role = 'fragment_output'
       LIMIT 1
    ),
    'output',
    'Fragment output direction recorded as output'
  );

  PERFORM pg_temp.is(
    (
      SELECT COUNT(*)
        FROM app_provenance.process_io
       WHERE process_instance_id = v_fragment_process
         AND direction IS NULL
    ),
    0,
    'Fragment process recorded no NULL IO directions'
  );

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.process_io
       WHERE process_instance_id = v_fragment_process
         AND artefact_id = v_reagent
         AND io_role = 'reagent'
         AND direction = 'input'
    ),
    'Fragment process recorded reagent IO'
  );

  FOR v_result IN
    SELECT *
    FROM app_provenance.sp_register_labware_with_wells(
      'container_plate_96',
      jsonb_build_object('name','Alpha Library Plate','external_identifier','alpha-plate-lib'),
      jsonb_build_array(jsonb_build_object('slot_name','A01')),
      v_scope
    )
  LOOP
    v_library_plate := v_result.container_id;
    IF v_result.slot_name = 'A01' THEN
      v_library_slot := v_result.slot_id;
    END IF;
  END LOOP;

  v_index_process := app_provenance.sp_index_libraries(
    v_dest_plate,
    jsonb_build_array(jsonb_build_object('source_slot','A01','dest_slot','A01','index_pair','IDX-A01')),
    v_library_plate
  );

  PERFORM pg_temp.isnt_null(v_index_process, 'Indexing helper returned process instance');

  SELECT artefact_id
    INTO v_library_output
    FROM app_provenance.artefacts
   WHERE container_slot_id = v_library_slot
   ORDER BY updated_at DESC
   LIMIT 1;

  PERFORM pg_temp.isnt_null(v_library_output, 'Library plate slot populated with output artefact');

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.process_io
       WHERE process_instance_id = v_index_process
         AND artefact_id = v_library_output
         AND direction = 'output'
         AND io_role = 'library_output'
    ),
    'Indexing process recorded library output IO'
  );

  PERFORM pg_temp.is(
    (
      SELECT direction
        FROM app_provenance.process_io
       WHERE process_instance_id = v_index_process
         AND artefact_id = v_library_output
         AND io_role = 'library_output'
       LIMIT 1
    ),
    'output',
    'Indexing output direction recorded as output'
  );

  PERFORM pg_temp.is(
    (
      SELECT COUNT(*)
        FROM app_provenance.process_io
       WHERE process_instance_id = v_index_process
         AND direction IS NULL
    ),
    0,
    'Indexing process recorded no NULL IO directions'
  );

  v_measure_process := app_provenance.sp_plate_measurement(
    jsonb_build_object('plate_id', v_library_plate::text, 'process_type_key','process_plate_measurement', 'name','Library QC'),
    jsonb_build_array(jsonb_build_object('slot_name','A01','traits', jsonb_build_object('concentration_ng_ul', 22.5)))
  );

  PERFORM pg_temp.isnt_null(v_measure_process, 'Plate measurement helper returned process instance');

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.process_instances
       WHERE process_instance_id = v_measure_process
         AND status = 'completed'
    ),
    'Plate measurement process recorded as completed'
  );

  PERFORM pg_temp.is(
    coalesce((SELECT metadata ->> 'concentration_ng_ul'
                FROM app_provenance.artefacts
               WHERE artefact_id = v_library_output
               ORDER BY updated_at DESC
               LIMIT 1), ''),
    '22.5',
    'Plate measurement traits applied to library artefact'
  );

  FOR v_result IN
    SELECT *
    FROM app_provenance.sp_register_labware_with_wells(
      'container_cryovial_2ml',
      jsonb_build_object('name','Alpha Pool Tube','external_identifier','alpha-pool-001'),
      jsonb_build_array(jsonb_build_object('slot_name','TUBE')),
      v_scope
    )
  LOOP
    v_pool_slot := v_result.slot_id;
  END LOOP;

  v_pool_process := app_provenance.sp_pool_fixed_volume(
    ARRAY[v_slot_a01, v_dest_slot],
    v_pool_slot,
    10,
    jsonb_build_object('name','Alpha Pool')
  );

  PERFORM pg_temp.isnt_null(v_pool_process, 'Pooling helper returned process instance');

  PERFORM pg_temp.is(
    (
      SELECT COUNT(*)
        FROM app_provenance.process_io
       WHERE process_instance_id = v_pool_process
         AND direction = 'pooled_input'
         AND io_role = 'pool_component'
    ),
    2,
    'Pooling process recorded two component IO rows'
  );

  SELECT artefact_id INTO v_pool_output
    FROM app_provenance.artefacts
   WHERE container_slot_id = v_pool_slot
   ORDER BY updated_at DESC
   LIMIT 1;

  PERFORM pg_temp.isnt_null(v_pool_output, 'Pooling helper created output artefact');

  v_demux_process := app_provenance.sp_demultiplex_outputs(
    v_pool_output,
    jsonb_build_object('run_id','RUN-001'),
      jsonb_build_array(
      jsonb_build_object('name','FASTQ R1','artefact_type_key','data_product_sequence'),
      jsonb_build_object('name','FASTQ R2','artefact_type_key','data_product_sequence')
    )
  );

  PERFORM pg_temp.isnt_null(v_demux_process, 'Demultiplex helper returned process instance');

  PERFORM pg_temp.is(
    (
      SELECT COUNT(*)
        FROM app_provenance.process_io
       WHERE process_instance_id = v_demux_process
         AND direction = 'output'
         AND io_role = 'demultiplexed_output'
    ),
    2,
    'Demultiplex process recorded two output artefacts'
  );

  v_storage_event := app_provenance.sp_record_storage_event(
    jsonb_build_object(
      'artefact_id', v_pool_output::text,
      'event_type', 'move',
      'reason', 'Unit test placement'
    )
  );

  PERFORM pg_temp.isnt_null(v_storage_event, 'Storage event helper returned identifier');

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.artefact_storage_events
       WHERE storage_event_id = v_storage_event
         AND reason = 'Unit test placement'
    ),
    'Storage event recorded with expected reason'
  );

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.artefact_relationships
       WHERE parent_artefact_id = v_virtual_ids[1]
         AND child_artefact_id IN (
           SELECT artefact_id FROM app_provenance.artefacts WHERE container_slot_id = v_slot_a01
         )
    ),
    'Virtual manifest linked to well occupant'
  );

  PERFORM pg_temp.is(
    (
      SELECT COUNT(*)
        FROM app_provenance.artefact_relationships
       WHERE child_artefact_id = v_pool_output
         AND relationship_type = 'pooled_from'
    ),
    2,
    'Pooling relationships recorded for both sources'
  );

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.process_instances
       WHERE process_instance_id = v_pool_process
    ),
    'Pooling process persisted'
  );

  PERFORM pg_temp.ok(
    EXISTS (
      SELECT 1
        FROM app_provenance.process_io
       WHERE process_instance_id = v_demux_process
         AND direction = 'output'
         AND io_role = 'demultiplexed_output'
    ),
    'Demultiplex outputs persisted'
  );
END;
$$;

RESET ROLE;
