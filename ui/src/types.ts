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

export interface TransactionContextActivityRow {
  started_hour: string;
  client_app: string;
  finished_status: string;
  context_count: number;
  open_contexts: number;
}

export interface AuditRecentActivityRow {
  audit_id: number;
  performed_at: string;
  schema_name: string;
  table_name: string;
  operation: string;
  txn_id: string;
  actor_id: string | null;
  actor_identity: string | null;
  actor_roles: string[] | null;
}

export interface HandoverOverviewRow {
  research_artefact_id: string;
  research_artefact_name: string | null;
  research_scope_keys: string[] | null;
  ops_artefact_id: string;
  ops_artefact_name: string | null;
  ops_scope_keys: string[] | null;
  research_transfer_state: string | null;
  ops_transfer_state: string | null;
  propagation_whitelist: string[] | null;
  handover_at: string | null;
  returned_at: string | null;
  handover_by: string | null;
  returned_by: string | null;
}

export interface ScopeTransferOverviewRow {
  source_artefact_id: string;
  source_artefact_name: string | null;
  target_artefact_id: string;
  target_artefact_name: string | null;
  relationship_type: string;
  source_transfer_state: string | null;
  target_transfer_state: string | null;
  propagation_whitelist: string[] | null;
  allowed_roles: string[] | null;
  handover_at: string | null;
  returned_at: string | null;
  handover_by: string | null;
  returned_by: string | null;
}

export interface NotebookEntryOverview {
  entry_id: string;
  entry_key: string | null;
  title: string;
  description: string | null;
  status: "draft" | "submitted" | "locked";
  primary_scope_id: string;
  primary_scope_key: string | null;
  primary_scope_name: string | null;
  metadata: Record<string, unknown> | null;
  submitted_at: string | null;
  submitted_by: string | null;
  locked_at: string | null;
  locked_by: string | null;
  created_at: string;
  created_by: string | null;
  updated_at: string;
  updated_by: string | null;
  latest_version: number | null;
  latest_version_created_at: string | null;
  latest_version_created_by: string | null;
}

export type NotebookCell =
  | {
      cell_type: "markdown";
      metadata?: Record<string, unknown>;
      source: string[];
    }
  | {
      cell_type: "code";
      metadata?: Record<string, unknown>;
      source: string[];
      execution_count?: number | null;
      outputs?: NotebookOutput[];
    };

export interface NotebookOutput {
  output_type: string;
  text?: string[] | string;
  name?: string;
  ename?: string;
  evalue?: string;
  traceback?: string[];
}

export interface NotebookDocument {
  cells: NotebookCell[];
  metadata: Record<string, unknown>;
  nbformat: number;
  nbformat_minor: number;
}

export interface NotebookVersionRow {
  version_id: string;
  entry_id: string;
  version_number: number;
  notebook_json: NotebookDocument;
  checksum: string;
  note: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
  created_by: string | null;
}

export interface AccessibleScopeRow {
  scope_id: string;
  scope_key: string;
  scope_type: string;
  display_name: string;
  role_name: string;
  source_scope_id: string | null;
  source_role_name: string | null;
}
