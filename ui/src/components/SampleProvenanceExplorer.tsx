import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type {
  LabwareInventoryRow,
  SampleLineageRow,
  SampleOverviewRow,
  HandoverOverviewRow
} from "../types";
import { ProvenanceGraph, ProvenanceGraphLink, ProvenanceGraphNode } from "./ProvenanceGraph";

interface SampleProvenanceExplorerProps {
  samples: SampleOverviewRow[];
  lineage: SampleLineageRow[];
  labwareInventory: LabwareInventoryRow[];
  handovers?: HandoverOverviewRow[];
  loading: boolean;
  error: string | null;
  onSelectLabware?: (labwareId: string | null) => void;
  selectedLabwareId?: string | null;
  focusedSampleId?: string | null;
  onSampleFocusChange?: (sampleId: string) => void;
}

interface HandoverDetail {
  role: "research" | "ops";
  transferState: string | null;
  scopeKeys: string[] | null;
  handoverAt: string | null;
  returnedAt: string | null;
  propagationWhitelist: string[] | null;
  counterpartName: string | null;
  counterpartId: string;
}

interface LineageNode {
  sampleId: string;
  name: string;
  method: string | null;
  depth: number;
  labwareId: string | null;
  labwareLabel: string;
  storagePath: string | null;
  relation: "ancestor" | "descendant";
  handoverDetails: HandoverDetail[];
}

const formatDateTime = (value: string | null) => {
  if (!value) return "—";
  try {
    return new Date(value).toLocaleString();
  } catch (error) {
    console.warn("Failed to format date", error);
    return value;
  }
};

const buildLabwareLabel = (
  barcode: string | null,
  name: string | null
): string => {
  if (barcode && name) return `${barcode} – ${name}`;
  if (barcode) return barcode;
  if (name) return name;
  return "Not assigned";
};

const formatList = (values?: string[] | null): string => {
  if (!values || values.length === 0) {
    return "—";
  }
  return values.join(", ");
};

