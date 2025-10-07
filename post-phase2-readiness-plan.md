# Post-Phase 2 Readiness Plan – Bridge to Phases 3 & 4

## Objectives
- Convert Samples & Inventory outputs into reusable services that underpin ELN (Phase 3) and Service Requests & Workflow Orchestration (Phase 4).
- Deliver shared template, attachment, and authorization capabilities once, before parallel ELN/workflow workstreams start.
- De-risk downstream feature delivery by validating cross-domain data flows, automation hooks, and operational processes upfront.

## Interlocks & Dependencies
- Confirm Phase 2 schema is stable (no outstanding migrations) and contract snapshots are regenerated to include storage/lineage resources.
- Align with security backbone (Phases 0-1) to extend RLS helper predicates (`lims.can_access_*`) across new template, file, and workflow tables.
- Capture stakeholder input from ELN champions and workflow owners to prioritize shared services and UX requirements.
- Identify outstanding infrastructure tasks (object storage buckets, secrets management) that must be ready for large-file handling.

## Shared Platform Enhancements
### Template & Content Services
- Introduce `lims.template_definitions`, `lims.template_versions`, and `lims.template_instances` to model reusable forms for ELN entries and SOP tasks.
- Add JSON Schema storage for template validation and register pre/post-submit hooks for automation roles.
- Align template JSON Schema usage with community drafts (draft-07 or 2020-12) so we can leverage off-the-shelf validators and low-code form generators.
- Build polymorphic link tables (`lims.template_bindings`) that associate templates with samples, protocols, or service offerings.
- Provide migration-driven seed templates (baseline notebook entry, generic service request) for demo and regression testing.

### Protocol Management & Interoperability
- Stand up `lims.protocol_definitions` and `lims.protocol_versions` to capture internal and external protocols, storing provenance (DOI, provider URL) and licensing metadata for assets sourced from platforms like protocols.io.
- Normalize protocol content into structured JSON (steps, materials, instrumentation) enabling reuse inside templates and workflow step definitions while preserving original rich-text/attachment context.
- Evaluate importing protocols.io JSON exports or ISA-JSON/ISA-Tab metadata to seed step/material vocabularies and tagging.
- Implement protocol ingestion scripts or APIs that can pull public/open protocol metadata (author, revision history, tags) and map them onto local vocabularies for search and governance.
- Create linkage tables (`lims.protocol_bindings`) connecting protocol versions to ELN entries, workflow definitions, and CAPA records so updates propagate with proper version-locking.
- Document curation workflows for reviewing third-party protocols, including compliance checks and optional redaction before publishing to internal catalogs.

### File & Object Storage Handling
- Finalize object storage pointer pattern: `lims.file_assets` table with checksum, byte length, storage provider key, and retention policy metadata.
- Implement signed URL generation functions plus background checksum verification queue integration (ties into Phase 4 QC evidence uploads).
- Extend attachment junction tables for ELN entries and service deliverables (`eln_entry_files`, `workflow_artifact_files`) referencing `file_assets`.
- Define lifecycle states (pending upload, active, quarantined) and integrate with audit logging to capture who attached/approved files.

### Project-Scoped Access & RBAC
- Reuse and extend helper predicates from `ops/db/migrations/20240520010000_refine_storage_rls.sql` to cover templates, entries, requests, and artifacts.
- Add `lims.can_access_template(template_id)` and `lims.can_access_work_item(task_id)` functions leveraging project membership, role checks, and custodial relationships.
- Update role grants so `app_operator` manages workflow assets, `app_researcher` authors ELN content, and automation roles can append machine data without bypassing RLS.
- Document new policies in `docs/security-model.md` and ensure PostgREST/PostGraphile role mappings are refreshed.

### Research→Operations Continuity
- Keep early-stage ELN templates flexible but anchored to protocol step references so researcher notes convert cleanly into structured data for downstream reuse.
- Promote promising work by version-locking template/protocol pairs and using the shared approval state machine (draft → submitted → approved → locked) to tighten change control as tech-dev iterates.
- Transition mature processes into workflow definitions that reuse those templates and protocol versions while layering task sequencing, SLAs, and QC checkpoints for production readiness.
- Maintain consistent RLS, audit logging, and event hooks across ELN, tech-dev, and operations contexts so handoffs preserve context and traceability.
- Back transitions with training, sandbox environments, and data backfill scripts to reduce friction as ownership shifts between teams.

### Audit, Compliance & Notifications
- Extend immutable audit triggers to new tables; ensure audit payloads capture template version IDs and related sample/work item references.
- Design common approval state machine (draft → submitted → approved → locked) reusable by ELN entries and SOP steps, with optional e-signature checkpoints.
- Instrument event publishing (LISTEN/NOTIFY or webhook emission) for entry submissions and workflow status transitions to feed analytics and alerting.

