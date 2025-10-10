# Detailed Implementation Plan – Phase 1 Redux: Transaction-Centric Security Backbone

## Objectives
- Bootstrap a fresh PostgreSQL baseline that carries forward only the hardened security primitives, leaving legacy domain tables behind.
- Bind every state-changing request to a single Postgres transaction with explicit actor, persona, and client metadata.
- Deliver normalized audit artifacts that capture inserts, updates, and deletes with transaction references for full reconstruction.
- Harden RBAC and RLS policies so downstream services can extend security guarantees without duplicating logic.
- Provide tooling and documentation that keep PostgREST/PostGraphile integrations aligned with the transaction context model.

## Guiding Principles
- **Actor-attribution first**: no write occurs without a recorded end-user, delegated service, and effective DB role.
- **Single-source audit**: base tables stay lean; audit tables own historical truth with immutable rows keyed by transaction context.
- **Least-privilege defaults**: application roles receive the minimum grants needed to execute prepared workflows.
- **Automation-friendly**: instrument and service accounts follow the same transaction discipline, avoiding back doors.

## Workstreams

### 0. Fresh Baseline Setup
- Provision a clean schema (or database) that retains authentication, RBAC, and security helper primitives while omitting legacy LIMS tables.
- Re-run existing migrations to install security packages; archive the prior schema for reference without keeping it on active connections.
- Port regression harnesses (`scripts/test_rbac.sh`, pgTAP suites) to target the reset baseline and verify the expected fixtures still compile.

### 1. Transaction Context Lifecycle
- Design a `app_security.transaction_contexts` table storing `txn_id`, end-user identifiers, impersonated roles, JWT claims, client app, and timestamps.
- Implement a helper function (`start_transaction_context()`) that generates `txn_id`, inserts the context row, and `set_config`s GUCs (`app.txn_id`, `app.actor_id`, `app.roles`).
- Update connection entrypoints for PostgREST/PostGraphile to call the helper at request start and clean up on commit/rollback.
- Document expectations that all write-capable stored procedures begin by asserting `current_setting('app.txn_id', false)` to guard against context drift.

### 2. Audit Schema & Trigger Framework
- Create `app_security.audit_log` with columns for `txn_id`, `schema_name`, `table_name`, `operation`, `primary_key`, `row_before`, `row_after`, and `performed_at`.
- Build reusable trigger functions that read the transaction GUCs, serialize row diffs, and insert audit entries before each DML change.
- Extend delete handling with soft tombstone rows referencing `txn_id` so downstream reporting can join audit data without orphaned pointers.
- Apply the trigger framework to the rebuilt Phase 1 tables (users, roles, memberships, tokens) and document how new Phase 2 tables must opt in.

### 3. RBAC & RLS Hardening
- Align database roles with persona matrix, adding specialized roles for PostgREST authenticator, background jobs, and automation endpoints.
- Refresh grants so only the owner role can execute transaction helper functions; shared roles receive EXECUTE but not ownership privileges.
- Refine RLS policies to source actor metadata from `current_setting`, enabling policy predicates like `has_role('project_admin')`.
- Add guard rails preventing cross-tenant writes by asserting JWT/project membership inside RLS functions that now have access to `txn_id`.

### 4. Application Integration & Developer Tooling
- Update PostgREST configuration (`db-pre-request`, `db-anon-role`) to start/stop transaction contexts per HTTP request and propagate JWT claims.
- Provide sample `curl` scripts and Postman collections demonstrating how to include actor metadata in JWTs and observe audit trail outputs.
- Modify CLI/automation scripts to call stored procedures that wrap `start_transaction_context()` to maintain parity with interactive flows.
- Ensure migration tooling (`make db/migrate`, `dbmate`) seeds demo contexts and JWT fixtures for local testing.

### 5. Validation, Monitoring & Ops Readiness
- Extend `scripts/test_rbac.sh` (or new harness) to impersonate multiple roles, execute writes, and validate that audit rows tie back to contexts.
- Add pgTAP or custom SQL assertions confirming triggers populate `txn_id`, actor, and diff fields when mutations occur.
- Instrument PostgreSQL with views or metrics exporting counts of transactions by role, audit log growth, and missing context anomalies.
- Draft operational runbooks for forensic queries: tracing a `txn_id`, reconstructing record history, and verifying deletion events.

## Milestones & Deliverables
- **M1 – Transaction Context Prototype (Week 1)**: helper functions, context table, and PostgREST integration running in development.
- **M2 – Audit Trigger Rollout (Week 2)**: audit schema deployed, triggers covering core tables, sample reconstructions documented.
- **M3 – RBAC/RLS Verification (Week 3)**: updated policies passing automated tests; regression suite expanded with context assertions.
- **M4 – Tooling & Docs (Week 4)**: developer how-to guides, sample JWTs, and ops runbooks reviewed with security leadership.

## Dependencies & Coordination
- Coordinate with authentication/SSO owners to ensure JWT claims expose required actor and role metadata.
- Align with DevOps on logging/monitoring destinations for audit and context metrics.
- Engage compliance stakeholders early to validate audit retention, storage encryption, and access review processes.

## Risks & Mitigations
- **Stray legacy dependencies**: catalog scripts or services that still reference removed tables and replace them with transaction-aware equivalents before cutover.
- **Trigger performance overhead**: benchmark heavy tables; consider asynchronous logging via logical decoding if latency spikes.
- **Role sprawl**: establish governance for new roles and map them to persona documentation before granting DB access.
- **Audit data volume**: set retention policies and archiving strategies; consider partitioning audit tables by month.

## Exit Criteria
- Every write path (API, CLI, automation) establishes a transaction context and produces audit rows with traceable `txn_id`.
- RBAC and RLS policies rely on consistent session metadata, and automated security tests confirm enforcement.
- Operations and compliance teams can answer “who changed what and when” using documented queries without manual data stitching.
- Phase 2 teams can extend audit hooks and transaction contexts to new domain tables without altering the core framework.
