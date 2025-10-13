-- migrate:up
CREATE SCHEMA IF NOT EXISTS app_provenance AUTHORIZATION postgres;

GRANT USAGE ON SCHEMA app_provenance TO app_auth, dev, postgrest_authenticator, postgraphile_authenticator;
GRANT CREATE ON SCHEMA app_provenance TO dev;

-------------------------------------------------------------------------------
-- Reference data tables
-------------------------------------------------------------------------------

CREATE TABLE app_provenance.artefact_types (
  artefact_type_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type_key         text NOT NULL UNIQUE CHECK (type_key = lower(type_key)),
  display_name     text NOT NULL,
  kind             text NOT NULL CHECK (kind IN (
    'subject',
    'material',
    'reagent',
    'container',
    'data_product',
    'instrument_run',
    'workflow',
    'instrument',
    'virtual',
    'other'
  )),
  description      text,
  metadata         jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  is_active        boolean NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by       uuid REFERENCES app_core.users(id),
  updated_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_by       uuid REFERENCES app_core.users(id)
);

CREATE INDEX idx_artefact_types_kind ON app_provenance.artefact_types(kind);

CREATE TABLE app_provenance.artefact_traits (
  trait_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trait_key      text NOT NULL UNIQUE CHECK (trait_key = lower(trait_key)),
  display_name   text NOT NULL,
  description    text,
  data_type      text NOT NULL CHECK (data_type IN ('boolean','text','integer','numeric','json','enum')),
  allowed_values jsonb,
  default_value  jsonb,
  metadata       jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at     timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by     uuid REFERENCES app_core.users(id),
  updated_at     timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_by     uuid REFERENCES app_core.users(id),
  CHECK (allowed_values IS NULL OR jsonb_typeof(allowed_values) IN ('array','object')),
  CHECK (
    default_value IS NULL
    OR jsonb_typeof(default_value) IN ('object','array','string','number','boolean','null')
  )
);

CREATE INDEX idx_artefact_traits_type ON app_provenance.artefact_traits(data_type);

CREATE TABLE app_provenance.process_types (
  process_type_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type_key        text NOT NULL UNIQUE CHECK (type_key = lower(type_key)),
  display_name    text NOT NULL,
  description     text,
  metadata        jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by      uuid REFERENCES app_core.users(id),
  updated_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_by      uuid REFERENCES app_core.users(id)
);

-------------------------------------------------------------------------------
-- Process instances and artefacts
-------------------------------------------------------------------------------

CREATE TABLE app_provenance.process_instances (
  process_instance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  process_type_id     uuid NOT NULL REFERENCES app_provenance.process_types(process_type_id),
  process_identifier  text UNIQUE,
  name                text NOT NULL,
  description         text,
  status              text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('draft','scheduled','in_progress','completed','failed','cancelled')),
  started_at          timestamptz,
  completed_at        timestamptz,
  executed_by         uuid REFERENCES app_core.users(id),
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at          timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by          uuid REFERENCES app_core.users(id),
  updated_at          timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_by          uuid REFERENCES app_core.users(id),
  CHECK (name <> ''),
  CHECK (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at)
);

CREATE INDEX idx_process_instances_type ON app_provenance.process_instances(process_type_id);
CREATE INDEX idx_process_instances_status ON app_provenance.process_instances(status);

CREATE TABLE app_provenance.artefacts (
  artefact_id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  artefact_type_id          uuid NOT NULL REFERENCES app_provenance.artefact_types(artefact_type_id),
  name                      text NOT NULL,
  external_identifier       text UNIQUE,
  description               text,
  status                    text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','active','reserved','consumed','completed','archived','retired')),
  is_virtual                boolean NOT NULL DEFAULT false,
  quantity                  numeric,
  quantity_unit             text,
  quantity_estimated        boolean NOT NULL DEFAULT false,
  metadata                  jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  origin_process_instance_id uuid REFERENCES app_provenance.process_instances(process_instance_id) ON DELETE SET NULL,
  container_artefact_id     uuid REFERENCES app_provenance.artefacts(artefact_id) ON DELETE SET NULL,
  container_slot_id         uuid,
  created_at                timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by                uuid REFERENCES app_core.users(id),
  updated_at                timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_by                uuid REFERENCES app_core.users(id),
  CHECK (name <> ''),
  CHECK (quantity IS NULL OR quantity >= 0),
  CHECK (
    container_slot_id IS NULL
    OR container_artefact_id IS NOT NULL
  )
);

CREATE INDEX idx_artefacts_type ON app_provenance.artefacts(artefact_type_id);
CREATE INDEX idx_artefacts_status ON app_provenance.artefacts(status);

