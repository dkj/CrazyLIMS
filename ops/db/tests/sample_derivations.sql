\set ON_ERROR_STOP on
SET client_min_messages TO WARNING;

SET ROLE app_admin;

DO $$
DECLARE
  admin_id uuid;
  project_id uuid;
  sample_root uuid;
  sample_child uuid;
  sample_leaf uuid;
BEGIN
  SELECT id INTO admin_id FROM lims.users WHERE email = 'admin@example.org';
  SELECT id INTO project_id FROM lims.projects WHERE project_code = 'PRJ-001';

  SELECT id INTO sample_root FROM lims.samples WHERE name = 'Cycle Test Root';
  IF sample_root IS NULL THEN
    INSERT INTO lims.samples (name, sample_type, project_id, created_by)
    VALUES ('Cycle Test Root', 'test_root', project_id, admin_id)
    RETURNING id INTO sample_root;
  END IF;

  SELECT id INTO sample_child FROM lims.samples WHERE name = 'Cycle Test Child';
  IF sample_child IS NULL THEN
    INSERT INTO lims.samples (name, sample_type, project_id, created_by)
    VALUES ('Cycle Test Child', 'test_child', project_id, admin_id)
    RETURNING id INTO sample_child;
  END IF;

  SELECT id INTO sample_leaf FROM lims.samples WHERE name = 'Cycle Test Leaf';
  IF sample_leaf IS NULL THEN
    INSERT INTO lims.samples (name, sample_type, project_id, created_by)
    VALUES ('Cycle Test Leaf', 'test_leaf', project_id, admin_id)
    RETURNING id INTO sample_leaf;
  END IF;

  INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_by)
  VALUES (sample_root, sample_child, 'test-seed', admin_id)
  ON CONFLICT DO NOTHING;

  INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_by)
  VALUES (sample_child, sample_leaf, 'test-seed', admin_id)
  ON CONFLICT DO NOTHING;

  BEGIN
    INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_by)
    VALUES (sample_leaf, sample_root, 'cycle-test', admin_id);
    RAISE EXCEPTION 'Expected cycle prevention to trigger';
  EXCEPTION
    WHEN others THEN
      IF SQLSTATE <> 'P0001' OR position('cycle' IN SQLERRM) = 0 THEN
        RAISE;
      END IF;
  END;

  BEGIN
    INSERT INTO lims.sample_derivations (parent_sample_id, child_sample_id, method, created_by)
    VALUES (sample_child, sample_child, 'self-loop', admin_id);
    RAISE EXCEPTION 'Expected self-derivation prevention to trigger';
  EXCEPTION
    WHEN others THEN
      IF SQLSTATE <> 'P0001' OR position('self' IN SQLERRM) = 0 THEN
        RAISE;
      END IF;
  END;

  BEGIN
    UPDATE lims.sample_derivations
    SET parent_sample_id = sample_leaf
    WHERE parent_sample_id = sample_root
      AND child_sample_id = sample_child;
    RAISE EXCEPTION 'Expected cycle prevention on update to trigger';
  EXCEPTION
    WHEN others THEN
      IF SQLSTATE <> 'P0001' OR position('cycle' IN SQLERRM) = 0 THEN
        RAISE;
      END IF;
  END;

  -- Clean up the happy-path derivations and samples
  DELETE FROM lims.sample_derivations
  WHERE parent_sample_id IN (sample_root, sample_child, sample_leaf)
     OR child_sample_id IN (sample_root, sample_child, sample_leaf);

  DELETE FROM lims.samples
  WHERE id IN (sample_leaf, sample_child, sample_root);
END;
$$;

RESET ROLE;