export function SampleProvenanceExplorer({
  samples,
  lineage,
  labwareInventory,
  handovers = [],
  loading,
  error,
  onSelectLabware,
  selectedLabwareId,
  focusedSampleId,
  onSampleFocusChange
}: SampleProvenanceExplorerProps) {
  const [localSampleId, setLocalSampleId] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [showSuggestions, setShowSuggestions] = useState(false);
  const suggestionsRef = useRef<HTMLUListElement | null>(null);
  const [graphDistance, setGraphDistance] = useState<number>(2);

  const handoverAnnotations = useMemo(() => {
    const map = new Map<string, HandoverDetail[]>();

    const pushDetail = (sampleId: string | null | undefined, detail: HandoverDetail) => {
      if (!sampleId) return;
      if (!map.has(sampleId)) {
        map.set(sampleId, []);
      }
      map.get(sampleId)!.push(detail);
    };

    handovers.forEach((row) => {
      pushDetail(row.research_artefact_id, {
        role: "research",
        transferState: row.research_transfer_state,
        scopeKeys: row.research_scope_keys,
        handoverAt: row.handover_at,
        returnedAt: row.returned_at,
        propagationWhitelist: row.propagation_whitelist,
        counterpartName: row.ops_artefact_name,
        counterpartId: row.ops_artefact_id
      });

      pushDetail(row.ops_artefact_id, {
        role: "ops",
        transferState: row.ops_transfer_state,
        scopeKeys: row.ops_scope_keys,
        handoverAt: row.handover_at,
        returnedAt: row.returned_at,
        propagationWhitelist: row.propagation_whitelist,
        counterpartName: row.research_artefact_name,
        counterpartId: row.research_artefact_id
      });
    });

    return map;
  }, [handovers]);

  const samplesById = useMemo(() => {
    const map = new Map<string, SampleOverviewRow>();
    samples.forEach((row) => {
      map.set(row.id, row);
    });
    return map;
  }, [samples]);

  const selectedSampleId = focusedSampleId ?? localSampleId;

  const focusSample = useCallback(
    (sampleId: string) => {
      if (!samplesById.has(sampleId)) {
        return;
      }

      if (focusedSampleId) {
        if (focusedSampleId !== sampleId) {
          onSampleFocusChange?.(sampleId);
        }
      } else {
        setLocalSampleId(sampleId);
        onSampleFocusChange?.(sampleId);
      }
    },
    [focusedSampleId, onSampleFocusChange, samplesById]
  );

  useEffect(() => {
    if (focusedSampleId && samplesById.has(focusedSampleId)) {
      setLocalSampleId(focusedSampleId);
    }
  }, [focusedSampleId, samplesById]);

  useEffect(() => {
    if (focusedSampleId && samplesById.has(focusedSampleId)) {
      return;
    }

    if (!selectedSampleId) {
      const firstSample = samples[0];
      if (firstSample) {
        if (focusedSampleId) {
          onSampleFocusChange?.(firstSample.id);
        } else {
          setLocalSampleId(firstSample.id);
          onSampleFocusChange?.(firstSample.id);
        }
      }
    }
  }, [focusedSampleId, onSampleFocusChange, samples, samplesById, selectedSampleId]);

  const selectedSample = selectedSampleId
    ? samplesById.get(selectedSampleId) ?? null
    : null;

  const sampleSuggestions = useMemo(() => {
    if (!searchTerm) {
      return samples.slice(0, 15);
    }
    const norm = searchTerm.trim().toLowerCase();
    return samples
      .filter((sample) => sample.name.toLowerCase().includes(norm))
      .slice(0, 20);
  }, [samples, searchTerm]);

  useEffect(() => {
    if (selectedSample) {
      setSearchTerm(selectedSample.name);
    }
  }, [selectedSample]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        suggestionsRef.current &&
        !suggestionsRef.current.contains(event.target as Node)
      ) {
        setShowSuggestions(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const selectedHandoverDetails = selectedSample?.id
    ? handoverAnnotations.get(selectedSample.id) ?? []
    : [];

  const labwareById = useMemo(() => {
    const map = new Map<string, LabwareInventoryRow>();
    labwareInventory.forEach((row) => map.set(row.labware_id, row));
    return map;
  }, [labwareInventory]);

  const currentLabware = selectedSample?.current_labware_id
    ? labwareById.get(selectedSample.current_labware_id)
    : undefined;

  const { ancestors, descendants } = useMemo(() => {
    if (!selectedSampleId) {
      return { ancestors: [] as LineageNode[], descendants: [] as LineageNode[] };
    }

    const parentsByChild = new Map<string, SampleLineageRow[]>();
    const childrenByParent = new Map<string, SampleLineageRow[]>();

    lineage.forEach((row) => {
      if (!parentsByChild.has(row.child_sample_id)) {
        parentsByChild.set(row.child_sample_id, []);
      }
      parentsByChild.get(row.child_sample_id)!.push(row);

      if (!childrenByParent.has(row.parent_sample_id)) {
        childrenByParent.set(row.parent_sample_id, []);
      }
      childrenByParent.get(row.parent_sample_id)!.push(row);
    });

    const collect = (
      seed: string,
      relation: "ancestor" | "descendant"
    ): LineageNode[] => {
      const results: LineageNode[] = [];
      const visited = new Set<string>();
      const stack: Array<{ id: string; depth: number }> = [{
        id: seed,
        depth: 0
      }];

      while (stack.length) {
        const current = stack.pop()!;
        const edges =
          relation === "ancestor"
            ? parentsByChild.get(current.id) ?? []
            : childrenByParent.get(current.id) ?? [];

        edges.forEach((edge) => {
          const nextId = relation === "ancestor"
            ? edge.parent_sample_id
            : edge.child_sample_id;
          if (visited.has(nextId)) return;
          visited.add(nextId);

          const node: LineageNode = {
            sampleId: nextId,
            name:
              relation === "ancestor"
                ? edge.parent_sample_name ?? "Unknown sample"
                : edge.child_sample_name ?? "Unknown sample",
            method: edge.method,
            depth: current.depth + 1,
            labwareId:
              relation === "ancestor"
                ? edge.parent_labware_id
                : edge.child_labware_id,
            labwareLabel:
              relation === "ancestor"
                ? buildLabwareLabel(
                    edge.parent_labware_barcode,
                    edge.parent_labware_name
                  )
                : buildLabwareLabel(
                    edge.child_labware_barcode,
                    edge.child_labware_name
                  ),
            storagePath:
              relation === "ancestor"
                ? edge.parent_storage_path
                : edge.child_storage_path,
            relation,
            handoverDetails: handoverAnnotations.get(nextId) ?? []
          };

          results.push(node);
          stack.push({ id: nextId, depth: node.depth });
        });
      }

      return results.sort((a, b) => {
        if (a.depth !== b.depth) return a.depth - b.depth;
        return a.name.localeCompare(b.name);
      });
    };

    return {
      ancestors: collect(selectedSampleId, "ancestor"),
      descendants: collect(selectedSampleId, "descendant")
    };
  }, [handoverAnnotations, lineage, selectedSampleId]);

  const handleSelectLabware = (labwareId: string | null) => {
    if (!onSelectLabware) return;
    onSelectLabware(labwareId ?? null);
  };

  const handleFocusSample = (sampleId: string) => {
    focusSample(sampleId);
  };

  const handleSuggestionSelect = (sampleId: string) => {
    const sample = samplesById.get(sampleId);
    if (!sample) return;
    setSearchTerm(sample.name);
    setShowSuggestions(false);
    handleFocusSample(sampleId);
  };

  const handleSearchKey = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "Enter") {
      event.preventDefault();
      const firstSuggestion = sampleSuggestions[0];
      if (firstSuggestion) {
        handleSuggestionSelect(firstSuggestion.id);
      }
    }
    if (event.key === "Escape") {
      setShowSuggestions(false);
    }
  };

  const graphData = useMemo(() => {
    if (!selectedSampleId) {
      return {
        nodes: [] as ProvenanceGraphNode[],
        links: [] as ProvenanceGraphLink[]
      };
    }

    const nodeMap = new Map<string, ProvenanceGraphNode>();
    const edges: ProvenanceGraphLink[] = [];

    const registerNode = (
      id: string,
      name: string,
      relation: "ancestor" | "descendant" | "focus",
      depth: number
    ) => {
      const existing = nodeMap.get(id);
      if (!existing || depth < existing.depth) {
        nodeMap.set(id, { id, name, relation, depth });
      }
    };

    registerNode(
      selectedSampleId,
      selectedSample?.name ?? selectedSampleId,
      "focus",
      0
    );

    const parentsByChild = new Map<string, SampleLineageRow[]>();
    const childrenByParent = new Map<string, SampleLineageRow[]>();

    lineage.forEach((row) => {
      if (!parentsByChild.has(row.child_sample_id)) {
        parentsByChild.set(row.child_sample_id, []);
      }
      parentsByChild.get(row.child_sample_id)!.push(row);

      if (!childrenByParent.has(row.parent_sample_id)) {
        childrenByParent.set(row.parent_sample_id, []);
      }
      childrenByParent.get(row.parent_sample_id)!.push(row);
    });

    const expand = (
      seed: string,
      relation: "ancestor" | "descendant",
      maxDepth: number
    ) => {
      const stack: Array<{ id: string; depth: number }> = [{ id: seed, depth: 0 }];
      const seen = new Set<string>();

      while (stack.length) {
        const { id, depth } = stack.pop()!;
        const nextDepth = depth + 1;
        if (nextDepth > maxDepth) continue;

        const edgesForRelation = relation === "ancestor"
          ? parentsByChild.get(id) ?? []
          : childrenByParent.get(id) ?? [];

        edgesForRelation.forEach((edge) => {
          const targetId = relation === "ancestor"
            ? edge.parent_sample_id
            : edge.child_sample_id;
          if (!targetId || seen.has(targetId)) return;
          seen.add(targetId);

          const name = relation === "ancestor"
            ? edge.parent_sample_name ?? targetId
            : edge.child_sample_name ?? targetId;

          registerNode(targetId, name, relation, nextDepth);
          stack.push({ id: targetId, depth: nextDepth });

          if (relation === "ancestor") {
            edges.push({ source: targetId, target: id });
          } else {
            edges.push({ source: id, target: targetId });
          }
        });
      }
    };

    expand(selectedSampleId, "ancestor", graphDistance);
    expand(selectedSampleId, "descendant", graphDistance);

    return {
      nodes: Array.from(nodeMap.values()),
      links: edges
    };
  }, [lineage, selectedSample, selectedSampleId, graphDistance]);

  if (loading) {
    return <div className="provenance__state">Loading provenance data…</div>;
  }

  if (error) {
    return <div className="provenance__state provenance__state--error">{error}</div>;
  }

  if (!selectedSample) {
    return (
      <div className="provenance__state">
        Select a persona with sample access to explore provenance.
      </div>
    );
  }

  return (
    <div className="provenance">
      <div className="provenance__controls provenance__controls--search">
        <label className="provenance__label" htmlFor="provenance-sample-search">
          Focus sample
        </label>
        <div className="provenance__search">
          <input
            id="provenance-sample-search"
            type="search"
            placeholder="Search samples by name…"
            value={searchTerm}
            onChange={(event) => {
              setSearchTerm(event.target.value);
              setShowSuggestions(true);
            }}
            onFocus={() => setShowSuggestions(true)}
            onKeyDown={handleSearchKey}
            autoComplete="off"
          />
          {showSuggestions && sampleSuggestions.length > 0 && (
            <ul className="provenance__search-results" ref={suggestionsRef}>
              {sampleSuggestions.map((sample) => (
                <li key={sample.id}>
                  <button
                    type="button"
                    onClick={() => handleSuggestionSelect(sample.id)}
                  >
                    <span className="provenance__search-result-name">
                      {sample.name}
                    </span>
                    <span className="provenance__search-result-meta">
                      {sample.project_code ?? sample.project_name ?? "—"}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
        <div className="provenance__distance">
          <label htmlFor="provenance-distance">Graph depth</label>
          <input
            id="provenance-distance"
            type="number"
            min={1}
            max={5}
            value={graphDistance}
            onChange={(event) =>
              setGraphDistance(
                Math.min(5, Math.max(1, Number(event.target.value) || 1))
              )
            }
          />
        </div>
      </div>

      <div className="provenance__summary">
        <div>
          <h3>{selectedSample.name}</h3>
          <dl>
            <div>
              <dt>Type</dt>
              <dd>{selectedSample.sample_type_code ?? "—"}</dd>
            </div>
            <div>
              <dt>Status</dt>
              <dd>{selectedSample.sample_status ?? "—"}</dd>
            </div>
            <div>
              <dt>Project</dt>
              <dd>{selectedSample.project_name ?? selectedSample.project_code ?? "—"}</dd>
            </div>
            <div>
              <dt>Collected</dt>
              <dd>{formatDateTime(selectedSample.collected_at)}</dd>
            </div>
          </dl>
        </div>

        <div className="provenance__summary-card">
          <h4>Current Labware</h4>
          <p>
            {buildLabwareLabel(
              selectedSample.current_labware_barcode,
              selectedSample.current_labware_name
            )}
          </p>
          <p className="provenance__summary-path">
            {selectedSample.storage_path ?? "Checked out / location pending"}
          </p>
          {selectedSample.current_labware_id && (
            <button
              type="button"
              className="provenance__button"
              onClick={() => handleSelectLabware(selectedSample.current_labware_id)}
            >
              View labware in storage explorer
            </button>
          )}
        </div>

        {currentLabware && (
          <div className="provenance__summary-card">
            <h4>Active Contents</h4>
            <p>
              {currentLabware.active_sample_count} sample(s) currently linked
            </p>
            {!!currentLabware.active_samples?.length && (
              <ul>
                {currentLabware.active_samples.slice(0, 5).map((item) => (
                  <li key={item.sample_id}>
                    {item.sample_name ?? item.sample_id}
                  </li>
                ))}
                {currentLabware.active_samples.length > 5 && (
                  <li className="provenance__more">
                    +{currentLabware.active_samples.length - 5} more
                  </li>
                )}
              </ul>
            )}
          </div>
        )}

        {selectedHandoverDetails.length > 0 && (
          <div className="provenance__summary-card provenance__summary-card--handover">
            <h4>Handover Visibility</h4>
            <div className="provenance__handover-summary">
              {selectedHandoverDetails.map((detail, index) => (
                <div
                  key={`${detail.role}-${detail.counterpartId}-${index}`}
                  className="provenance__handover-item"
                >
                  <div
                    className={`provenance__handover-badge provenance__handover-badge--${detail.role}`}
                  >
                    <span>
                      {detail.role === "ops" ? "Ops duplicate" : "Research source"}
                    </span>
                    {detail.transferState && (
                      <span className="provenance__handover-state">
                        {detail.transferState}
                      </span>
                    )}
                  </div>
                  <div className="provenance__handover-meta">
                    <span>
                      Counterpart: {detail.counterpartName ?? detail.counterpartId}
                    </span>
                    <span>Scopes: {formatList(detail.scopeKeys)}</span>
                    <span>Whitelist: {formatList(detail.propagationWhitelist)}</span>
                    {detail.handoverAt && (
                      <span>Handover: {formatDateTime(detail.handoverAt)}</span>
                    )}
                    {detail.returnedAt && (
                      <span>Returned: {formatDateTime(detail.returnedAt)}</span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {graphData.nodes.length > 0 && (
        <section className="provenance__graph-section">
          <h4>Lineage Graph (depth {graphDistance})</h4>
          <ProvenanceGraph
            nodes={graphData.nodes}
            links={graphData.links}
            onNodeFocus={handleFocusSample}
          />
        </section>
      )}

      <div className="provenance__columns">
        <div className="provenance__column">
          <h4>Ancestors</h4>
          {ancestors.length === 0 && (
            <p className="provenance__empty">No ancestor samples recorded.</p>
          )}
          {ancestors.map((node) => {
            const nodeClasses = ["provenance__node"];
            if (node.sampleId === selectedSampleId) {
              nodeClasses.push("provenance__node--active");
            }
            if (node.handoverDetails.length > 0) {
              nodeClasses.push("provenance__node--handover");
            }

            return (
              <div
                key={`ancestor-${node.sampleId}`}
                role="button"
                tabIndex={0}
                className={nodeClasses.join(" ")}
                onClick={() => handleFocusSample(node.sampleId)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" || event.key === " ") {
                    event.preventDefault();
                    handleFocusSample(node.sampleId);
                  }
                }}
              >
                <span className="provenance__node-title">{node.name}</span>
                <span className="provenance__node-meta">
                  {node.method ?? "Method unknown"} • Depth {node.depth}
                </span>
                <span className="provenance__node-labware">
                  {node.labwareLabel}
                </span>
                <span className="provenance__node-path">
                  {node.storagePath ?? "Checked out / location pending"}
                </span>
                {node.handoverDetails.length > 0 && (
                  <div className="provenance__handover-badges">
                    {node.handoverDetails.map((detail, detailIndex) => (
                      <span
                        key={`${node.sampleId}-${detail.role}-${detailIndex}`}
                        className={`provenance__handover-badge provenance__handover-badge--${detail.role}`}
                        title={`Scopes: ${formatList(detail.scopeKeys)}\nWhitelist: ${formatList(detail.propagationWhitelist)}`}
                      >
                        {detail.role === "ops" ? "Ops" : "Research"}
                        {detail.transferState ? ` • ${detail.transferState}` : ""}
                      </span>
                    ))}
                  </div>
                )}
                {node.labwareId && (
                  <button
                    type="button"
                    className={
                      "provenance__link" +
                      (node.labwareId === selectedLabwareId
                        ? " provenance__link--active"
                        : "")
                    }
                    onClick={(event) => {
                      event.stopPropagation();
                      handleSelectLabware(node.labwareId);
                    }}
                  >
                    Open labware in explorer
                  </button>
                )}
              </div>
            );
          })}
        </div>
        <div className="provenance__column">
          <h4>Descendants</h4>
          {descendants.length === 0 && (
            <p className="provenance__empty">No descendant samples recorded.</p>
          )}
          {descendants.map((node) => {
            const nodeClasses = ["provenance__node"];
            if (node.sampleId === selectedSampleId) {
              nodeClasses.push("provenance__node--active");
            }
            if (node.handoverDetails.length > 0) {
              nodeClasses.push("provenance__node--handover");
            }

            return (
              <div
                key={`descendant-${node.sampleId}`}
                role="button"
                tabIndex={0}
                className={nodeClasses.join(" ")}
                onClick={() => handleFocusSample(node.sampleId)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" || event.key === " ") {
                    event.preventDefault();
                    handleFocusSample(node.sampleId);
                  }
                }}
              >
                <span className="provenance__node-title">{node.name}</span>
                <span className="provenance__node-meta">
                  {node.method ?? "Method unknown"} • Depth {node.depth}
                </span>
                <span className="provenance__node-labware">
                  {node.labwareLabel}
                </span>
                <span className="provenance__node-path">
                  {node.storagePath ?? "Checked out / location pending"}
                </span>
                {node.handoverDetails.length > 0 && (
                  <div className="provenance__handover-badges">
                    {node.handoverDetails.map((detail, detailIndex) => (
                      <span
                        key={`${node.sampleId}-${detail.role}-${detailIndex}`}
                        className={`provenance__handover-badge provenance__handover-badge--${detail.role}`}
                        title={`Scopes: ${formatList(detail.scopeKeys)}\nWhitelist: ${formatList(detail.propagationWhitelist)}`}
                      >
                        {detail.role === "ops" ? "Ops" : "Research"}
                        {detail.transferState ? ` • ${detail.transferState}` : ""}
                      </span>
                    ))}
                  </div>
                )}
                {node.labwareId && (
                  <button
                    type="button"
                    className={
                      "provenance__link" +
                      (node.labwareId === selectedLabwareId
                        ? " provenance__link--active"
                        : "")
                    }
                    onClick={(event) => {
                      event.stopPropagation();
                      handleSelectLabware(node.labwareId);
                    }}
                  >
                    Open labware in explorer
                  </button>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
