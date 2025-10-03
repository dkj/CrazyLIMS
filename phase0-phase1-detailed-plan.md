# Detailed Implementation Plan – Phases 0 and 1

## Phase 0 – Environment & Governance

### Objectives
- Provide a reproducible developer environment with Postgres, PostgREST, PostGraphile, and seed data initialized from the SQL migrations.
- Establish the database migration workflow and CI checks that gate schema changes.
- Produce API contracts (OpenAPI and GraphQL SDL) on every build for downstream consumers.

### Devcontainer and Compose Setup
- Audit `.devcontainer/devcontainer.json` to ensure the container launches with required extensions, environment variables, and workspace mounts.
- Extend `docker-compose.yml` with services for `postgres`, `postgrest`, and `postgraphile`, defining healthchecks, shared volumes for migrations, and network aliases for inter-service communication.
- Configure PostgREST to read a `postgrest.conf` injected via bind mount or generated entrypoint script, pointing to the `postgres` service and referencing a dedicated PostgREST database role.
- Configure PostGraphile via CLI entrypoint (`npx postgraphile` or container image) using database URL environment variables, enabling schema watch mode in development.
- Validate the devcontainer lifecycle (`Dev Containers: Rebuild`) brings up the compose stack automatically by calling `docker-compose up` (or `make dev/up` if provided) in the `postCreateCommand`.
- Document developer routines in `README` or `TECH_SETUP.md`: start/stop commands, default credentials, and how to access PostgREST/PostGraphile endpoints from host.

### Migration Tooling and Seed Runners
- Choose migration orchestrator (e.g., `sqitch`, `dbmate`, or `psql` wrapper scripts) and codify in the `Makefile` (e.g., `make db/migrate`, `make db/reset`).
- Normalize existing SQL files in `ops/db/init` to follow a versioned naming convention; isolate role creation in `00_roles.sql`, schema creation in `01_db.sql`, and seed data in `02_schema_seed.sql`.
- Author bootstrap script that applies migrations inside the `postgres` container on startup (entrypoint script or `docker-compose` healthcheck sequence).
- Add idempotent seed routine for Dev/Test to populate reference data (units, vocabularies) while keeping Production seed optional via environment flag.
- Verify migrations run cleanly from both host (`psql` + make target) and inside devcontainer shell.

### API Contract Generation
- Configure PostgREST to emit OpenAPI by enabling the built-in `/` metadata endpoint and scripting `curl` + `jq` to export JSON into `contracts/openapi.json`.
- Configure PostGraphile to output schema SDL using `postgraphile --export-schema-json` and `--export-schema-graphql`, storing artifacts in `contracts/graphile/` with git-tracked snapshots.
- Add Make targets (`make contracts/export`) that call the above scripts, ensuring they run after migrations in CI and fail on drift via `git diff --exit-code`.

### Continuous Integration Hooks
- Create CI workflow (GitHub Actions or alternative) that spins a Postgres service, runs migrations, executes smoke queries (`SELECT 1`, check RLS existence), and exports contracts.
- Cache `node_modules` or container layers if PostGraphile/PostgREST dependencies are heavy, staying mindful of reproducibility.
- Surface artifacts from CI for developer download, and require successful workflow before merging schema changes.

### Validation & Exit Criteria
- `docker-compose up` from inside devcontainer starts all services without manual intervention; healthchecks pass.
- Running `make db/reset && make contracts/export` completes locally and in CI without errors.
- Generated contract files exist, are formatted, and load without errors in OpenAPI/GraphQL tooling.
- Developer documentation updated and reviewed by at least one team member.

## Phase 1 – Core Schema & Security Backbone

### Objectives
- Design and implement foundational RBAC, tenancy, and audit structures that enforce least privilege and traceability.
- Deliver initial database roles aligned to LIMS personas with supporting RLS policies for core tables.
- Provide base schema objects (projects, users, memberships) that downstream domains can reference safely.

### Domain and Security Modeling
- Conduct role matrix workshop with stakeholders to map permissions for researchers, operations staff, lab managers, automation actors, and external collaborators.
- Define tenancy boundaries (single organization with projects vs multi-tenant) and capture in a `tenants` or `projects` table with status, ownership, and SLA metadata fields.
- Model user identities with support for SSO/JWT subject mapping; include linkage tables for project memberships and role assignments.
- Introduce supporting tables for `api_clients` or service accounts needed by instrumentation integrations.

### SQL Implementation Tasks
- Update `ops/db/init/00_roles.sql` to create database roles (`app_admin`, `app_operator`, `app_researcher`, `app_external`, `app_automation`) plus dedicated authenticator roles (`postgrest_authenticator`, `postgraphile_authenticator`) and grant least-privilege access to schemas.
- In `ops/db/init/01_db.sql`, create schemas (`app_core`, `app_security`) and tables for users, projects, memberships, role templates, and audit logs (e.g., `app_security.audit_log` with JSONB payloads and timestamps).
- Implement RLS policies on sensitive tables (`app_core.projects`, `app_core.project_memberships`, `app_security.api_tokens`) to enforce tenant and role filters.
- Write reusable security helper functions (`current_tenant_id()`, `has_role(role_text)`) that rely on JWT claims or session variables.
- Add immutable audit triggers using `pgcrypto` UUIDs and `clock_timestamp()` to record inserts/updates/deletes across core tables, writing into a normalized audit log.

### JWT and Session Integration
- Define expected JWT claims (e.g., `sub`, `role`, `tenant_id`, `project_ids`) and document mapping to database settings via PostgREST `db-pre-request` function.
- Implement `set_config` hooks in a Postgres function executed by PostgREST/PostGraphile to translate JWT claims into `current_setting` values for use in RLS policies.
- Create sample JWT fixtures for development/testing and store them under `ops/examples/jwts/` for quick smoke testing with PostgREST.

### Seed and Validation Data
- Extend `ops/db/init/02_schema_seed.sql` (or create `ops/db/init/03_security_seed.sql`) to insert baseline roles, lab personas, demo tenants/projects, and admin accounts with hashed passwords or external IDs.
- Provide test data sets enabling Phase 2 to reference projects and users without manual setup.

### Testing & Verification
- Add SQL unit tests (e.g., using `pgTAP`) to assert RLS denies unauthorized access and allows authorized queries.
- Script smoke checks in the `Makefile` (e.g., `make db/test-security`) that run representative `SELECT` statements using `psql -v role=` switching among personas.
- Validate PostgREST/PostGraphile endpoints reflect the security model by issuing sample API calls with different JWTs and confirming response scopes.

### Documentation & Exit Criteria
- Create `docs/security-model.md` summarizing roles, RLS policies, JWT structure, and auditing approach.
- Ensure migrations apply cleanly over a blank database and on top of Phase 0 schema in CI.
- Review audit trail outputs to confirm insert/update/delete events capture actor, timestamp, target table, and row identifiers.
- Obtain sign-off from security lead or architect on RBAC matrix and policy correctness.