## Data & Schema Preparation
### ELN Foundations
- Define `lims.eln_entries`, `lims.eln_entry_versions`, and `lims.eln_entry_samples` tables with project tenancy columns, authorship metadata, and references to template instances.
- Prepare optional witnessing tables (`eln_entry_signoffs`) with timestamped approvals and reason codes for CAPA linkage.
- Ensure sample linkage uses canonical IDs from Phase 2 lineage tables and respects chain-of-custody constraints.
- Support protocol references by storing protocol version IDs on entries and enabling inline citation of external sources (e.g., protocols.io DOIs) for reproducibility.

### Service Request & Workflow Foundations
- Model `lims.service_requests`, `lims.service_request_parameters`, and `lims.request_samples` to capture intake metadata, SLAs, and attachments.
- Establish workflow orchestration tables: `lims.workflow_definitions`, `lims.workflow_steps`, `lims.task_instances`, `lims.task_transitions`, and `lims.qc_outcomes`.
- Explore mapping workflow definitions to BPMN 2.0 or a Temporal/Argo-style JSON DSL so external engines or future automation tooling can interoperate.
- Connect workflow tasks to templates and file assets to drive Phase 4 UI/API development.
- Plan for CAPA tracking tables (`lims.capa_records`, `lims.capa_actions`) referencing tasks and audit events.
- Embed protocol version references inside workflow steps so operators execute the correct revision and receive alerts when upstream protocol updates occur.

### Shared Reference & Lookup Data
- Standardize enumerations (entry types, task statuses, QC outcomes, CAPA categories) under a shared vocabulary schema for admin configurability.
- Seed default lookups and create low-code-friendly views that surface enumerations with display metadata.

## API & Integration Preparation
- Expand PostgREST/PostGraphile configurations to include template, file asset, ELN, and workflow schemas; regenerate OpenAPI/GraphQL contracts post-migrations.
- Deliver RPC endpoints for templated entry creation, file upload initiation, workflow task progression, and CAPA closure that enforce business rules server-side.
- Implement webhook stubs and LISTEN/NOTIFY channels for ELN submissions, task assignments, and SLA breaches ahead of Phase 4 automation work.
- Provide sample JWT fixtures and curl/Postman collections demonstrating ELN entry creation and workflow task updates for stakeholder testing.

## UI/Low-Code Enablement
- Create API-backed views optimized for notebook authoring (entry drafts, available templates, linked samples) and service queues (task backlog, SLA countdown).
- Define schema metadata (labels, field types, validation hints) consumable by low-code tools to auto-generate forms for templates and task parameters.
- Align attachment workflow with UI upload patterns, including chunked uploads and completion callbacks tied to `file_assets` state transitions.

## Operational Alignment & Change Management
- Update SOPs and training materials to cover new template management, file handling, and workflow queue processes.
- Coordinate with IT/DevOps to provision object storage, background workers, and monitoring dashboards for file processing.
- Schedule stakeholder reviews (research, operations, quality) to validate readiness before Phases 3 and 4 sprint planning.
- Plan data migration scripts (if needed) to backfill existing notebook entries or service request records into new canonical tables.

## Testing & Quality Strategy
- Extend pgTAP or SQL test suites to cover template validation, file asset lifecycle, RLS enforcement, and workflow state transitions.
- Add integration tests simulating end-to-end flows: researcher creates ELN entry with attachments; operator receives service request and progresses tasks with QC outcomes.
- Incorporate non-functional testing (large file upload performance, concurrent task processing) to meet upcoming SLAs.
- Refresh contract-diff checks to ensure new endpoints remain backward compatible and include sample payloads for QA teams.

## Milestones & Exit Criteria
1. **Schema & Migration Delivery**: New shared tables and helper functions merged; migrations pass against a Phase 2 baseline database.
2. **Security Sign-off**: Updated RLS policies validated via automated tests and manual spot-checks for each persona.
3. **API Exposure**: Contracts regenerated with template, file, ELN, and workflow resources; example clients validated.
4. **Operational Readiness**: Object storage, background workers, and monitoring configured; SOPs and training materials drafted.
5. **Stakeholder Alignment**: ELN and workflow leads approve shared service designs; backlog refined for Phases 3 and 4 execution.

## Risks & Mitigations
- **Scope Creep**: Keep template engine MVP-focused; defer advanced conditional logic to later iterations while ensuring schema extensibility.
- **Performance**: Large file ingestion may strain database connections—use asynchronous workers and signed URLs to offload transfers.
- **Security Gaps**: Centralize permission checks in helper functions and include regression tests whenever new RLS rules are added.
- **Change Management**: Early training and sandbox environments reduce adoption friction; schedule iterative feedback sessions.
