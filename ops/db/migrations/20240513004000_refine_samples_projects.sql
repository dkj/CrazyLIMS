-- migrate:up

-- Project catalog to scope sample visibility
CREATE TABLE IF NOT EXISTS lims.projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_code text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES lims.users(id)
);

CREATE TABLE IF NOT EXISTS lims.project_members (
  project_id uuid NOT NULL REFERENCES lims.projects(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES lims.users(id) ON DELETE CASCADE,
  member_role text,
  added_at timestamptz NOT NULL DEFAULT now(),
  added_by uuid REFERENCES lims.users(id),
  PRIMARY KEY (project_id, user_id)
);

-- Helper to evaluate project access consistently across policies
CREATE OR REPLACE FUNCTION lims.can_access_project(p_project_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
BEGIN
  IF p_project_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF lims.has_role('app_admin') OR lims.has_role('app_operator') THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM lims.project_members pm
    WHERE pm.project_id = p_project_id
      AND pm.user_id = lims.current_user_id()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION lims.can_access_project(uuid)
  TO app_auth, postgrest_authenticator, postgraphile_authenticator;

-- Ensure existing samples reference a project row via UUID key
ALTER TABLE lims.samples
  ADD COLUMN IF NOT EXISTS project_id uuid;

-- Seed projects from existing sample project codes (idempotent)
INSERT INTO lims.projects(project_code, name, created_by)
SELECT DISTINCT s.project_code, s.project_code, u.id
FROM lims.samples s
LEFT JOIN lims.users u ON u.email = 'admin@example.org'
WHERE s.project_code IS NOT NULL
ON CONFLICT (project_code) DO UPDATE SET name = EXCLUDED.name;

UPDATE lims.samples s
SET project_id = p.id
FROM lims.projects p
WHERE s.project_code IS NOT NULL
  AND p.project_code = s.project_code
  AND (s.project_id IS NULL OR s.project_id <> p.id);

-- Create placeholder project for rows without a code
DO $$
DECLARE
  admin_id uuid;
  fallback_project_id uuid;
BEGIN
  SELECT id INTO admin_id FROM lims.users WHERE email = 'admin@example.org';

  IF EXISTS (SELECT 1 FROM lims.samples WHERE project_code IS NULL AND project_id IS NULL) THEN
    INSERT INTO lims.projects(project_code, name, description, created_by)
    VALUES ('UNASSIGNED', 'Unassigned Project', 'Auto-generated for legacy rows', admin_id)
    ON CONFLICT (project_code) DO NOTHING;

    SELECT id INTO fallback_project_id FROM lims.projects WHERE project_code = 'UNASSIGNED';

    UPDATE lims.samples
    SET project_id = fallback_project_id,
        project_code = COALESCE(project_code, 'UNASSIGNED')
    WHERE project_id IS NULL;
  END IF;
END;
$$;

-- project_id is now mandatory
ALTER TABLE lims.samples
  ALTER COLUMN project_id SET NOT NULL;

ALTER TABLE lims.samples
  ADD CONSTRAINT samples_project_id_fk
  FOREIGN KEY (project_id)
  REFERENCES lims.projects(id);

-- Trigger to resolve project_id from project_code on INSERT/UPDATE
CREATE OR REPLACE FUNCTION lims.fn_samples_set_project()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, lims
AS $$
DECLARE
  proj_id uuid;
BEGIN
  IF NEW.project_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.project_code IS NULL THEN
    RAISE EXCEPTION 'project_id or project_code must be supplied';
  END IF;

  SELECT id INTO proj_id FROM lims.projects WHERE project_code = NEW.project_code;

  IF proj_id IS NULL THEN
    INSERT INTO lims.projects(project_code, name)
    VALUES (NEW.project_code, NEW.project_code)
    ON CONFLICT (project_code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO proj_id;
  END IF;

  NEW.project_id := proj_id;
  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION lims.fn_samples_set_project()
  TO app_admin, app_operator, app_automation, postgrest_authenticator, postgraphile_authenticator;

DROP TRIGGER IF EXISTS trg_samples_set_project ON lims.samples;
CREATE TRIGGER trg_samples_set_project
BEFORE INSERT OR UPDATE ON lims.samples
FOR EACH ROW
EXECUTE FUNCTION lims.fn_samples_set_project();

-- Assign default project memberships for seeded personas
DO $$
DECLARE
  admin_id uuid := (SELECT id FROM lims.users WHERE email = 'admin@example.org');
  operator_id uuid := (SELECT id FROM lims.users WHERE email = 'operator@example.org');
  alice_id uuid := (SELECT id FROM lims.users WHERE email = 'alice@example.org');
  bob_id uuid := (SELECT id FROM lims.users WHERE email = 'bob@example.org');
BEGIN
  INSERT INTO lims.project_members(project_id, user_id, member_role, added_by)
  SELECT p.id, admin_id, 'owner', admin_id
  FROM lims.projects p
  WHERE admin_id IS NOT NULL
  ON CONFLICT DO NOTHING;

  INSERT INTO lims.project_members(project_id, user_id, member_role, added_by)
  SELECT p.id, operator_id, 'operator', admin_id
  FROM lims.projects p
  WHERE operator_id IS NOT NULL
  ON CONFLICT DO NOTHING;

  IF alice_id IS NOT NULL THEN
    INSERT INTO lims.project_members(project_id, user_id, member_role, added_by)
    SELECT p.id, alice_id, 'researcher', admin_id
    FROM lims.projects p
    WHERE p.project_code IN ('PRJ-001', 'PRJ-002')
    ON CONFLICT DO NOTHING;
  END IF;

  IF bob_id IS NOT NULL THEN
    INSERT INTO lims.project_members(project_id, user_id, member_role, added_by)
    SELECT p.id, bob_id, 'researcher', admin_id
    FROM lims.projects p
    WHERE p.project_code = 'PRJ-003'
    ON CONFLICT DO NOTHING;
  END IF;
END;
$$;

-- Row level security for projects & memberships
ALTER TABLE lims.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.projects FORCE ROW LEVEL SECURITY;
ALTER TABLE lims.project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE lims.project_members FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_projects_admin_all ON lims.projects;
CREATE POLICY p_projects_admin_all
ON lims.projects
FOR ALL
TO app_admin
USING (TRUE)
WITH CHECK (TRUE);

DROP POLICY IF EXISTS p_projects_operator_manage ON lims.projects;
CREATE POLICY p_projects_operator_manage
ON lims.projects
FOR SELECT
TO app_operator
USING (TRUE);

DROP POLICY IF EXISTS p_projects_member_select ON lims.projects;
CREATE POLICY p_projects_member_select
ON lims.projects
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR EXISTS (
    SELECT 1
    FROM lims.project_members pm
    WHERE pm.project_id = id
      AND pm.user_id = lims.current_user_id()
  )
);

DROP POLICY IF EXISTS p_project_members_admin_all ON lims.project_members;
CREATE POLICY p_project_members_admin_all
ON lims.project_members
FOR ALL
TO app_admin
USING (TRUE)
WITH CHECK (TRUE);

DROP POLICY IF EXISTS p_project_members_operator_select ON lims.project_members;
CREATE POLICY p_project_members_operator_select
ON lims.project_members
FOR SELECT
TO app_operator
USING (TRUE);

DROP POLICY IF EXISTS p_project_members_member_select ON lims.project_members;
CREATE POLICY p_project_members_member_select
ON lims.project_members
FOR SELECT
TO app_auth
USING (
  lims.has_role('app_admin')
  OR lims.has_role('app_operator')
  OR user_id = lims.current_user_id()
);

-- Grants for new tables
GRANT SELECT ON lims.projects TO app_auth;
GRANT INSERT, UPDATE, DELETE ON lims.projects TO app_admin;
GRANT SELECT ON lims.project_members TO app_auth;
GRANT INSERT, UPDATE, DELETE ON lims.project_members TO app_admin;

-- Update sample policies to rely on project membership
DROP POLICY IF EXISTS p_samples_select_admin ON lims.samples;
CREATE POLICY p_samples_select_admin
ON lims.samples
FOR SELECT
TO app_admin
USING (TRUE);

DROP POLICY IF EXISTS p_samples_select_operator ON lims.samples;
CREATE POLICY p_samples_select_operator
ON lims.samples
FOR SELECT
TO app_operator
USING (TRUE);

DROP POLICY IF EXISTS p_samples_select_automation ON lims.samples;
CREATE POLICY p_samples_select_automation
ON lims.samples
FOR SELECT
TO app_automation
USING (TRUE);

DROP POLICY IF EXISTS p_samples_select_researcher ON lims.samples;
CREATE POLICY p_samples_select_researcher
ON lims.samples
FOR SELECT
TO app_researcher
USING (lims.can_access_project(project_id));

-- Reapply insert/update policies with project checks
DROP POLICY IF EXISTS p_samples_insert_ops ON lims.samples;
CREATE POLICY p_samples_insert_ops
ON lims.samples
FOR INSERT
TO app_operator
WITH CHECK (lims.can_access_project(project_id));

DROP POLICY IF EXISTS p_samples_update_ops ON lims.samples;
CREATE POLICY p_samples_update_ops
ON lims.samples
FOR UPDATE
TO app_operator
USING (lims.can_access_project(project_id))
WITH CHECK (lims.can_access_project(project_id));

DROP POLICY IF EXISTS p_samples_delete_ops ON lims.samples;
CREATE POLICY p_samples_delete_ops
ON lims.samples
FOR DELETE
TO app_operator
USING (lims.can_access_project(project_id));

DROP POLICY IF EXISTS p_samples_insert_admin ON lims.samples;
CREATE POLICY p_samples_insert_admin
ON lims.samples
FOR INSERT
TO app_admin
WITH CHECK (TRUE);

DROP POLICY IF EXISTS p_samples_update_admin ON lims.samples;
CREATE POLICY p_samples_update_admin
ON lims.samples
FOR UPDATE
TO app_admin
USING (TRUE)
WITH CHECK (TRUE);

DROP POLICY IF EXISTS p_samples_delete_admin ON lims.samples;
CREATE POLICY p_samples_delete_admin
ON lims.samples
FOR DELETE
TO app_admin
USING (TRUE);

DROP POLICY IF EXISTS p_samples_insert_automation ON lims.samples;
CREATE POLICY p_samples_insert_automation
ON lims.samples
FOR INSERT
TO app_automation
WITH CHECK (lims.can_access_project(project_id));

DROP POLICY IF EXISTS p_samples_update_automation ON lims.samples;
CREATE POLICY p_samples_update_automation
ON lims.samples
FOR UPDATE
TO app_automation
USING (lims.can_access_project(project_id))
WITH CHECK (lims.can_access_project(project_id));

-- migrate:down

DROP TRIGGER IF EXISTS trg_samples_set_project ON lims.samples;
DROP FUNCTION IF EXISTS lims.fn_samples_set_project();
DROP FUNCTION IF EXISTS lims.can_access_project(uuid);

ALTER TABLE lims.samples
  DROP CONSTRAINT IF EXISTS samples_project_id_fk;

ALTER TABLE lims.samples
  DROP COLUMN IF EXISTS project_id;

DROP TABLE IF EXISTS lims.project_members;
DROP TABLE IF EXISTS lims.projects;
