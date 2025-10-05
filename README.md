# CrazyLIMS Dev Environment

This repository hosts the database-first foundation for the CrazyLIMS project. The focus of Phase 0/1 is on PostgreSQL schema design, migration tooling, and access control expressed through PostgREST and PostGraphile.

## Prerequisites

- Docker + Docker Compose v2
- GNU Make
- (Optional) VS Code Devcontainer extension for the curated local environment

## First-Time Setup

```bash
# bring up the stack and apply migrations
make up

# wait until Postgres is healthy (also done automatically from targets)
make db-wait

# run migrations, SQL regression, API contract export, and RBAC smoke tests
make ci
```

The `dev` service defined in `docker-compose.yml` is used by the devcontainer; when working on the host, the main targets interact with Docker directly.

## Key Targets

| Target | Description |
| --- | --- |
| `make up` | Build and start Postgres, PostgREST, PostGraphile, and the dev helper container. |
| `make down` | Stop containers and remove volumes. |
| `make db/reset` | Drop/recreate the `lims` database and reapply migrations via dbmate. |
| `make db/test` | Run SQL-level regression checks (token hashing, RLS enforcement). |
| `make contracts/export` | Regenerate OpenAPI (PostgREST) and GraphQL schema snapshots. |
| `make test/security` | Execute REST and GraphQL RBAC smoke tests using fixture JWTs. |
| `make ci` | Orchestrates reset → db tests → contract export → RBAC smoke tests. |
| `make ui/dev` | Launch the read-only React console (served on http://localhost:5173). |

See `Makefile` for additional helper targets (logs, psql shell, etc.).

## Migration Workflow

- Generate new migrations with `make db/new name=...` (dbmate under the hood) instead of editing historical files.
- Keep migration bodies idempotent (`ON CONFLICT DO NOTHING`, `IF NOT EXISTS`) so `make db/reset` and CI replays remain safe.
- For follow-up adjustments, add a new migration that alters/drops/recreates objects; avoid mutating older files that may already be deployed.
- After creating a migration, run `make db/migrate` (or `make db/reset`) locally to ensure it applies cleanly before committing.

## Database Layout (Phase 1)

Schemas/tables created so far include:

- `lims.roles`, `lims.users`, `lims.user_roles`
- `lims.samples`, `lims.sample_derivations`, `lims.custody_events`, `lims.sample_labware_assignments`, `lims.audit_log`
- `lims.labware`, `lims.labware_positions`, `lims.labware_location_history`
- `lims.storage_facilities`, `lims.storage_units`, `lims.storage_sublocations`
- `lims.inventory_items`, `lims.inventory_transactions`
- `lims.api_clients`, `lims.api_tokens`

Helper functions such as `lims.current_roles()`, `lims.current_user_id()`, `lims.pre_request()`, and `lims.create_api_token()` power RLS and API token workflows.

See `docs/domain-samples.md` for a detailed explanation of the sample model, derivative workflows, and project-based visibility.

## JWT Fixtures & Usage

Development JWTs live under `ops/examples/jwts`:

- `admin.jwt`, `operator.jwt`, `researcher.jwt` map to seeded users.
- `make jwt/dev` regenerates tokens using the local secret (defined in `docker-compose.yml`).
- Use them with curl or GraphiQL, e.g.:
  ```bash
  AUTH="Authorization: Bearer $(cat ops/examples/jwts/admin.jwt)"
  curl -H "$AUTH" http://localhost:3000/users
  ```

Running `make jwt/dev` also copies the generated fixtures into `ui/public/tokens`, allowing the web console persona selector to serve them directly.

## Web Console (Phase 2 Prototype)

- Start via `make ui/dev` or `docker compose up ui`.
- Visit http://localhost:5173 and choose a persona; the console issues queries against PostgREST using the selected token.
- Current views display:
  - Sample overview (`/v_sample_overview`)
  - Labware contents (`/v_labware_contents`)
  - Inventory status (`/v_inventory_status`)
- As RBAC applies, switching personas immediately changes the dataset (e.g., researchers see only their permitted samples).
- Two researcher personas are available (`Researcher (Alice)` and `Researcher (Bob)`) to demonstrate sample-level row security—each can only see records they authored.
- Modify components under `ui/src` to iterate on additional visualizations or workflows.
- API calls are routed through the Vite dev-server proxy at `/api`, so the browser never needs to resolve the `postgrest` container hostname. Override the proxy target with `VITE_POSTGREST_SERVER_TARGET` (and optionally the public base with `VITE_POSTGREST_BROWSER_BASE`) when running PostgREST on a different address.

PostgREST automatically calls `lims.pre_request` to translate JWT claims into session settings consumed by RLS policies. PostGraphile requests go through the custom wrapper in `ops/postgraphile/server.js`, which validates JWTs via `jsonwebtoken` and forwards the same claim context.

## Service Accounts & API Tokens

Service accounts are represented by `lims.api_clients` rows with allowed roles. Tokens are hashed (`sha256`) and stored in `lims.api_tokens`. Use the `lims.create_api_token(api_client_id, plain_token, expires_at, metadata)` function to register a new token (the plaintext should be provided to the caller once and handled outside the database).

Recommended workflow:

1. Ensure the persona creating tokens signs in as an admin (`app_admin`).
2. Insert/update the API client metadata (`client_identifier`, allowed roles, contact email).
3. Call `lims.create_api_token` with a randomly generated secret (>=32 characters). The function stores the digest and a 6-character hint for debugging.
4. Return the plaintext token to the caller and discard it locally.
5. Use `lims.v_api_client_overview` for active token counts and last usage; revoke tokens by updating `revoked_at`/`revoked_by` or deleting the row.

Automation-authenticated workflows should pass tokens through PostgREST/PostGraphile where the token is exchanged for a JWT (future phase) or handled by a gateway component.

## Testing

- `make db/test` ensures critical database invariants (token digesting, researcher RLS visibility, and privilege boundaries).
- `make test/security` drives PostgREST and PostGraphile with the fixture JWTs to confirm behavior across REST/GraphQL.
- Both invocations are part of `make ci`; hook CI providers to run it on pull requests.

## Troubleshooting

- Ensure Docker resources are cleaned (`make down`) if migrations fail or containers restart repeatedly.
- When tests fail, re-run the specific target with `MAKECMDGOALS="..."` to focus on one layer (`db/test`, `test/security`, etc.).
- Config secrets: rotate `PGRST_JWT_SECRET` / `POSTGRAPHILE_JWT_SECRET` via `.env` or direct compose overrides and regenerate dev tokens.
