# Security & Access Control Model – Phase 1 Redux

Phase 1 Redux rebuilds the security backbone around explicit transaction contexts and reusable auditing primitives. The goal: every write path—REST, GraphQL, CLI, automation—must establish the same session metadata before touching data, ensuring consistent RBAC and a tamper-evident audit trail.

## Personas and Database Roles

| Persona              | Database Role     | Description                                                        |
| -------------------- | ----------------- | ------------------------------------------------------------------ |
| Administrator        | `app_admin`       | Full control: manage users, roles, tokens, and security settings.  |
| Lab Operator         | `app_operator`    | Operational workflows (future domain tables) under admin oversight.|
| Researcher           | `app_researcher`  | Read-only views limited to their own records.                      |
| External Collaborator| `app_external`    | Restricted read-only personas (future scope).                      |
| Automation / Machine | `app_automation`  | Service accounts and instrument integrations.                      |

`app_auth` is the umbrella role inherited by all personas. `postgrest_authenticator` and `postgraphile_authenticator` can assume any persona role based on JWT claims. Local development continues to use the `dev` role, which inherits every persona for convenience.

## Core Tables

All security objects now live under two schemas:

- **`app_core.roles`** – persona catalog (`role_name`, `display_name`, flags for system/assignable).
- **`app_core.users`** – canonical user identities with metadata, lifecycle timestamps, and service-account flag.
- **`app_core.user_roles`** – grants linking users to roles, recording who granted access and when.
- **`app_security.transaction_contexts`** – one row per request/write transaction storing actor identifiers, effective/impersonated roles, JWT snapshot, client metadata, and disposition (`committed`, `rolled_back`, `cancelled`).
- **`app_security.audit_log`** – immutable audit entries (insert/update/delete) populated by triggers that reference the owning `txn_id`.
- **`app_security.api_clients`** – registry of automation clients with role allowlists and contact details.
- **`app_security.api_tokens`** – hashed API tokens linked to a user + optional API client, with expiration and revocation metadata.

## Session Bootstrap & JWT Mapping

JWTs supplied to PostgREST/PostGraphile should include:

- `sub` – stable external identifier mapped to `app_core.users.external_id`.
- `roles` (array) or `role` (string) – persona(s) to assume (e.g., `app_admin`).
- Optional `user_id` – UUID of the user to short-circuit the lookup.
- Recommended metadata such as `preferred_username` / `email` for audit labels.

### PostgREST Flow

Configure `PGRST_DB_PRE_REQUEST=app_security.pre_request`. The function:

1. Reads `request.jwt.claims` and normalises roles/identifiers.
2. Seeds session GUCs (`app.actor_id`, `app.actor_identity`, `app.roles`, `app.jwt_claims`, `app.client_app`).
3. For state-changing HTTP verbs (`POST`, `PUT`, `PATCH`, `DELETE`), calls `app_security.start_transaction_context()` once per request and records lightweight metadata (`http_method`, `request_path`).

Helper functions (`app_security.current_roles()`, `app_security.current_actor_id()`, `app_security.has_role(text)`) still fall back to parsing the JWT if these GUCs are missing, but the pre-request hook ensures PostgREST write requests always arrive with a fully initialised transaction context before DML executes.

### PostGraphile Flow

`ops/postgraphile/server.js` mirrors the same bootstrap by:

1. Validating JWTs (audience/issuer aware) via `jsonwebtoken`.
2. Supplying `request.jwt.claims`, `app.jwt_claims`, `app.roles`, `app.actor_id`, `app.actor_identity`, and `app.client_app='postgraphile'` through `pgSettings` before every request.
3. Using an owner connection (`postgres://postgres:postgres@db:5432/lims`) so watch fixtures (`postgraphile_watch` schema + triggers) are kept up to date for hot-reload while the authenticator continues to run with least privilege.
4. Allowing the first write in a session to lazily call `app_security.start_transaction_context()` via `app_security.require_transaction_context()`; the helper automatically backfills the context row if `app.txn_id` is absent.

