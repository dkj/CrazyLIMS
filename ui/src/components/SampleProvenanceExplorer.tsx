import { useCallback, useEffect, useMemo, useState } from "react";
import type {
  LabwareInventoryRow,
  SampleLineageRow,
  SampleOverviewRow
} from "../types";

interface SampleProvenanceExplorerProps {
  samples: SampleOverviewRow[];
  lineage: SampleLineageRow[];
  labwareInventory: LabwareInventoryRow[];
  loading: boolean;
  error: string | null;
  onSelectLabware?: (labwareId: string) => void;
  selectedLabwareId?: string | null;
  focusedSampleId?: string | null;
  onSampleFocusChange?: (sampleId: string) => void;
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

export function SampleProvenanceExplorer({
  samples,
  lineage,
  labwareInventory,
  loading,
  error,
  onSelectLabware,
  selectedLabwareId,
  focusedSampleId,
  onSampleFocusChange
}: SampleProvenanceExplorerProps) {
  const [localSampleId, setLocalSampleId] = useState<string | null>(null);

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
            relation
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
  }, [lineage, selectedSampleId]);

  const handleSelectLabware = (labwareId: string | null) => {
    if (!labwareId || !onSelectLabware) return;
    onSelectLabware(labwareId);
  };

  const handleFocusSample = (sampleId: string) => {
    focusSample(sampleId);
  };

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
      <div className="provenance__controls">
        <label className="provenance__label" htmlFor="provenance-sample-select">
          Focus sample
        </label>
        <select
          id="provenance-sample-select"
          value={selectedSampleId ?? ""}
          onChange={(event) => handleFocusSample(event.target.value)}
        >
          {samples.map((sample) => (
            <option key={sample.id} value={sample.id}>
              {sample.name} ({sample.project_code ?? sample.project_name ?? "—"})
            </option>
          ))}
        </select>
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
            <p>{currentLabware.active_sample_count} sample(s) currently linked</p>
            {!!currentLabware.active_samples?.length && (
              <ul>
                {currentLabware.active_samples.map((item) => (
                  <li key={item.sample_id}>{item.sample_name ?? item.sample_id}</li>
                ))}
              </ul>
            )}
          </div>
        )}
      </div>

      <div className="provenance__columns">
        <div className="provenance__column">
          <h4>Ancestors</h4>
          {ancestors.length === 0 && (
            <p className="provenance__empty">No ancestor samples recorded.</p>
          )}
          {ancestors.map((node) => (
            <div
              key={`ancestor-${node.sampleId}`}
              role="button"
              tabIndex={0}
              className={
                "provenance__node" +
                (node.sampleId === selectedSampleId
                  ? " provenance__node--active"
                  : "")
              }
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
          ))}
        </div>
        <div className="provenance__column">
          <h4>Descendants</h4>
          {descendants.length === 0 && (
            <p className="provenance__empty">No descendant samples recorded.</p>
          )}
          {descendants.map((node) => (
            <div
              key={`descendant-${node.sampleId}`}
              role="button"
              tabIndex={0}
              className={
                "provenance__node" +
                (node.sampleId === selectedSampleId
                  ? " provenance__node--active"
                  : "")
              }
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
          ))}
        </div>
      </div>
    </div>
  );
}
