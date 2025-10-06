export interface SampleOverviewRow {
  id: string;
  name: string;
  sample_type_code: string | null;
  sample_status: string | null;
  collected_at: string | null;
  project_id: string;
  project_code: string | null;
  project_name: string | null;
  current_labware_id: string | null;
  current_labware_barcode: string | null;
  current_labware_name: string | null;
  storage_path: string | null;
  derivatives: Array<Record<string, unknown>> | null;
}

export interface LabwareContentRow {
  labware_id: string;
  barcode: string | null;
  display_name: string | null;
  status: string | null;
  position_label: string | null;
  sample_id: string | null;
  sample_name: string | null;
  volume: number | null;
  volume_unit: string | null;
  current_storage_sublocation_id: string | null;
}

export interface InventoryStatusRow {
  id: string;
  name: string;
  barcode: string | null;
  quantity: number;
  unit: string;
  minimum_quantity: number | null;
  below_threshold: boolean;
  expires_at: string | null;
  storage_sublocation_id: string | null;
}

export interface UserRow {
  id: string;
  email: string;
  full_name: string;
  default_role: string | null;
  is_service_account: boolean;
}

export interface ProjectAccessRow {
  id: string;
  project_code: string;
  name: string;
  description: string | null;
  is_member: boolean;
  access_via: string;
  sample_count: number;
  active_labware_count: number;
}

export interface SampleLineageRow {
  parent_sample_id: string;
  parent_sample_name: string | null;
  parent_sample_type_code: string | null;
  parent_project_id: string | null;
  parent_labware_id: string | null;
  parent_labware_barcode: string | null;
  parent_labware_name: string | null;
  parent_storage_path: string | null;
  child_sample_id: string;
  child_sample_name: string | null;
  child_sample_type_code: string | null;
  child_project_id: string | null;
  child_labware_id: string | null;
  child_labware_barcode: string | null;
  child_labware_name: string | null;
  child_storage_path: string | null;
  method: string | null;
  created_at: string | null;
  created_by: string | null;
}

export interface SampleLabwareHistoryRow {
  sample_id: string;
  sample_name: string | null;
  labware_id: string;
  labware_barcode: string | null;
  labware_name: string | null;
  labware_position_id: string | null;
  position_label: string | null;
  assigned_at: string;
  released_at: string | null;
  current_storage_sublocation_id: string | null;
  current_storage_path: string | null;
}

export interface LabwareInventoryRow {
  labware_id: string;
  barcode: string | null;
  display_name: string | null;
  status: string | null;
  labware_type: string | null;
  current_storage_sublocation_id: string | null;
  storage_path: string | null;
  active_sample_count: number;
  active_samples: Array<{
    sample_id: string;
    sample_name: string | null;
    sample_status: string | null;
  }> | null;
}

export interface StorageTreeRow {
  facility_id: string;
  facility_name: string;
  unit_id: string;
  unit_name: string;
  storage_type: string | null;
  sublocation_id: string | null;
  sublocation_name: string | null;
  parent_sublocation_id: string | null;
  capacity: number | null;
  storage_path: string | null;
  labware_count: number;
  sample_count: number;
}
