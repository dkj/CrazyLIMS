-- migrate:up
-- Add 'storage' as a first-class artefact kind and update storage types
-- avoid altering session search_path in migration (dbmate)

-- Relax and recreate the CHECK to include 'storage'
ALTER TABLE app_provenance.artefact_types
  DROP CONSTRAINT IF EXISTS artefact_types_kind_check;

ALTER TABLE app_provenance.artefact_types
  ADD CONSTRAINT artefact_types_kind_check
  CHECK (kind IN (
    'subject',
    'material',
    'reagent',
    'container',
    'data_product',
    'instrument_run',
    'workflow',
    'instrument',
    'virtual',
    'storage',
    'other'
  ));

-- Update existing storage_* type rows to use kind = 'storage'
UPDATE app_provenance.artefact_types
   SET kind = 'storage'
 WHERE type_key IN (
   'storage_facility','storage_unit','storage_sublocation','storage_virtual','storage_external'
 );

-- migrate:down
-- Revert 'storage' kind addition (will set kind back to 'other' for storage_* rows)
UPDATE app_provenance.artefact_types
   SET kind = 'other'
 WHERE type_key IN (
   'storage_facility','storage_unit','storage_sublocation','storage_virtual','storage_external'
 );

ALTER TABLE app_provenance.artefact_types
  DROP CONSTRAINT IF EXISTS artefact_types_kind_check;

ALTER TABLE app_provenance.artefact_types
  ADD CONSTRAINT artefact_types_kind_check
  CHECK (kind IN (
    'subject',
    'material',
    'reagent',
    'container',
    'data_product',
    'instrument_run',
    'workflow',
    'instrument',
    'virtual',
    'other'
  ));
