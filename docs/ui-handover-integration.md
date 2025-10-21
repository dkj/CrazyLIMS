# Handover & Return Integration Notes

This guide captures the database entry points the web UI can rely on when presenting research⇄ops handovers.

## Stored Procedures

| Procedure | Purpose | Typical Caller |
|-----------|---------|----------------|
| `app_provenance.sp_transfer_between_scopes(...)` | Generalised handover utility that duplicates artefacts into another scope, records allowed roles, stores whitelists, and stamps transfer state. | Study owners delegating work, partner labs, automation controllers. |
| `app_provenance.sp_complete_transfer(...)` | Completes an in-flight transfer, adds derived scope visibility, and finalises `transfer_state` metadata. | Teams returning results to the origin scope or closing delegated work. |
| `app_provenance.sp_handover_to_ops(...)` | Compatibility wrapper around `sp_transfer_between_scopes` that targets legacy ops scopes and defaults ops personas. | Research lab operators or API workflow controller. |
| `app_provenance.sp_return_from_ops(...)` | Wrapper around `sp_complete_transfer` preserving the historic ops-return flow. | Ops lab techs / automation once deliverables are reconciled. |

All procedures rely on the scope framework (`app_security.actor_has_scope`) for authorisation. Prefer calling the generalised helpers via PostGraphile/PostgREST; the wrappers remain for legacy integrations.

## Helper View for UI

`app_core.v_scope_transfer_overview` aggregates every scope-to-scope handover (research⇄ops, research⇄research, facility⇄facility, etc.) and exposes rich metadata for UI consumers:

| Column | Description |
|--------|-------------|
| `source_artefact_id`, `source_artefact_name` | Artefact handed off from the originating scope. |
| `source_scopes` | JSON array describing each scope attached to the source artefact (id, key, type, relationship). |
| `target_artefact_id`, `target_artefact_name` | Duplicate that lives inside the target scope. |
| `target_scopes` | JSON array of the duplicate's scope memberships. |
| `source_transfer_state`, `target_transfer_state` | Latest transfer-state trait values on each artefact. |
| `propagation_whitelist` | Whitelisted metadata keys that propagate from source to target after corrections. |
| `allowed_roles` | Roles permitted to mutate the duplicate via `app_provenance.can_update_handover_metadata`. |
| `relationship_type`, `relationship_metadata` | Underlying relationship type plus raw metadata (notes, additional audit breadcrumbs). |
| `handover_at`, `handover_by`, `returned_at`, `returned_by` | Lifecycle audit fields. |

For compatibility the narrower `app_core.v_handover_overview` now selects a filtered subset of `v_scope_transfer_overview` where the target scope type is `ops`, exposing the familiar research/ops columns listed below.

Row-level security flows through the underlying tables: users only see transfers involving scopes they belong to, regardless of which view they query.

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

1. Research (or the originating team) calls `sp_transfer_between_scopes` to hand artefacts to another scope (the `sp_handover_to_ops` wrapper still works for ops-focused flows).  
2. The target team operates solely on the duplicate within its scopes.  
3. Research corrections propagate automatically for whitelisted fields.  
4. The target team calls `sp_complete_transfer` (or `sp_return_from_ops`) to signal the deliverable has been returned.  

The UI can surface this lifecycle by mapping `research_transfer_state` and `ops_transfer_state` to status badges, combining timestamps from the view.

## Propagation Whitelist UX

When calling `sp_transfer_between_scopes` (or the `sp_handover_to_ops` wrapper), the payload’s `field_whitelist` controls which metadata keys may flow from the source scope after corrections. The UI should:

- Display the whitelist (`propagation_whitelist`) for each handover.  
- Offer a controlled editor (e.g. multi-select) to append allowable keys before the handover is initiated.  
- Surface audit-friendly information pulled from the view’s `handover_at`/`returned_at` columns.

## Provenance Graph UX Ideas

Leverage the view and trait data when rendering provenance graphs:

- **Node styling:** colour/badge nodes using `research_transfer_state` and `ops_transfer_state` (e.g. highlight `transferred` artefacts awaiting return).  
- **Edge labels:** label `handover_duplicate` edges with the ops scope key and the `propagation_whitelist` members so users see exactly what metadata flows.  
- **Scope tooltips:** display `research_scope_keys` / `ops_scope_keys` in hover/side panels to explain why a node is visible.  
- **Timeline filters:** use `handover_at` / `returned_at` to filter the graph (e.g. “show handovers from the last 7 days” or “pending returns”).  
- **Access hints:** if the UI detects truncated traversals (no more descendants but the user expects outputs), surface an informative banner reminding them that RLS hides artefacts outside their scopes.

