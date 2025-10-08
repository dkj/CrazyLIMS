-- migrate:up
WITH parent AS (
  SELECT
    s.id,
    COALESCE(s.created_by, creator.id) AS created_by,
    s.project_code
  FROM lims.samples s
  LEFT JOIN lims.users creator ON creator.email = 'alice@example.org'
  WHERE s.name = 'PBMC Batch 001'
  LIMIT 1
),
seed_samples AS (
  SELECT
    parent.id AS parent_id,
    parent.created_by,
    parent.project_code,
    seed.name,
    seed.sample_type,
    'seed:aliquot'::text AS method
  FROM parent,
  LATERAL (
    VALUES
      ('PBMC Batch 001 - Aliquot A', 'cell_aliquot'),
      ('PBMC Batch 001 - Aliquot B', 'cell_aliquot')
  ) AS seed(name, sample_type)
)
INSERT INTO lims.samples (name, sample_type, project_code, created_by)
SELECT ss.name, ss.sample_type, ss.project_code, ss.created_by
FROM seed_samples ss
WHERE NOT EXISTS (
  SELECT 1 FROM lims.samples existing WHERE existing.name = ss.name
);

WITH parent AS (
  SELECT
    s.id,
    COALESCE(s.created_by, creator.id) AS created_by,
    s.project_code
  FROM lims.samples s
  LEFT JOIN lims.users creator ON creator.email = 'alice@example.org'
  WHERE s.name = 'PBMC Batch 001'
  LIMIT 1
),
children AS (
  SELECT
    child.id,
    child.name,
    parent.id AS parent_id,
    parent.created_by
  FROM parent
  JOIN lims.samples child ON child.name IN (
    'PBMC Batch 001 - Aliquot A',
    'PBMC Batch 001 - Aliquot B'
  )
)
INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_by)
SELECT
  children.parent_id,
  children.id,
  'seed:aliquot',
  children.created_by
FROM children
LEFT JOIN lims.sample_derivations existing
  ON existing.parent_sample_id = children.parent_id
 AND existing.child_sample_id = children.id
WHERE existing.id IS NULL;

WITH parent AS (
  SELECT
    s.id,
    COALESCE(s.created_by, creator.id) AS created_by,
    s.project_code
  FROM lims.samples s
  LEFT JOIN lims.users creator ON creator.email = 'alice@example.org'
  WHERE s.name = 'PBMC Batch 001 - Aliquot A'
  LIMIT 1
),
seed_samples AS (
  SELECT
    parent.id AS parent_id,
    parent.created_by,
    parent.project_code,
    'PBMC Batch 001 - Aliquot A - Cryovial 1'::text AS name,
    'cryovial'::text AS sample_type,
    'seed:cryovial'::text AS method
  FROM parent
)
INSERT INTO lims.samples (name, sample_type, project_code, created_by)
SELECT ss.name, ss.sample_type, ss.project_code, ss.created_by
FROM seed_samples ss
WHERE NOT EXISTS (
  SELECT 1 FROM lims.samples existing WHERE existing.name = ss.name
);

WITH parent AS (
  SELECT
    s.id,
    COALESCE(s.created_by, creator.id) AS created_by
  FROM lims.samples s
  LEFT JOIN lims.users creator ON creator.email = 'alice@example.org'
  WHERE s.name = 'PBMC Batch 001 - Aliquot A'
  LIMIT 1
),
child AS (
  SELECT
    parent.id AS parent_id,
    parent.created_by,
    sample.id AS child_id
  FROM parent
  JOIN lims.samples sample ON sample.name = 'PBMC Batch 001 - Aliquot A - Cryovial 1'
)
INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_by)
SELECT child.parent_id, child.child_id, 'seed:cryovial', child.created_by
FROM child
LEFT JOIN lims.sample_derivations existing
  ON existing.parent_sample_id = child.parent_id
 AND existing.child_sample_id = child.child_id
WHERE existing.id IS NULL;