## Transaction Context Lifecycle

1. **Start** – Entry points call (or trigger) `app_security.start_transaction_context(...)`, which inserts a row into `app_security.transaction_contexts` and sets local GUCs (`app.txn_id`, `app.actor_id`, `app.roles`, `app.impersonated_roles`, `app.jwt_claims`, `app.client_app`). PostgREST executes this eagerly for write verbs; PostGraphile defers to the first mutation, with `app_security.require_transaction_context()` auto-starting if necessary.
2. **Mutate** – Tables with write capabilities attach the `app_security.record_audit()` trigger. The trigger calls `app_security.require_transaction_context()` (raising if `app.txn_id` is missing), captures `row_before`/`row_after` snapshots, computes the primary-key diff, and inserts into `app_security.audit_log`.
3. **Finish** – A deferrable constraint trigger (`trg_mark_transaction_committed`) fires at commit, stamping `finished_status='committed'` and `finished_at`. Custom flows can still override the status via `app_security.finish_transaction_context(...)` before commit (e.g., cancellation paths).

Any attempt to insert/update/delete without an active context halts immediately with a descriptive error. If a caller bypasses the pre-request hook, `app_security.require_transaction_context()` backfills the context row by calling `app_security.start_transaction_context()` with the current session metadata.

## Row-Level Security Policies

- `app_core.roles` – world-readable; only `app_admin` can insert/update/delete.
- `app_core.users` – `app_admin` controls lifecycle; non-admin personas can only see their own row.
- `app_core.user_roles` – restricted to `app_admin` for both read/write.
- `app_security.api_clients` / `app_security.api_tokens` – visible and mutable only to `app_admin` (automation relies on stored procedures rather than direct table access).
- `app_security.audit_log` – `SELECT` granted to `app_admin` with RLS enforcing the same.

Policies depend on `app_security.has_role('role_name')`, which inspects `app.roles` from the session. If `pre_request`/`start_transaction_context` fail to set these GUCs, reads may degrade to minimal visibility, but writes will still be blocked by the audit trigger guard.

## Service Accounts & API Tokens

1. Create a service account by inserting into `app_core.users` with `is_service_account = true` and granting roles via `app_core.user_roles`.
2. Register (or reuse) an `app_security.api_clients` row that whitelists the roles a client may request.
3. From an admin context, call `app_security.create_api_token(user_id, plaintext_token, allowed_roles, expires_at, metadata, client_identifier)`.
   - Tokens must be ≥32 characters; the function stores the SHA-256 digest and a 6-character hint.
   - `allowed_roles` is normalised to lower-case without duplicates.
   - `created_by` is captured via `app_security.current_actor_id()`.
4. Revoke tokens via `revoked_at`/`revoked_by` or delete the row. Future instrumentation should exchange these tokens for JWTs that drive the same pre-request workflow as human callers.

## Development & Verification

- JWT fixtures live under `ops/examples/jwts`. Run `make jwt/dev` after adjusting claims or secrets; the script regenerates tokens and copies them into `ui/public/tokens`.
- `make db/test` executes SQL regression checks under `ops/db/tests/security.sql`, asserting that writes without contexts fail, audit rows materialise, `finish_transaction_context` updates status, and researcher RLS limits visibility.
- `make test/security` runs `scripts/test_rbac.sh`, which exercises the transaction helpers via the CLI (admin creates/modifies/deletes within a context; researchers attempt forbidden operations).

## Operational Checklist

1. Ensure PostgREST/PostGraphile are configured with `app_security.pre_request` and call `app_security.start_transaction_context()` for every write.
2. Rotate JWT secrets via `docker-compose.yml` overrides and regenerate local fixtures with `make jwt/dev`.
3. Onboard new personas by inserting into `app_core.roles` and crafting migrations that grant appropriate privileges.
4. Monitor `app_security.v_transaction_context_activity` (open contexts per hour/client) and `app_security.v_audit_recent_activity` for anomalies; investigate any contexts that remain pending.
