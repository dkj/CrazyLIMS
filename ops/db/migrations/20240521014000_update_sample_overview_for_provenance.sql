-- migrate:up

DROP VIEW IF EXISTS lims.v_sample_overview;

CREATE VIEW lims.v_sample_overview
WITH (security_invoker = true)
AS
SELECT
  s.id,
  s.name,
  s.sample_type_code,
  s.sample_status,
  s.collected_at,
  s.project_id,
  p.project_code,
  p.name AS project_name,
  s.current_labware_id,
  lab.barcode AS current_labware_barcode,
  lab.display_name AS current_labware_name,
  lims.storage_location_path(lab.current_storage_sublocation_id) AS storage_path,
  (
    SELECT jsonb_agg(
      jsonb_build_object(
        'child_sample_id', sd.child_sample_id,
        'method', sd.method
      )
    )
    FROM lims.sample_derivations sd
    WHERE sd.parent_sample_id = s.id
  ) AS derivatives
FROM lims.samples s
JOIN lims.projects p ON p.id = s.project_id
LEFT JOIN lims.labware lab ON lab.id = s.current_labware_id;

GRANT SELECT ON lims.v_sample_overview TO app_auth;

-- migrate:down

DROP VIEW IF EXISTS lims.v_sample_overview;

CREATE VIEW lims.v_sample_overview
WITH (security_invoker = true)
AS
SELECT
  s.id,
  s.name,
  s.sample_type_code,
  s.sample_status,
  s.collected_at,
  s.project_id,
  p.project_code,
  p.name AS project_name,
  lab.barcode AS current_labware_barcode,
  loc_path.path_text AS storage_path,
  (
    SELECT jsonb_agg(jsonb_build_object('child_sample_id', sd.child_sample_id, 'method', sd.method))
    FROM lims.sample_derivations sd
    WHERE sd.parent_sample_id = s.id
  ) AS derivatives
FROM lims.samples s
JOIN lims.projects p ON p.id = s.project_id
LEFT JOIN lims.labware lab ON lab.id = s.current_labware_id
LEFT JOIN LATERAL (
  SELECT string_agg(
           format('%s/%s/%s', COALESCE(sf.name, ''), COALESCE(su.name, ''), COALESCE(ss.name, '')),
           ' → '
         ) AS path_text
  FROM lims.storage_sublocations ss
  LEFT JOIN lims.storage_units su ON su.id = ss.unit_id
  LEFT JOIN lims.storage_facilities sf ON sf.id = su.facility_id
  WHERE ss.id = lab.current_storage_sublocation_id
) loc_path ON true;

GRANT SELECT ON lims.v_sample_overview TO app_auth;