CREATE TABLE app_provenance.process_io (
  process_io_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  process_instance_id uuid NOT NULL REFERENCES app_provenance.process_instances(process_instance_id) ON DELETE CASCADE,
  artefact_id         uuid NOT NULL REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE,
  direction           text NOT NULL CHECK (direction IN ('input','output','pooled_input','pooled_output','reference')),
  io_role             text,
  quantity            numeric,
  quantity_unit       text,
  is_primary          boolean NOT NULL DEFAULT false,
  multiplex_group     text,
  evidence            jsonb,
  confidence          numeric,
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  CHECK (quantity IS NULL OR quantity >= 0),
  CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1::numeric))
);

CREATE INDEX idx_process_io_process ON app_provenance.process_io(process_instance_id);
CREATE INDEX idx_process_io_artefact ON app_provenance.process_io(artefact_id);
CREATE UNIQUE INDEX idx_process_io_unique ON app_provenance.process_io (
  process_instance_id,
  artefact_id,
  direction,
  COALESCE(io_role, ''),
  COALESCE(multiplex_group, '')
);

CREATE TABLE app_provenance.artefact_trait_values (
  artefact_trait_value_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  artefact_id             uuid NOT NULL REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE,
  trait_id                uuid NOT NULL REFERENCES app_provenance.artefact_traits(trait_id) ON DELETE CASCADE,
  value                   jsonb NOT NULL,
  effective_at            timestamptz NOT NULL DEFAULT clock_timestamp(),
  recorded_by             uuid REFERENCES app_core.users(id),
  metadata                jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  UNIQUE (artefact_id, trait_id, effective_at)
);

CREATE INDEX idx_trait_values_trait ON app_provenance.artefact_trait_values(trait_id);
CREATE INDEX idx_trait_values_effective ON app_provenance.artefact_trait_values(artefact_id, effective_at DESC);

CREATE TABLE app_provenance.artefact_relationships (
  relationship_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_artefact_id   uuid NOT NULL REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE,
  child_artefact_id    uuid NOT NULL REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE,
  relationship_type    text NOT NULL CHECK (relationship_type = lower(relationship_type)),
  process_instance_id  uuid REFERENCES app_provenance.process_instances(process_instance_id) ON DELETE SET NULL,
  metadata             jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at           timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by           uuid REFERENCES app_core.users(id),
  UNIQUE (parent_artefact_id, child_artefact_id, relationship_type),
  CHECK (parent_artefact_id <> child_artefact_id)
);

CREATE INDEX idx_relationships_parent ON app_provenance.artefact_relationships(parent_artefact_id);
CREATE INDEX idx_relationships_child ON app_provenance.artefact_relationships(child_artefact_id);

-------------------------------------------------------------------------------
-- Scope links
-------------------------------------------------------------------------------

CREATE TABLE app_provenance.artefact_scopes (
  artefact_id  uuid NOT NULL REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE,
  scope_id     uuid NOT NULL REFERENCES app_security.scopes(scope_id) ON DELETE CASCADE,
  relationship text NOT NULL DEFAULT 'primary' CHECK (relationship IN ('primary','supplementary','facility','dataset','derived_from')),
  assigned_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  assigned_by  uuid REFERENCES app_core.users(id),
  metadata     jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  PRIMARY KEY (artefact_id, scope_id, relationship)
);

CREATE INDEX idx_artefact_scopes_scope ON app_provenance.artefact_scopes(scope_id);

CREATE TABLE app_provenance.process_scopes (
  process_instance_id uuid NOT NULL REFERENCES app_provenance.process_instances(process_instance_id) ON DELETE CASCADE,
  scope_id            uuid NOT NULL REFERENCES app_security.scopes(scope_id) ON DELETE CASCADE,
  relationship        text NOT NULL DEFAULT 'primary' CHECK (relationship IN ('primary','facility','dataset','workflow','instrument')),
  assigned_at         timestamptz NOT NULL DEFAULT clock_timestamp(),
  assigned_by         uuid REFERENCES app_core.users(id),
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  PRIMARY KEY (process_instance_id, scope_id, relationship)
);

CREATE INDEX idx_process_scopes_scope ON app_provenance.process_scopes(scope_id);

-------------------------------------------------------------------------------
-- Containment
-------------------------------------------------------------------------------

CREATE TABLE app_provenance.container_slot_definitions (
  slot_definition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  artefact_type_id   uuid NOT NULL REFERENCES app_provenance.artefact_types(artefact_type_id) ON DELETE CASCADE,
  slot_name          text NOT NULL,
  display_name       text,
  position           jsonb,
  metadata           jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  UNIQUE (artefact_type_id, slot_name)
);

CREATE TABLE app_provenance.container_slots (
  container_slot_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  container_artefact_id uuid NOT NULL REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE,
  slot_definition_id  uuid REFERENCES app_provenance.container_slot_definitions(slot_definition_id) ON DELETE SET NULL,
  slot_name           text NOT NULL,
  display_name        text,
  position            jsonb,
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  UNIQUE (container_artefact_id, slot_name)
);

