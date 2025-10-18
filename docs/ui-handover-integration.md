# Handover & Return Integration Notes

This guide captures the database entry points the web UI can rely on when presenting research⇄ops handovers.

## Stored Procedures

| Procedure | Purpose | Typical Caller |
|-----------|---------|----------------|
| `app_provenance.sp_handover_to_ops(research_scope_id uuid, ops_scope_key text, artefact_ids uuid[], field_whitelist text[])` | Creates ops-scope duplicates linked to the supplied research artefacts. Stores a per-handover whitelist for downstream propagation and stamps `transfer_state` traits. | Research lab operators or API workflow controller. |
| `app_provenance.sp_return_from_ops(ops_artefact_id uuid, research_scope_ids uuid[])` | Marks an ops artefact as returned, adds back scope visibility, and completes the transfer-state lifecycle. | Ops lab techs / automation once deliverables are reconciled. |

Both procedures rely on the existing scope framework (`app_security.actor_has_scope`) for authorisation. The UI should call them via PostGraphile/PostgREST mutations exposed by the backend.

## Helper View for UI

`app_core.v_handover_overview` aggregates the data the UI typically needs:

| Column | Description |
|--------|-------------|
| `research_artefact_id`, `research_artefact_name` | Original artefact handed off. |
| `research_scope_keys` | Project/dataset scopes associated with the research artefact. |
| `ops_artefact_id`, `ops_artefact_name` | Duplicate living in the ops scope. |
| `ops_scope_keys` | Ops scopes the duplicate currently belongs to. |
| `research_transfer_state`, `ops_transfer_state` | Latest transfer-state trait on both artefacts. |
| `propagation_whitelist` | JSON → array of metadata keys the ops duplicate can receive from research corrections. |
| `handover_at`, `handover_by` | Timestamp and user UUID responsible for the handover. |
| `returned_at`, `returned_by` | Timestamp and user UUID that completed the return. |

Row-level security flows through the underlying tables: users only see handovers involving scopes they belong to.

### Typical Queries

- **List handovers visible to the current actor**
  ```sql
  SELECT research_artefact_name,
         ops_artefact_name,
         ops_transfer_state,
         handover_at,
         returned_at
  FROM app_core.v_handover_overview
  ORDER BY handover_at DESC NULLS LAST;
  ```
- **Fetch detail for a specific ops artefact**
  ```sql
  SELECT *
  FROM app_core.v_handover_overview
  WHERE ops_artefact_id = $1;
  ```

## Transfer-State Lifecycle

1. Research creates materials and invokes `sp_handover_to_ops`.  
2. Ops processes operate solely on the duplicate within their scopes.  
3. Research corrections propagate automatically for whitelisted fields.  
4. Ops calls `sp_return_from_ops` to indicate the deliverable is back with research.  

The UI can surface this lifecycle by mapping `research_transfer_state` and `ops_transfer_state` to status badges, combining timestamps from the view.

## Propagation Whitelist UX

When calling `sp_handover_to_ops`, the payload’s `field_whitelist` controls which metadata keys may flow from research to ops after corrections. The UI should:

- Display the whitelist (`propagation_whitelist`) for each handover.  
- Offer a controlled editor (e.g. multi-select) to append allowable keys before the handover is initiated.  
- Surface audit-friendly information pulled from the view’s `handover_at`/`returned_at` columns.

## API Usage Patterns

### PostGraphile (GraphQL)

Call stored procedures via mutations:

```graphql
mutation HandoverToOps($scopeId: UUID!, $opsKey: String!, $artefactIds: [UUID!]!, $whitelist: [String!]) {
  callAppProvenanceSpHandoverToOps(
    input: {
      pResearchScopeId: $scopeId
      pOpsScopeKey: $opsKey
      pArtefactIds: $artefactIds
      pFieldWhitelist: $whitelist
    }
  ) {
    clientMutationId
    result
  }
}
```

For returns:

```graphql
mutation ReturnFromOps($opsArtefact: UUID!, $researchScopes: [UUID!]!) {
  callAppProvenanceSpReturnFromOps(
    input: {
      pOpsArtefactId: $opsArtefact
      pResearchScopeIds: $researchScopes
    }
  ) {
    clientMutationId
  }
}
```

Fetch the summary view in the same GraphQL session:

```graphql
query VisibleHandovers {
  appCoreVhandoverOverview(orderBy: HANDOVER_AT_DESC) {
    nodes {
      researchArtefactName
      opsArtefactName
      handoverAt
      returnedAt
      opsTransferState
      propagationWhitelist
    }
  }
}
```

### PostgREST (REST)

Assuming PostgREST exposes RPC endpoints:

- Trigger handover:
  ```http
  POST /rpc/sp_handover_to_ops
  {
    "p_research_scope_id": "...",
    "p_ops_scope_key": "ops:normalisation:2024-07-15",
    "p_artefact_ids": ["..."],
    "p_field_whitelist": ["well_volume_ul","index_set"]
  }
  ```

- Mark return:
  ```http
  POST /rpc/sp_return_from_ops
  {
    "p_ops_artefact_id": "...",
    "p_research_scope_ids": ["..."]
  }
  ```

- Read the overview view with standard filters:
  ```http
  GET /app_core.v_handover_overview?ops_transfer_state=eq.transferred&order=handover_at.desc
  ```

Keep JWT claims aligned with the DB scope memberships so RLS grants the correct slice of the view.
