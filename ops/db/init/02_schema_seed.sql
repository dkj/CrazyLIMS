\connect lims;

-- === Users (Phase0: very simple; map to JWT later) ===
CREATE TABLE lims.users (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email       text UNIQUE NOT NULL,
  full_name   text NOT NULL,
  role        text NOT NULL CHECK (role IN ('admin','scientist','lab_tech')),
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- === Samples (inventory seed) ===
CREATE TABLE lims.samples (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id   text UNIQUE,                 -- barcode/QR or external code
  name          text NOT NULL,
  sample_type   text NOT NULL,
  project_code  text,
  parent_id     uuid REFERENCES lims.samples(id) ON DELETE SET NULL,
  created_by    uuid REFERENCES lims.users(id),
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- === Audit Log ===
CREATE TABLE lims.audit_log (
  id           bigserial PRIMARY KEY,
  ts           timestamptz NOT NULL DEFAULT now(),
  actor        text,              -- later: from JWT claims
  action       text NOT NULL,     -- INSERT/UPDATE/DELETE
  table_name   text NOT NULL,
  row_pk       text,
  diff         jsonb              -- optional: before/after
);

CREATE OR REPLACE FUNCTION lims.fn_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  pk text;
BEGIN
  pk := COALESCE(NEW.id::text, OLD.id::text, null);
  INSERT INTO lims.audit_log(actor, action, table_name, row_pk, diff)
  VALUES (current_user, TG_OP, TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME, pk,
          CASE
            WHEN TG_OP = 'INSERT' THEN jsonb_build_object('new', to_jsonb(NEW))
            WHEN TG_OP = 'UPDATE' THEN jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW))
            WHEN TG_OP = 'DELETE' THEN jsonb_build_object('old', to_jsonb(OLD))
          END);
  RETURN COALESCE(NEW, OLD);
END $$;

ALTER FUNCTION lims.fn_audit() OWNER TO postgres;
ALTER FUNCTION lims.fn_audit() SET search_path = pg_catalog, lims;

CREATE TRIGGER trg_audit_users
AFTER INSERT OR UPDATE OR DELETE ON lims.users
FOR EACH ROW EXECUTE FUNCTION lims.fn_audit();

CREATE TRIGGER trg_audit_samples
AFTER INSERT OR UPDATE OR DELETE ON lims.samples
FOR EACH ROW EXECUTE FUNCTION lims.fn_audit();

-- === RLS (enable; simple Phase0 policy) ===
ALTER TABLE lims.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.samples ENABLE ROW LEVEL SECURITY;

-- For Phase0: allow read to anon, full access to dev (you'll tighten later)
CREATE POLICY p_users_select ON lims.users FOR SELECT TO web_anon USING (true);
CREATE POLICY p_samples_select ON lims.samples FOR SELECT TO web_anon USING (true);

CREATE POLICY p_users_dev_all ON lims.users FOR ALL TO dev USING (true) WITH CHECK (true);
CREATE POLICY p_samples_dev_all ON lims.samples FOR ALL TO dev USING (true) WITH CHECK (true);

GRANT SELECT ON ALL TABLES IN SCHEMA lims TO web_anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lims TO dev;
REVOKE ALL ON lims.audit_log FROM dev;
GRANT SELECT ON lims.audit_log TO dev;

-- Seed an admin user and a couple of samples
INSERT INTO lims.users(email, full_name, role) VALUES
('admin@example.org','Admin User','admin'),
('alice@example.org','Alice Scientist','scientist');

INSERT INTO lims.samples(name, sample_type, project_code, created_by) VALUES
('PBMC Batch 001','cell','PRJ-001',(SELECT id FROM lims.users WHERE email='alice@example.org')),
('Serum Tube A','fluid','PRJ-002',(SELECT id FROM lims.users WHERE email='alice@example.org'));
