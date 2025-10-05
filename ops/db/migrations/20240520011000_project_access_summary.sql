-- migrate:up

CREATE OR REPLACE VIEW lims.v_project_access_overview
WITH (security_invoker = true)
AS
SELECT
  p.id,
  p.project_code,
  p.name,
  p.description,
  COALESCE(membership.is_member, false) AS is_member,
  CASE
    WHEN lims.has_role('app_admin') THEN 'admin'
    WHEN lims.has_role('app_operator') THEN 'operator'
    WHEN COALESCE(membership.is_member, false) THEN 'project_membership'
    ELSE 'role_policy'
  END AS access_via,
  COALESCE(sample_stats.sample_count, 0) AS sample_count,
  COALESCE(labware_stats.labware_count, 0) AS active_labware_count
FROM lims.projects p
LEFT JOIN LATERAL (
  SELECT true AS is_member
  FROM lims.project_members pm
  WHERE pm.project_id = p.id
    AND pm.user_id = lims.current_user_id()
  LIMIT 1
) membership ON true
LEFT JOIN LATERAL (
  SELECT COUNT(DISTINCT s.id) AS sample_count
  FROM lims.samples s
  WHERE s.project_id = p.id
) sample_stats ON true
LEFT JOIN LATERAL (
  SELECT COUNT(DISTINCT lw.id) AS labware_count
  FROM lims.labware lw
  WHERE EXISTS (
    SELECT 1
    FROM lims.samples s
    WHERE s.project_id = p.id
      AND (
        s.current_labware_id = lw.id
        OR EXISTS (
          SELECT 1
          FROM lims.sample_labware_assignments sla
          WHERE sla.sample_id = s.id
            AND sla.labware_id = lw.id
            AND sla.released_at IS NULL
        )
      )
  )
) labware_stats ON true;

GRANT SELECT ON lims.v_project_access_overview TO app_auth;

-- migrate:down

REVOKE ALL ON lims.v_project_access_overview FROM PUBLIC;
REVOKE ALL ON lims.v_project_access_overview FROM app_auth;
DROP VIEW IF EXISTS lims.v_project_access_overview;
