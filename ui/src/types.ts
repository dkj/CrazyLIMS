export interface SampleOverviewRow {
  id: string;
  name: string;
  sample_type_code: string | null;
  sample_status: string | null;
  collected_at: string | null;
  project_id: string;
  project_code: string | null;
  project_name: string | null;
  current_labware_barcode: string | null;
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
