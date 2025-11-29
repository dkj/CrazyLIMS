# Transaction Context Examples

These samples demonstrate how to exercise the Phase 1 Redux security backbone end to end: create a write via PostgREST, inspect the transaction context, and review the corresponding audit log entries.

> **Prerequisites**
>
> - Run `make up` to start the stack.
> - Reset the database to apply the latest migrations: `make db/reset`.
> - Generate fresh JWT fixtures: `make jwt/dev`.

## 1. Create a User via PostgREST

```bash
export AUTH="Authorization: Bearer $(cat ops/examples/jwts/admin.jwt)"

curl -s -X POST \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  http://localhost:7100/app_core.users \
  -d '{"email":"demo-user@example.org","full_name":"Demo User","default_role":"app_researcher"}' \
  | jq .
```

The request succeeds only because the admin JWT triggers `app_security.pre_request`, which sets session metadata and establishes a transaction context before the insert.

## 2. Inspect the Transaction Context

Find the most recent context created by PostgREST:

```bash
docker compose exec -T db psql -U dev -d lims <<'SQL'
SELECT txn_id,
       actor_identity,
       actor_roles,
       client_app,
       finished_status,
       finished_at,
       metadata
FROM app_security.transaction_contexts
ORDER BY started_at DESC
LIMIT 3;
SQL
```

You should see a row with `client_app = 'postgrest'`, `finished_status = 'committed'`, and metadata capturing the HTTP method and path.

## 3. Review the Audit Log

Use the helper view to inspect the latest activity:

```bash
docker compose exec -T db psql -U dev -d lims <<'SQL'
SELECT audit_id,
       performed_at,
       operation,
       table_name,
       txn_id,
       actor_identity
FROM app_security.v_audit_recent_activity
ORDER BY performed_at DESC
LIMIT 5;
SQL
```

Alternatively, query the raw audit table to compare `row_before` and `row_after`:

```bash
docker compose exec -T db psql -U dev -d lims <<'SQL'
SELECT operation,
       row_after ->> 'email' AS email,
       txn_id,
       actor_identity
FROM app_security.audit_log
WHERE table_name = 'users'
ORDER BY performed_at DESC
LIMIT 5;
SQL
```

## 4. Monitor Context Activity

The view `app_security.v_transaction_context_activity` buckets transaction contexts by hour and status:

```bash
docker compose exec -T db psql -U dev -d lims <<'SQL'
SELECT started_hour,
       client_app,
       finished_status,
       context_count,
       open_contexts
FROM app_security.v_transaction_context_activity
ORDER BY started_hour DESC
LIMIT 6;
SQL
```

Use this view to spot long-running or abandoned contexts (non-zero `open_contexts`).

## 5. Sample Postman Collection

Import `docs/postman/transaction-context.postman_collection.json` into Postman to replay the same workflow using the admin JWT. The collection includes:

1. **POST Create User** – inserts a user through PostgREST.
2. **GET Recent Audit Entries** – fetches the latest audit rows for verification.

Update the collection variables (`baseUrl`, `adminJwt`) to match your environment before executing.