All of these rely on `app_core.v_scope_transfer_overview` (or the narrower `app_core.v_handover_overview`) alongside the existing provenance graph data—no extra queries are required beyond joining the view to the graph datasource.

## API Usage Patterns

### PostGraphile (GraphQL)

Call stored procedures via mutations. Prefer the general helpers when introducing new flows:

```graphql
mutation TransferBetweenScopes($sourceScopeId: UUID!, $targetKey: String!, $targetType: String!, $artefactIds: [UUID!]!, $allowedRoles: [String!]) {
  callAppProvenanceSpTransferBetweenScopes(
    input: {
      pSourceScopeId: $sourceScopeId
      pTargetScopeKey: $targetKey
      pTargetScopeType: $targetType
      pArtefactIds: $artefactIds
      pAllowedRoles: $allowedRoles
      pFieldWhitelist: ["well_volume_ul"]
    }
  ) {
    clientMutationId
    result
  }
}
```

To mark a transfer complete:

```graphql
mutation CompleteTransfer($targetArtefact: UUID!, $returnScopes: [UUID!]) {
  callAppProvenanceSpCompleteTransfer(
    input: {
      pTargetArtefactId: $targetArtefact
      pReturnScopeIds: $returnScopes
    }
  ) {
    clientMutationId
  }
}
```

Wrappers remain available for legacy ops flows:

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

- Trigger a general handover:
  ```http
  POST /rpc/sp_transfer_between_scopes
  {
    "p_source_scope_id": "...",
    "p_target_scope_key": "project:pilot-collab",
    "p_target_scope_type": "project",
    "p_artefact_ids": ["..."],
    "p_field_whitelist": ["well_volume_ul"],
    "p_allowed_roles": ["app_researcher"]
  }
  ```

- Mark the transfer complete:
  ```http
  POST /rpc/sp_complete_transfer
  {
    "p_target_artefact_id": "...",
    "p_return_scope_ids": ["..."]
  }
  ```

Wrappers remain for legacy ops flows (`sp_handover_to_ops`, `sp_return_from_ops`).

- Read the general overview with standard filters:
  ```http
  GET /v_scope_transfer_overview?relationship_type=eq.handover_duplicate&order=handover_at.desc
  ```

- Existing UI components can continue to query the narrower view:
  ```http
  GET /v_handover_overview?ops_transfer_state=eq.transferred&order=handover_at.desc
  ```

Keep JWT claims aligned with the DB scope memberships so RLS grants the correct slice of the view.

## Rendering the Annotated Graph in the Web UI

A typical React/TypeScript stack can render the annotated provenance graph by combining the existing graph API with `v_handover_overview` data:

1. **Fetch graph topology** (whatever endpoint already drives the provenance view).  
2. **Fetch handover annotations** from the view, keyed by `research_artefact_id` / `ops_artefact_id`.  
3. **Merge** the annotations into the graph nodes/edges before rendering.

Pseudo-code outline:

```ts
const { graph } = await api.fetchProvenanceGraph(rootArtefactId);
const { nodes: handovers } = await gqlVisibleHandovers();
const byOpsId = new Map(handovers.map(h => [h.opsArtefactId, h]));
const byResearchId = new Map(handovers.map(h => [h.researchArtefactId, h]));

const enrichedNodes = graph.nodes.map(node => {
  const annotation = byOpsId.get(node.id) ?? byResearchId.get(node.id);
  return {
    ...node,
    transferState: annotation?.opsTransferState ?? annotation?.researchTransferState,
    scopeKeys: annotation?.opsScopeKeys ?? annotation?.researchScopeKeys,
    propagationWhitelist: annotation?.propagationWhitelist ?? [],
    handoverAt: annotation?.handoverAt,
    returnedAt: annotation?.returnedAt,
  };
});
```

For rendering:

- Use a graph library (e.g. Cytoscape, D3, Vis.js) to colour nodes by `transferState`.  
- Overlay tooltips showing scope keys and last handover/return timestamps.  
- For edges where `relationship_type === 'handover_duplicate'`, display a badge containing the ops scope and whitelist summary.

Because RLS already trims the datasets per user, the UI can safely render the merged graph without extra filtering logic.
