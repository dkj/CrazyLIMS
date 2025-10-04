-- migrate:up
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SCHEMA IF NOT EXISTS lims AUTHORIZATION postgres;
ALTER SCHEMA lims OWNER TO postgres;
GRANT USAGE ON SCHEMA lims TO web_anon, app_auth, dev;
GRANT CREATE ON SCHEMA lims TO dev;

CREATE TABLE IF NOT EXISTS lims.users (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email      text UNIQUE NOT NULL,
  full_name  text NOT NULL,
  role       text NOT NULL CHECK (role IN ('admin', 'scientist', 'lab_tech')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lims.samples (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id  text UNIQUE,
  name         text NOT NULL,
  sample_type  text NOT NULL,
  project_code text,
  parent_id    uuid REFERENCES lims.samples(id) ON DELETE SET NULL,
  created_by   uuid REFERENCES lims.users(id),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lims.audit_log (
  id         bigserial PRIMARY KEY,
  ts         timestamptz NOT NULL DEFAULT now(),
  actor      text,
  action     text NOT NULL,
  table_name text NOT NULL,
  row_pk     text,
  diff       jsonb
);

CREATE OR REPLACE FUNCTION lims.fn_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  pk text;
BEGIN
  pk := COALESCE(NEW.id::text, OLD.id::text, NULL);
  INSERT INTO lims.audit_log(actor, action, table_name, row_pk, diff)
  VALUES (
    current_user,
    TG_OP,
    TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
    pk,
    CASE
      WHEN TG_OP = 'INSERT' THEN jsonb_build_object('new', to_jsonb(NEW))
      WHEN TG_OP = 'UPDATE' THEN jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW))
      WHEN TG_OP = 'DELETE' THEN jsonb_build_object('old', to_jsonb(OLD))
    END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

ALTER FUNCTION lims.fn_audit() OWNER TO postgres;
ALTER FUNCTION lims.fn_audit() SET search_path = pg_catalog, lims;

DROP TRIGGER IF EXISTS trg_audit_users ON lims.users;
CREATE TRIGGER trg_audit_users
AFTER INSERT OR UPDATE OR DELETE ON lims.users
FOR EACH ROW EXECUTE FUNCTION lims.fn_audit();

DROP TRIGGER IF EXISTS trg_audit_samples ON lims.samples;
CREATE TRIGGER trg_audit_samples
AFTER INSERT OR UPDATE OR DELETE ON lims.samples
FOR EACH ROW EXECUTE FUNCTION lims.fn_audit();

ALTER TABLE lims.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.samples ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_users_select ON lims.users;
CREATE POLICY p_users_select ON lims.users FOR SELECT TO web_anon USING (TRUE);

DROP POLICY IF EXISTS p_samples_select ON lims.samples;
CREATE POLICY p_samples_select ON lims.samples FOR SELECT TO web_anon USING (TRUE);

DROP POLICY IF EXISTS p_users_dev_all ON lims.users;
CREATE POLICY p_users_dev_all ON lims.users FOR ALL TO dev USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS p_samples_dev_all ON lims.samples;
CREATE POLICY p_samples_dev_all ON lims.samples FOR ALL TO dev USING (TRUE) WITH CHECK (TRUE);

GRANT SELECT ON ALL TABLES IN SCHEMA lims TO web_anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lims TO app_auth;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA lims TO app_auth;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lims TO dev;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA lims TO dev;

REVOKE ALL ON lims.audit_log FROM dev;
GRANT SELECT ON lims.audit_log TO dev;

REVOKE ALL ON lims.audit_log FROM app_auth;
GRANT SELECT ON lims.audit_log TO app_auth;

INSERT INTO lims.users(email, full_name, role)
SELECT email, full_name, role
FROM (
  VALUES
    ('admin@example.org', 'Admin User', 'admin'),
    ('alice@example.org', 'Alice Scientist', 'scientist')
) AS seed(email, full_name, role)
WHERE NOT EXISTS (SELECT 1 FROM lims.users u WHERE u.email = seed.email);

INSERT INTO lims.samples(name, sample_type, project_code, created_by)
SELECT seed.name, seed.sample_type, seed.project_code, seed.created_by
FROM (
  VALUES
    (
      'PBMC Batch 001',
      'cell',
      'PRJ-001',
      (SELECT id FROM lims.users WHERE email = 'alice@example.org')
    ),
    (
      'Serum Tube A',
      'fluid',
      'PRJ-002',
      (SELECT id FROM lims.users WHERE email = 'alice@example.org')
    )
) AS seed(name, sample_type, project_code, created_by)
WHERE NOT EXISTS (
  SELECT 1 FROM lims.samples s WHERE s.name = seed.name AND COALESCE(s.project_code, '') = COALESCE(seed.project_code, '')
);

-- migrate:down
DELETE FROM lims.samples WHERE name IN ('PBMC Batch 001', 'Serum Tube A');
DELETE FROM lims.users WHERE email IN ('admin@example.org', 'alice@example.org');

REVOKE SELECT ON lims.audit_log FROM app_auth;
REVOKE SELECT ON lims.audit_log FROM dev;

REVOKE SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lims FROM dev;
REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA lims FROM dev;
REVOKE SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lims FROM app_auth;
REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA lims FROM app_auth;
REVOKE SELECT ON ALL TABLES IN SCHEMA lims FROM web_anon;

DROP POLICY IF EXISTS p_samples_dev_all ON lims.samples;
DROP POLICY IF EXISTS p_users_dev_all ON lims.users;
DROP POLICY IF EXISTS p_samples_select ON lims.samples;
DROP POLICY IF EXISTS p_users_select ON lims.users;

ALTER TABLE lims.samples DISABLE ROW LEVEL SECURITY;
ALTER TABLE lims.users DISABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_audit_samples ON lims.samples;
DROP TRIGGER IF EXISTS trg_audit_users ON lims.users;
DROP FUNCTION IF EXISTS lims.fn_audit();

DROP TABLE IF EXISTS lims.audit_log;
DROP TABLE IF EXISTS lims.samples;
DROP TABLE IF EXISTS lims.users;

REVOKE CREATE ON SCHEMA lims FROM dev;
REVOKE USAGE ON SCHEMA lims FROM dev;
REVOKE USAGE ON SCHEMA lims FROM app_auth;
REVOKE USAGE ON SCHEMA lims FROM web_anon;

DROP SCHEMA IF EXISTS lims CASCADE;