CREATE INDEX idx_container_slots_container ON app_provenance.container_slots(container_artefact_id);

ALTER TABLE app_provenance.container_slots
  ADD CONSTRAINT container_slots_container_unique UNIQUE (container_slot_id, container_artefact_id);

ALTER TABLE app_provenance.artefacts
  ADD CONSTRAINT artefacts_container_slot_fk
  FOREIGN KEY (container_slot_id, container_artefact_id)
  REFERENCES app_provenance.container_slots(container_slot_id, container_artefact_id)
  ON DELETE SET NULL;

CREATE UNIQUE INDEX idx_artefact_slot_unique
  ON app_provenance.artefacts(container_slot_id)
  WHERE container_slot_id IS NOT NULL
    AND status IN ('draft','active','reserved');

-------------------------------------------------------------------------------
-- Storage hierarchy and events
-------------------------------------------------------------------------------

CREATE TABLE app_provenance.storage_nodes (
  storage_node_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  node_key              text NOT NULL UNIQUE CHECK (node_key = lower(node_key)),
  node_type             text NOT NULL CHECK (node_type IN ('facility','unit','sublocation','virtual','external')),
  display_name          text NOT NULL,
  description           text,
  parent_storage_node_id uuid REFERENCES app_provenance.storage_nodes(storage_node_id) ON DELETE CASCADE,
  scope_id              uuid REFERENCES app_security.scopes(scope_id) ON DELETE SET NULL,
  barcode               text,
  environment           jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(environment) IN ('object','null')),
  metadata              jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  is_active             boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by            uuid REFERENCES app_core.users(id),
  updated_at            timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_by            uuid REFERENCES app_core.users(id),
  UNIQUE (parent_storage_node_id, display_name),
  CHECK (parent_storage_node_id IS NULL OR parent_storage_node_id <> storage_node_id)
);

CREATE INDEX idx_storage_nodes_parent ON app_provenance.storage_nodes(parent_storage_node_id);
CREATE INDEX idx_storage_nodes_scope ON app_provenance.storage_nodes(scope_id);

CREATE TABLE app_provenance.artefact_storage_events (
  storage_event_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  artefact_id           uuid NOT NULL REFERENCES app_provenance.artefacts(artefact_id) ON DELETE CASCADE,
  from_storage_node_id  uuid REFERENCES app_provenance.storage_nodes(storage_node_id) ON DELETE SET NULL,
  to_storage_node_id    uuid REFERENCES app_provenance.storage_nodes(storage_node_id) ON DELETE SET NULL,
  event_type            text NOT NULL CHECK (event_type IN ('register','move','check_in','check_out','disposed','location_correction')),
  occurred_at           timestamptz NOT NULL DEFAULT clock_timestamp(),
  actor_id              uuid REFERENCES app_core.users(id),
  process_instance_id   uuid REFERENCES app_provenance.process_instances(process_instance_id) ON DELETE SET NULL,
  reason                text,
  metadata              jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  CHECK (
    from_storage_node_id IS NOT NULL
    OR to_storage_node_id IS NOT NULL
    OR event_type = 'register'
  )
);

CREATE INDEX idx_storage_events_artefact ON app_provenance.artefact_storage_events(artefact_id, occurred_at DESC);
CREATE INDEX idx_storage_events_process ON app_provenance.artefact_storage_events(process_instance_id);

-- migrate:down
DROP TABLE IF EXISTS app_provenance.artefact_storage_events;
DROP TABLE IF EXISTS app_provenance.storage_nodes;
DROP TABLE IF EXISTS app_provenance.container_slots;
DROP TABLE IF EXISTS app_provenance.container_slot_definitions;
DROP TABLE IF EXISTS app_provenance.process_scopes;
DROP TABLE IF EXISTS app_provenance.artefact_scopes;
DROP TABLE IF EXISTS app_provenance.artefact_relationships;
DROP TABLE IF EXISTS app_provenance.artefact_trait_values;
DROP TABLE IF EXISTS app_provenance.process_io;
DROP TABLE IF EXISTS app_provenance.artefacts;
DROP TABLE IF EXISTS app_provenance.process_instances;
DROP TABLE IF EXISTS app_provenance.process_types;
DROP TABLE IF EXISTS app_provenance.artefact_traits;
DROP TABLE IF EXISTS app_provenance.artefact_types;

REVOKE USAGE ON SCHEMA app_provenance FROM app_auth, dev, postgrest_authenticator, postgraphile_authenticator;
REVOKE CREATE ON SCHEMA app_provenance FROM dev;

DROP SCHEMA IF EXISTS app_provenance;
