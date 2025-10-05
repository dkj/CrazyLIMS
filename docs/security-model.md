# Security & Access Control Model

## Personas and Database Roles

| Persona              | Database Role     | Description                                                        |
| -------------------- | ----------------- | ------------------------------------------------------------------ |
| Administrator        | `app_admin`       | Full control: manage users, roles, and all domain data.            |
| Lab Operator         | `app_operator`    | Create and maintain operational records (samples, metadata).       |
| Researcher           | `app_researcher`  | Read-only access scoped to tenant data and authored content.       |
| External Collaborator| `app_external`    | Highly restricted read-only slices (future scope).                 |
| Automation / Machine | `app_automation`  | Service accounts writing instrument output under supervision.      |

All authenticated personas inherit from the umbrella `app_auth` role, which carries baseline privileges for generated APIs. Authenticator roles (`postgrest_authenticator`, `postgraphile_authenticator`) can assume any application role to honour JWT claims. Local development uses the `dev` role, which inherits every persona role to simplify experimentation.

## Core Tables

Phase 1 introduces the following security-centric tables under `lims`:

- `lims.roles` – catalog of assignable persona roles (seeded with the table above).
- `lims.users` – canonical user identities keyed by UUID with optional `external_id` for SSO mapping.
- `lims.user_roles` – membership bridge (many-to-many) capturing who granted which role and when.
- `lims.api_clients` – registered service accounts with allowed roles and metadata.
- `lims.api_tokens` – hashed API credentials linked to clients, with revocation metadata and usage tracking.

Downstream tables (currently `lims.samples`) reference `lims.users` via `created_by`, enabling RLS and audit hooks to attribute changes to actors.

## Session Bootstrap & JWT Mapping

JWTs are expected to carry at least:

- `sub` – stable external identifier (e.g., Okta subject); mapped to `lims.users.external_id`.
- `roles` – array of database role names to assume (e.g., `["app_operator"]`).
- Optional `user_id` – UUID matching `lims.users.id` to skip the lookup by `sub`.
- Recommended metadata claims (`preferred_username`, `email`) used for audit trails.

### PostgREST Flow

PostgREST executes `lims.pre_request` before each request. The function inspects the JWT (via `request.jwt.claims`) and calls `set_config` to expose:

- `lims.current_user_id`
- `lims.current_roles`
- Original JWT JSON (`request.jwt.claims`)

`lims.current_roles()` and `lims.current_user_id()` helper functions fall back to parsing the JWT directly, so explicit `set_config` calls act as a fast path and support impersonation scripts.

#### Role Resolution Sources

Sessions can inherit privileges from two places:

1. **JWT Claims** – Tokens may carry `role`/`roles` arrays. `lims.pre_request` trusts these claims and sets the database role immediately (used heavily by service integrations and API tokens).
2. **Database Assignments** – If claims omit role data, `lims.current_user_id()` resolves the actor, and `lims.has_role()` queries `lims.user_roles` to determine memberships. Humans typically rely on this path to ensure role changes take effect without token regeneration.

This dual approach allows long-lived automation tokens to bake in explicit roles while human accounts remain centrally managed inside the database.

### PostGraphile Flow

PostGraphile now runs through `ops/postgraphile/server.js`, which:

1. Verifies incoming JWTs with `jsonwebtoken` using the shared secret in `POSTGRAPHILE_JWT_SECRET` (and optional audience/issuer checks).
2. Injects `request.jwt.claims`, `lims.current_roles`, and the active `role` into `pgSettings` so that every resolver query sees the same context as PostgREST.

This keeps both API surfaces aligned and allows the database helper functions / RLS policies to behave identically regardless of entry point.

## Row-Level Security Overview

RLS is enforced on `lims.roles`, `lims.users`, `lims.user_roles`, and `lims.samples`:

- Administrators (`app_admin`) can fully manage users, roles, memberships, and samples.
- Operators (`app_operator`) can read all users, update operational metadata, and manage samples (insert/update/delete).
- Authenticated actors can always read their own user record and assigned roles via `lims.has_role()` checks in policies.
- Automation (`app_automation`) can insert/update samples – useful for ingestion daemons – but cannot delete.
- Read-only personas fall back to the default SELECT policy which trusts `lims.has_role('app_admin')` or sampling of claims.

Audit triggers (`lims.fn_audit`) capture actor identity, role context, and diffs for each mutation across the secured tables.

## Development Fixtures

Sample JWTs and helper scripts live under `ops/examples/jwts`:

- `make-dev-jwts.sh` regenerates tokens signed with the local dev secret.
- `admin.jwt`, `operator.jwt`, and `researcher.jwt` align with the seeded users (`admin@example.org`, `operator@example.org`, `alice@example.org`).
- Run `make jwt/dev` after tweaking claims or secrets to refresh all fixtures.

Use these files with PostgREST (`curl -H "Authorization: Bearer $(cat admin.jwt)" ...`) or GraphiQL to test RLS paths quickly.

## Service Accounts & Token Lifecycle

- Service accounts live in `lims.api_clients` with metadata such as `allowed_roles`, contact email, and auditing columns.
- Token digests are stored in `lims.api_tokens`; plaintext secrets are never persisted. A six-character `token_hint` (trailing characters of the plaintext) helps operators identify which credential a user is referencing.
- Administrators generate new credentials by calling `lims.create_api_token(api_client_id, plain_token, expires_at, metadata)` while logged in with sufficient privileges. The function enforces minimum length and records `created_by`.
- Tokens can be revoked by setting `revoked_at`/`revoked_by` or deleting the row. Active counts and last use timestamps are exposed through `lims.v_api_client_overview`.
- Downstream integration layers should exchange the token for a JWT (future phase) or validate against the stored digest before mapping to an allowed role.

## Verification

- `make test/security` spins up the API containers, regenerates the dev JWT fixtures, and runs smoke tests (`scripts/test_rbac.sh`) that exercise representative REST and GraphQL requests for administrator, operator, and researcher personas.
- The script confirms that privileged roles can read/write appropriately while lower-privilege personas are restricted to their own scope or denied mutations (including GraphQL mutations blocked for researchers and REST access limited to their own user record).
- `make db/test` runs SQL-level checks (`ops/db/tests/security.sql`) to validate token hashing, RLS behaviour, and researcher visibility rules directly inside the database.

## Operational Checklist

1. Ensure identity provider issues JWTs containing `roles` and `sub` values matching the records in `lims.users` / `lims.user_roles`.
2. Update `docker-compose.yml` secrets when rotating keys; re-run `make jwt/dev` for new fixtures.
3. Extend `lims.roles` and `lims.user_roles` via migrations when adding new personas.
4. Keep `make ci` in CI: it rebuilds the database, applies migrations, and exports OpenAPI / GraphQL contracts, surfacing schema drift.
