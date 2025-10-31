# CrazyLIMS Dev Environment

This repository hosts the database-first foundation for the CrazyLIMS project. The Phase 1 Redux reboot realigns the stack around a transaction-centric security backbone: every write must occur inside an attributed transaction context, with audit trails and RLS policies deriving actor metadata from shared session settings.

## Prerequisites

- GNU Make
- One of:
  - Docker + Docker Compose v2 (host or devcontainer)
  - Local toolchain: PostgreSQL 15+, Node.js 18+, npm, curl, jq, openssl, and tar with xz support. The helper script below will
    attempt to install PostgreSQL automatically via `apt-get` when running as root.
- (Optional) VS Code Devcontainer extension for the curated local environment

## First-Time Setup

```bash
# bring up the stack and apply migrations (Docker when available, otherwise the local helper)
make up

# wait until Postgres is healthy (also done automatically from targets)
make db-wait

# run migrations, SQL regression, API contract export, and RBAC smoke tests
make ci
```

The `dev` service defined in `docker-compose.yml` is used by the devcontainer; when Docker is unavailable the Makefile transparently drives the local helper described below.

### Running without Docker (Codex-friendly)

When Docker cannot be used (e.g. Codespaces-lite/Codex sandboxes), the `scripts/local_dev.sh` helper provisions a private PostgreSQL cluster under `.localdev/`, downloads PostgREST/PostGraphile binaries, and keeps process management out of band from Docker Compose.

```bash
# initialize the local toolchain (installs PostgreSQL via apt-get when missing)
./scripts/local_dev.sh start

# apply migrations / run checks via Make targets as usual
make db/migrate
make db/test      # automatically starts the helper and waits for PostgreSQL
make test/security

# stop services when finished (Postgres, PostgREST, PostGraphile)
./scripts/local_dev.sh stop
```

Additional helper commands (the Make targets above will start/stop services as needed, but these are handy for manual control):

- `./scripts/local_dev.sh status` – quick health snapshot
- `./scripts/local_dev.sh reset` – stop everything and remove `.localdev/pgdata`
- `./scripts/local_dev.sh logs` – tail the PostgreSQL/PostgREST/PostGraphile logs in one stream
- `./scripts/local_dev.sh psql` – open a `psql` shell as the seeded `dev` role

## Key Targets

