\set ON_ERROR_STOP on
SET client_min_messages TO NOTICE;

-------------------------------------------------------------------------------
-- Lightweight assertion helpers (session-scoped, no external extensions)
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION pg_temp.__test_notice(context text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE NOTICE 'ok - %', context;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.__test_fail(context text, detail text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF detail IS NULL THEN
    RAISE EXCEPTION 'Test failed: %', context;
  ELSE
    RAISE EXCEPTION 'Test failed: % (%).', context, detail;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.ok(condition boolean, context text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF coalesce(condition, false) THEN
    PERFORM pg_temp.__test_notice(context);
  ELSE
    PERFORM pg_temp.__test_fail(context);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.is(actual anycompatible, expected anycompatible, context text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF actual IS DISTINCT FROM expected THEN
    PERFORM pg_temp.__test_fail(
      context,
      format('expected %, got %', expected, actual)
    );
  ELSE
    PERFORM pg_temp.__test_notice(context);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.isnt_null(value anycompatible, context text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF value IS NULL THEN
    PERFORM pg_temp.__test_fail(context, 'value was NULL');
  ELSE
    PERFORM pg_temp.__test_notice(context);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.cmp_ok(actual anycompatible, operator text, expected anycompatible, context text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  result boolean;
  left_text text := coalesce(actual::text, 'NULL');
  right_text text := coalesce(expected::text, 'NULL');
BEGIN
  IF operator NOT IN ('=', '<>', '<', '<=', '>', '>=') THEN
    RAISE EXCEPTION 'Test failed: % (unsupported comparator %)', context, operator;
  END IF;

  EXECUTE format('SELECT ($1 %s $2)::boolean', operator)
    INTO result
    USING actual, expected;

  IF coalesce(result, false) THEN
    PERFORM pg_temp.__test_notice(context);
  ELSE
    PERFORM pg_temp.__test_fail(
      context,
      format('comparison failed: %s %s %s', left_text, operator, right_text)
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.is_deeply(actual anycompatiblearray, expected anycompatiblearray, context text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF actual IS DISTINCT FROM expected THEN
    PERFORM pg_temp.__test_fail(
      context,
      format('expected %, got %', expected, actual)
    );
  ELSE
    PERFORM pg_temp.__test_notice(context);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.fail(context text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.__test_fail(context);
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.throws_like(sql text, expected text, context text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  err_text text;
BEGIN
  BEGIN
    EXECUTE sql;
    PERFORM pg_temp.__test_fail(
      context,
      format('expected error like %, but command succeeded', expected)
    );
  EXCEPTION
    WHEN others THEN
      err_text := SQLERRM;
      IF err_text LIKE expected THEN
        PERFORM pg_temp.__test_notice(context);
      ELSE
        PERFORM pg_temp.__test_fail(
          context,
          format('expected error like %, got %', expected, err_text)
        );
      END IF;
  END;
END;
$$;

SET search_path = pg_temp, public, app_core, app_security, app_provenance;

-------------------------------------------------------------------------------
-- Ensure new schemas exist
-------------------------------------------------------------------------------

DO $$
BEGIN
  PERFORM pg_temp.ok(
    EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app_core'),
    'app_core schema exists'
  );
  PERFORM pg_temp.ok(
    EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app_security'),
    'app_security schema exists'
  );
END;
$$;
