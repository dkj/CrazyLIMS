-- migrate:up

-------------------------------------------------------------------------------
-- Enforce DAG structure on lims.sample_derivations
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION lims.fn_assert_sample_derivation_dag()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  cycle_detected boolean := false;
BEGIN
  -- Skip expensive checks when the edge endpoints are unchanged
  IF TG_OP = 'UPDATE'
     AND NEW.parent_sample_id = OLD.parent_sample_id
     AND NEW.child_sample_id = OLD.child_sample_id THEN
    RETURN NEW;
  END IF;

  IF NEW.parent_sample_id = NEW.child_sample_id THEN
    RAISE EXCEPTION USING MESSAGE = 'Sample cannot derive from itself';
  END IF;

  WITH RECURSIVE descendants AS (
    SELECT sd.parent_sample_id, sd.child_sample_id
    FROM lims.sample_derivations sd
    WHERE sd.parent_sample_id = NEW.child_sample_id
    UNION
    SELECT sd.parent_sample_id, sd.child_sample_id
    FROM lims.sample_derivations sd
    JOIN descendants d ON sd.parent_sample_id = d.child_sample_id
  )
  SELECT true INTO cycle_detected
  FROM descendants
  WHERE child_sample_id = NEW.parent_sample_id
  LIMIT 1;

  IF cycle_detected THEN
    RAISE EXCEPTION USING MESSAGE = 'Sample derivation would create a cycle';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assert_sample_derivation_dag ON lims.sample_derivations;

CREATE TRIGGER trg_assert_sample_derivation_dag
AFTER INSERT OR UPDATE ON lims.sample_derivations
FOR EACH ROW
EXECUTE FUNCTION lims.fn_assert_sample_derivation_dag();

-- migrate:down

DROP TRIGGER IF EXISTS trg_assert_sample_derivation_dag ON lims.sample_derivations;
DROP FUNCTION IF EXISTS lims.fn_assert_sample_derivation_dag();
