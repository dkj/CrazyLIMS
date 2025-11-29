# CrazyLIMS

Canonical entry point and documentation index for the CrazyLIMS database-first stack.

## Start here
- Project overview, environment setup, and Make targets: [docs/overview.md](docs/overview.md) (formerly the full README).
- Quick start: `make up` (bring up services) → `make ci` (migrations, db tests, contract export, RBAC + UI smoke tests).
- Need local services without Docker? See `scripts/local_dev.sh` notes in [docs/overview.md](docs/overview.md).

## Documentation map
- Core references: [docs/security-model.md](docs/security-model.md), [docs/database-schema.md](docs/database-schema.md), [docs/domain-samples.md](docs/domain-samples.md), [docs/ui-handover-integration.md](docs/ui-handover-integration.md).
- ELN: [jupyterlite-eln-plan.md](jupyterlite-eln-plan.md), [ui/public/eln/embed.html](ui/public/eln/embed.html), [eln-jupyterlite-embedding-attempts.md](eln-jupyterlite-embedding-attempts.md) (experiment log). The bundled JupyterLite now ships a Pyodide-ready PostgREST client (`crazylims_postgrest_client.pyodide.build_authenticated_client`) plus offline wheels under `/eln/lite/pypi`.
- Transaction contexts & examples: [docs/transaction-context-examples.md](docs/transaction-context-examples.md), [docs/postman/transaction-context.postman_collection.json](docs/postman/transaction-context.postman_collection.json).
- Security redux & lineage-aware access: [security-access-control-plan-phase1-and-2-security-redux.md](security-access-control-plan-phase1-and-2-security-redux.md).

## Plans & roadmap
- Security backbone: [phase1-redux-detailed-plan.md](phase1-redux-detailed-plan.md).
- Unified artefact/provenance platform: [phase2-redux-detailed-plan.md](phase2-redux-detailed-plan.md).
- Historical plans kept for context: [overarching-implementaion-plan.md](overarching-implementaion-plan.md), [phase0-phase1-detailed-plan.md](phase0-phase1-detailed-plan.md), [phase2-detailed-plan.md](phase2-detailed-plan.md), [post-phase2-readiness-plan.md](post-phase2-readiness-plan.md), [tech-option-d-postgresql-schema-driven.md](tech-option-d-postgresql-schema-driven.md), [minimal-eln-project-access.md](minimal-eln-project-access.md).

## API contracts
- PostgREST OpenAPI: [contracts/postgrest/openapi.json](contracts/postgrest/openapi.json).
- PostGraphile schema snapshots: [contracts/postgraphile/](contracts/postgraphile/).
- Use these for client generation (REST/GraphQL); keep them in sync with migrations via `make contracts/export`.

## Services & UI
- PostgREST: http://localhost:7100 (override with `POSTGREST_HOST_PORT`).
- PostGraphile: http://localhost:7101 (override with `POSTGRAPHILE_HOST_PORT`).
- Dev console (persona switcher, security views, ELN workbench): `make ui/dev` → http://localhost:5173.

## Assets & tokens
- Dev JWT fixtures: [ops/examples/jwts](ops/examples/jwts) (`make jwt/dev` regenerates and copies to `ui/public/tokens`).
- Vendored JupyterLite bundle (browser-only Pyodide runtime): `make jupyterlite/vendor` (outputs to `ui/public/eln/lite/`).

## Repo helpers
- Migration workflow and test targets are documented in [docs/overview.md](docs/overview.md).
- `Makefile` lists helper targets (logs, psql shell, db reset, UI tests).
