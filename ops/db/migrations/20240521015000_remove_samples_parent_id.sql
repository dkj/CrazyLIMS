-- migrate:up

-- Backfill legacy parent relationships into sample_derivations before removing parent_id.
INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_at, created_by)
SELECT
  s.parent_id,
  s.id,
  'aliquoting (legacy import)'::text,
  COALESCE(s.created_at, now()),
  s.created_by
FROM lims.samples s
LEFT JOIN lims.sample_derivations sd
  ON sd.parent_sample_id = s.parent_id
 AND sd.child_sample_id = s.id
WHERE s.parent_id IS NOT NULL
  AND sd.id IS NULL;

ALTER TABLE lims.samples DROP CONSTRAINT IF EXISTS samples_parent_id_fkey;
ALTER TABLE lims.samples DROP COLUMN IF EXISTS parent_id;

-- migrate:down

ALTER TABLE lims.samples ADD COLUMN parent_id uuid;
ALTER TABLE lims.samples
  ADD CONSTRAINT samples_parent_id_fkey
  FOREIGN KEY (parent_id) REFERENCES lims.samples(id) ON DELETE SET NULL;

WITH candidate_parents AS (
  SELECT
    sd.child_sample_id AS sample_id,
    sd.parent_sample_id,
    sd.created_at,
    sd.created_by,
    ROW_NUMBER() OVER (
      PARTITION BY sd.child_sample_id
      ORDER BY sd.created_at ASC
    ) AS rn
  FROM lims.sample_derivations sd
)
UPDATE lims.samples s
SET parent_id = cp.parent_sample_id
FROM candidate_parents cp
WHERE cp.rn = 1
  AND s.id = cp.sample_id;