WITH parent AS (
  SELECT
    s.id,
    COALESCE(s.created_by, creator.id) AS created_by,
    s.project_code
  FROM lims.samples s
  LEFT JOIN lims.users creator ON creator.email = 'alice@example.org'
  WHERE s.name = 'Participant 001 Blood Draw'
  LIMIT 1
),
seed_samples AS (
  SELECT
    parent.id AS parent_id,
    parent.created_by,
    parent.project_code,
    seed.name,
    seed.sample_type,
    'seed:fraction'::text AS method
  FROM parent,
  LATERAL (
    VALUES
      ('Participant 001 Blood Draw - Plasma Fraction', 'fraction_plasma'),
      ('Participant 001 Blood Draw - Buffy Coat Fraction', 'fraction_buffy_coat')
  ) AS seed(name, sample_type)
)
INSERT INTO lims.samples (name, sample_type, project_code, created_by)
SELECT ss.name, ss.sample_type, ss.project_code, ss.created_by
FROM seed_samples ss
WHERE NOT EXISTS (
  SELECT 1 FROM lims.samples existing WHERE existing.name = ss.name
);

WITH parent AS (
  SELECT
    s.id,
    COALESCE(s.created_by, creator.id) AS created_by
  FROM lims.samples s
  LEFT JOIN lims.users creator ON creator.email = 'alice@example.org'
  WHERE s.name = 'Participant 001 Blood Draw'
  LIMIT 1
),
children AS (
  SELECT
    child.id,
    child.name,
    parent.id AS parent_id,
    parent.created_by
  FROM parent
  JOIN lims.samples child ON child.name IN (
    'Participant 001 Blood Draw - Plasma Fraction',
    'Participant 001 Blood Draw - Buffy Coat Fraction'
  )
)
INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_by)
SELECT
  children.parent_id,
  children.id,
  'seed:fraction',
  children.created_by
FROM children
LEFT JOIN lims.sample_derivations existing
  ON existing.parent_sample_id = children.parent_id
 AND existing.child_sample_id = children.id
WHERE existing.id IS NULL;

WITH parent AS (
  SELECT
    s.id,
    COALESCE(s.created_by, creator.id) AS created_by,
    s.project_code
  FROM lims.samples s
  LEFT JOIN lims.users creator ON creator.email = 'alice@example.org'
  WHERE s.name = 'Participant 001 Blood Draw - Plasma Fraction'
  LIMIT 1
),
seed_sample AS (
  SELECT
    parent.id AS parent_id,
    parent.created_by,
    parent.project_code,
    'Participant 001 Blood Draw - Plasma Fraction - LCMS Prep'::text AS name,
    'analysis_prep'::text AS sample_type,
    'seed:prep'::text AS method
  FROM parent
)
INSERT INTO lims.samples (name, sample_type, project_code, created_by)
SELECT ss.name, ss.sample_type, ss.project_code, ss.created_by
FROM seed_sample ss
WHERE NOT EXISTS (
  SELECT 1 FROM lims.samples existing WHERE existing.name = ss.name
);

WITH parent AS (
  SELECT
    s.id,
    COALESCE(s.created_by, creator.id) AS created_by
  FROM lims.samples s
  LEFT JOIN lims.users creator ON creator.email = 'alice@example.org'
  WHERE s.name = 'Participant 001 Blood Draw - Plasma Fraction'
  LIMIT 1
),
child AS (
  SELECT
    parent.id AS parent_id,
    parent.created_by,
    sample.id AS child_id
  FROM parent
  JOIN lims.samples sample ON sample.name = 'Participant 001 Blood Draw - Plasma Fraction - LCMS Prep'
)
INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_by)
SELECT child.parent_id, child.child_id, 'seed:prep', child.created_by
FROM child
LEFT JOIN lims.sample_derivations existing
  ON existing.parent_sample_id = child.parent_id
 AND existing.child_sample_id = child.child_id
WHERE existing.id IS NULL;


-- migrate:down

WITH target AS (
  SELECT id
  FROM lims.samples
  WHERE name IN (
    'PBMC Batch 001 - Aliquot A - Cryovial 1',
    'PBMC Batch 001 - Aliquot A',
    'PBMC Batch 001 - Aliquot B',
    'Participant 001 Blood Draw - Plasma Fraction - LCMS Prep',
    'Participant 001 Blood Draw - Plasma Fraction',
    'Participant 001 Blood Draw - Buffy Coat Fraction'
  )
)
DELETE FROM lims.sample_derivations
WHERE child_sample_id IN (SELECT id FROM target)
   OR parent_sample_id IN (SELECT id FROM target);

DELETE FROM lims.samples
WHERE id IN (SELECT id FROM target);
