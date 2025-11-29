# Documentation Map & Status

README.md is the canonical entry point for the project. This file is a companion map that points to authoritative references, current plans, and older materials kept for context.

## Canonical references (current)
- `README.md` – doc index and navigation.
- `docs/overview.md` – environment setup, tooling, Make targets, JWT fixtures, and quickstarts.
- `docs/security-model.md` – transaction contexts, RLS, personas, JWT mapping, audit hooks.
- `docs/database-schema.md` – Phase 2 Redux schema overview (artefacts, processes, scopes, ELN tables, storage RPC).
- `docs/domain-samples.md` – unified artefact/provenance guidance (wells-as-artefacts, storage-as-artefacts, lineage conventions).
- `docs/ui-handover-integration.md` – research⇄ops transfer helpers, RPCs, views for UI usage.
- `docs/ui-testing.md` – Playwright testing quickstart, dependency bootstrapping, and ELN E2E toggles.
- `contracts/postgrest/openapi.json` / `contracts/postgraphile/*` – exported API contracts for client generation.

## Active plans / near-term tracks
- `phase1-redux-detailed-plan.md` – security backbone (transaction contexts, audit, RLS).
- `phase2-redux-detailed-plan.md` – unified artefact + provenance platform, containment, storage.
- `security-access-control-plan-phase1-and-2-security-redux.md` – lineage-aware visibility, handover protocol, pooled runs; maps to current migrations.
- `jupyterlite-eln-plan.md` – ELN workbench scope, stories, and embedding approach.

## Legacy / historical (keep for context only)
- `phase0-phase1-detailed-plan.md`, `phase2-detailed-plan.md`, `post-phase2-readiness-plan.md`, `tech-option-d-postgresql-schema-driven.md` – superseded by the Redux docs above.
- `overarching-implementaion-plan.md` – earlier multi-phase outline; keep as historical roadmap.
- `minimal-eln-project-access.md` – initial ELN MVP sketch (pre-unified artefact/ELN schema).
- `eln-jupyterlite-embedding-attempts.md` – experiment log; useful background but not current design.

## How to keep this fresh
- Add new docs here when they become canonical; move older ones to “Legacy / historical”.
- When plans are superseded, mark the new canonical path in their intro paragraph and update this index.
- If schema/API changes land without matching doc updates, flag them in this file to avoid drift.
