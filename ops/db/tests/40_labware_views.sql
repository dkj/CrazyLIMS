-------------------------------------------------------------------------------
-- Convenience views include slotless labware contents
-------------------------------------------------------------------------------

SET ROLE app_admin;

DO $$
DECLARE
  v_admin_id uuid;
  v_samples text[];
BEGIN
  SELECT id INTO v_admin_id
  FROM app_core.users
  WHERE email = 'admin@example.org';

  PERFORM pg_temp.isnt_null(v_admin_id, 'Admin fixture user present for slotless labware view');

  PERFORM set_config('app.actor_id', v_admin_id::text, false);
  PERFORM set_config('app.actor_identity', 'admin@example.org', false);
  PERFORM set_config('app.roles', 'app_admin', false);

  SELECT array_agg(sample_name ORDER BY sample_name)
    INTO v_samples
    FROM app_core.v_labware_contents
   WHERE barcode = 'TUBE-0001'
     AND position_label IS NULL;

  PERFORM pg_temp.ok(v_samples IS NOT NULL AND array_length(v_samples, 1) = 2, 'Slotless labware view returned two samples');
  PERFORM pg_temp.is_deeply(
    v_samples,
    ARRAY['Organoid Expansion Batch RDX-01 Cryo Backup', 'Serum QC Control Sample'],
    'Slotless labware view returns expected sample names'
  );
END;
$$;

RESET ROLE;

-------------------------------------------------------------------------------
-- Convenience views include slotted plate labware contents
-------------------------------------------------------------------------------

SET ROLE app_admin;

DO $$
DECLARE
  v_admin_id uuid;
  v_positions text[];
BEGIN
  SELECT id INTO v_admin_id
  FROM app_core.users
  WHERE email = 'admin@example.org';

  PERFORM pg_temp.isnt_null(v_admin_id, 'Admin fixture user present for slotted labware view');

  PERFORM set_config('app.actor_id', v_admin_id::text, false);
  PERFORM set_config('app.actor_identity', 'admin@example.org', false);
  PERFORM set_config('app.roles', 'app_admin', false);

  SELECT array_agg(format('%s:%s', position_label, sample_name) ORDER BY position_label, sample_name)
    INTO v_positions
    FROM app_core.v_labware_contents
   WHERE barcode = 'PLATE-0007';

  PERFORM pg_temp.ok(
    NOT EXISTS (
      SELECT 1
        FROM app_core.v_labware_contents
       WHERE barcode = 'PLATE-0007'
         AND position_label IS NULL
    ),
    'Slotted labware view emits position labels'
  );

  PERFORM pg_temp.ok(v_positions IS NOT NULL AND array_length(v_positions, 1) = 2, 'Slotted labware view returned two rows');

  PERFORM pg_temp.is_deeply(
    v_positions,
    ARRAY['A1:Plasma Aliquot GP-001-A', 'A2:Plasma Prep Buffer Lot 42'],
    'Slotted labware view returns expected slot/name pairs'
  );
END;
$$;

RESET ROLE;
