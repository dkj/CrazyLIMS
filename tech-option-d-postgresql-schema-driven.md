# Technology Option D: PostgreSQL-Centric, Schema-Driven (PostgREST/PostGraphile)

## Summary
**PostgreSQL as the system’s brain**. Database schema is the **single source of truth**; APIs are **auto-generated** (REST/GraphQL). Business rules live in declarative schema, views, policies, and stored procedures. **Minimal codebase**; rapid evolution.

## Stack
- **Core Data Platform:** PostgreSQL (managed: Aurora, Azure Hyperscale/Citus, Cloud SQL)
- **API Layer:**
  - **PostgREST** → REST auto-exposed from tables/views/functions (**OpenAPI** auto-docs)
  - **PostGraphile** → GraphQL auto-exposed from schema (smart comments/plugins)
- **Security:** Row-Level Security (RLS), roles, JWT auth mapping DB roles
- **Business Logic:** Constraints, triggers, stored procedures (PL/pgSQL); workflow modeled as data (workflow defs/steps/tasks)
- **Frontend:**
  - Low-code admin/UI (Retool/Appsmith/React-Admin) for CRUD & dashboards
  - Custom React for ELN (rich text/attachments) + **SOP wizard** (task/step UI)
  - Optional **JupyterHub** integration for notebook-style analysis bound to APIs
- **Files/Results:** Object storage; DB holds metadata + links; checksum/versioning
- **DevOps:** SQL-migrations as code; light containers for PostgREST/PostGraphile; horizontal API scaling; managed Postgres HA/backups
- **Contracts:** OpenAPI (REST) + GraphQL SDL; client SDKs generated from schemas; explicit versioning strategy via views/schemas

## Why This
- **Max capability / minimal code**: schema-driven APIs, docs, and clients.
- **Consistency & speed**: change schema → APIs/docs/UI bindings update.
- Leverages **Postgres features** (RLS, JSONB, FTS, LISTEN/NOTIFY) instead of custom services.

## Risks/Trade-offs
- **DB-centric discipline** required (careful schema/version governance).
- Very complex workflows may need some procedural SQL or a small sidecar service.
- Performance tuning shifts to SQL/indexing/query-planning expertise.

## Fit
- Teams prioritizing **elegance, maintainability, and speed**; desire **cloud scale-up** with managed Postgres; strong alignment with **API-first** and low-code ethos.