| Target | Description |
| --- | --- |
| `make up` | Build and start Postgres, PostgREST, PostGraphile, and the dev helper container. |
| `make down` | Stop containers and remove volumes. |
| `make db/reset` | Drop/recreate the `lims` database and reapply migrations via dbmate. |
| `make db/test` | Run SQL regression checks (transaction contexts, audit hooks, RLS). |
| `make contracts/export` | Regenerate OpenAPI (PostgREST) and GraphQL schema snapshots. |
| `make test/security` | Execute CLI smoke tests that exercise the transaction helpers. |
| `make ci` | Orchestrates reset → db tests → contract export → RBAC smoke tests. |
| `make ui/dev` | Launch the read-only React console (served on http://localhost:5173). |

See `Makefile` for additional helper targets (logs, psql shell, etc.).

PostgREST listens on host port **6000** and PostGraphile on **6001** by default to avoid conflicts in Codespaces and other devcontainer hosts. Override the published ports by setting `POSTGREST_HOST_PORT` / `POSTGRAPHILE_HOST_PORT` before running Docker Compose or `make` (e.g. `POSTGREST_HOST_PORT=7000 make up`).

## Migration Workflow

- Generate new migrations with `make db/new name=...` (dbmate under the hood) instead of editing historical files.
- Keep migration bodies idempotent (`ON CONFLICT DO NOTHING`, `IF NOT EXISTS`) so `make db/reset` and CI replays remain safe.
- For follow-up adjustments, add a new migration that alters/drops/recreates objects; avoid mutating older files that may already be deployed.
- After creating a migration, run `make db/migrate` (or `make db/reset`) locally to ensure it applies cleanly before committing.

## Database Layout (Phase 1 Redux)

Schemas and tables established by the redo:

- `app_core.roles`, `app_core.users`, `app_core.user_roles`
- `app_security.transaction_contexts`, `app_security.audit_log`
- `app_security.api_clients`, `app_security.api_tokens`

Key helper functions:

- `app_security.pre_request()` – translates JWT claims into `app.actor_*` and `app.roles` session settings consumed by RLS.
- `app_security.start_transaction_context()` / `finish_transaction_context()` – wrap every state-changing operation in a server-side transaction context row and set the `app.txn_id` GUC.
- `app_security.record_audit()` – reusable trigger that writes inserts/updates/deletes into `app_security.audit_log`.
- `app_security.create_api_token()` – hashes API tokens bound to users and optional API clients.

All write-capable tables carry audit triggers that call `app_security.require_transaction_context()`; attempts to mutate data without an active context are rejected before touching rows. PostgREST automatically seeds the context for write methods, and PostGraphile does so lazily on the first mutation (the helper backfills the row if needed).

## Transaction Context Quickstart

- Follow `docs/transaction-context-examples.md` for a full walkthrough (POST via PostgREST → inspect context → inspect audit log).
- Import `docs/postman/transaction-context.postman_collection.json` into Postman to replay the flow with environment variables (`baseUrl`, `adminJwt`).
- Use the monitoring views for lightweight observability:
  - `app_security.v_transaction_context_activity` – hourly roll-up of contexts, grouped by client and status.
  - `app_security.v_audit_recent_activity` – last 200 audit events for quick spot checks.
- When you switch the dev UI persona to Administrator, a "Security Monitoring" section surfaces these views in the browser for quick inspection.
- When troubleshooting, query `app_security.transaction_contexts` directly to confirm `finished_status` (the deferrable commit trigger stamps `committed` automatically).

## JWT Fixtures & Usage

Development JWTs live under `ops/examples/jwts`:

- `admin.jwt`, `operator.jwt`, `researcher.jwt` map to the seeded personas.
- `make jwt/dev` regenerates tokens using the local secret (defined in `docker-compose.yml`) and copies them into `ui/public/tokens`.
- Example usage:
  ```bash
  AUTH="Authorization: Bearer $(cat ops/examples/jwts/admin.jwt)"
  curl -H "$AUTH" http://localhost:6000/users
  ```

The React UI still targets the legacy sample inventory endpoints and is parked until Phase 2 rebuilds those shapes on top of the new transaction/audit substrate.

PostgREST should call `app_security.pre_request()` (via `db-pre-request`) so that JWT claims populate the shared session metadata consumed by RLS. PostGraphile mirrors the same flow via `pgSettings` and now runs with an owner connection (`postgres://postgres:postgres@db:5432/lims`) so schema changes in `app_core` hot-reload automatically while the authenticator keeps least-privilege access (`POSTGRAPHILE_SCHEMAS=app_core`).

## Service Accounts & API Tokens

Service accounts are regular `app_core.users` rows flagged with `is_service_account = true`. Grant the desired roles via `app_core.user_roles`, then call `app_security.create_api_token(user_id, plain_token, allowed_roles, expires_at, metadata, client_identifier)` to mint a hashed token stored in `app_security.api_tokens` (the plaintext should be provided to the caller once and discarded).

Recommended workflow:

1. Ensure the persona creating tokens signs in as an admin (`app_admin`).
2. Insert/update the API client metadata (`client_identifier`, allowed roles, contact email).
3. Call `app_security.create_api_token` with a randomly generated secret (≥32 characters). The function stores the digest and a 6-character hint for debugging.
4. Return the plaintext token to the caller and discard it locally.
5. Query `app_security.api_tokens` (RLS exposes it to admins only) for active tokens; revoke tokens by updating `revoked_at`/`revoked_by` or deleting the row.

Automation-authenticated workflows should call stored procedures that invoke `app_security.start_transaction_context()` at the start of each request, mirroring how HTTP entry points behave.

## Testing

- `make db/test` ensures critical invariants (transaction contexts required for writes, audit log population, RLS scope for researchers). The SQL harness uses session-scoped assertion helpers so it runs on stock Postgres and emits `NOTICE: ok - ...` lines for each check.
- `make test/security` runs `scripts/test_rbac.sh`, which exercises the transaction helpers and researcher RLS using the CLI.
- Both invocations are part of `make ci`; hook CI providers to run it on pull requests.

## Troubleshooting

- Ensure Docker resources are cleaned (`make down`) if migrations fail or containers restart repeatedly.
- When tests fail, re-run the specific target with `MAKECMDGOALS="..."` to focus on one layer (`db/test`, `test/security`, etc.).
- Config secrets: rotate `PGRST_JWT_SECRET` / `POSTGRAPHILE_JWT_SECRET` via `.env` or direct compose overrides and regenerate dev tokens.
