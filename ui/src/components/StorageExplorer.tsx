import { useEffect, useMemo, useState } from "react";
import type {
  LabwareInventoryRow,
  StorageTreeRow
} from "../types";

interface StorageExplorerProps {
  storageTree: StorageTreeRow[];
  labwareInventory: LabwareInventoryRow[];
  loading: boolean;
  error: string | null;
  onSelectLabware?: (labwareId: string | null) => void;
  selectedLabwareId?: string | null;
  onSelectSample?: (sampleId: string) => void;
  availableSampleIds?: string[];
}

type FacilityOption = {
  id: string;
  name: string;
};

type UnitOption = {
  id: string;
  name: string;
};

type SublocationOption = {
  id: string | null;
  name: string;
  capacity: number | null;
  storagePath: string | null;
  labwareCount: number;
  sampleCount: number;
};

export function StorageExplorer({
  storageTree,
  labwareInventory,
  loading,
  error,
  onSelectLabware,
  selectedLabwareId,
  onSelectSample,
  availableSampleIds
}: StorageExplorerProps) {
  const [facilityId, setFacilityId] = useState<string | null>(null);
  const [unitId, setUnitId] = useState<string | null>(null);
  const [sublocationId, setSublocationId] = useState<string | null>(null);

  const facilities: FacilityOption[] = useMemo(() => {
    const seen = new Map<string, FacilityOption>();
    storageTree.forEach((row) => {
      if (!row.facility_id || !row.facility_name) {
        return;
      }
      if (!seen.has(row.facility_id)) {
        seen.set(row.facility_id, {
          id: row.facility_id,
          name: row.facility_name
        });
      }
    });
    return Array.from(seen.values()).sort((a, b) => a.name.localeCompare(b.name));
  }, [storageTree]);

  const units: UnitOption[] = useMemo(() => {
    if (!facilityId) return [];
    const seen = new Map<string, UnitOption>();
    storageTree
      .filter((row) => row.facility_id === facilityId && row.unit_id && row.unit_name)
      .forEach((row) => {
        if (!seen.has(row.unit_id)) {
          seen.set(row.unit_id, { id: row.unit_id, name: row.unit_name });
        }
      });
    return Array.from(seen.values()).sort((a, b) => a.name.localeCompare(b.name));
  }, [storageTree, facilityId]);

  const sublocations: SublocationOption[] = useMemo(() => {
    if (!facilityId || !unitId) return [];
    return storageTree
      .filter((row) => row.facility_id === facilityId && row.unit_id === unitId)
      .map((row) => ({
        id: row.sublocation_id,
        name: row.sublocation_name ?? "Unspecified location",
        capacity: row.capacity,
        storagePath: row.storage_path,
        labwareCount: row.labware_count,
        sampleCount: row.sample_count
      }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }, [storageTree, facilityId, unitId]);

  const storageNodeBySublocation = useMemo(() => {
    const map = new Map<string, StorageTreeRow>();
    storageTree.forEach((row) => {
      if (row.sublocation_id) {
        map.set(row.sublocation_id, row);
      }
    });
    return map;
  }, [storageTree]);

  useEffect(() => {
    if (!facilityId && facilities.length > 0) {
      setFacilityId(facilities[0].id);
    }
  }, [facilityId, facilities]);

  useEffect(() => {
    if (!facilityId) {
      setUnitId(null);
      return;
    }
    if (units.length > 0 && !units.some((unit) => unit.id === unitId)) {
      setUnitId(units[0].id);
    }
  }, [facilityId, units, unitId]);

  useEffect(() => {
    if (!unitId) {
      setSublocationId(null);
      return;
    }
    if (
      sublocations.length > 0 &&
      !sublocations.some((location) => location.id === sublocationId)
    ) {
      setSublocationId(sublocations[0].id);
    }
  }, [unitId, sublocations, sublocationId]);

  useEffect(() => {
    if (!selectedLabwareId) return;
    const labware = labwareInventory.find(
      (item) => item.labware_id === selectedLabwareId
    );
    if (!labware || !labware.current_storage_sublocation_id) return;

    const node = storageNodeBySublocation.get(
      labware.current_storage_sublocation_id
    );
    if (!node) return;

    setFacilityId((current) =>
      current === node.facility_id ? current : node.facility_id
    );
    setUnitId((current) =>
      current === node.unit_id ? current : node.unit_id
    );
    setSublocationId((current) =>
      current === node.sublocation_id ? current : node.sublocation_id
    );
  }, [selectedLabwareId, labwareInventory, storageNodeBySublocation]);

  const labwareInSublocation = useMemo(() => {
    if (!sublocationId) return [] as LabwareInventoryRow[];
    return labwareInventory
      .filter(
        (row) => row.current_storage_sublocation_id === sublocationId
      )
      .sort((a, b) => {
        const labelA = a.barcode ?? a.display_name ?? a.labware_id;
        const labelB = b.barcode ?? b.display_name ?? b.labware_id;
        return labelA.localeCompare(labelB);
      });
  }, [labwareInventory, sublocationId]);

  const selectedLabware = selectedLabwareId
    ? labwareInventory.find((row) => row.labware_id === selectedLabwareId) ?? null
    : null;

  const availableSampleIdSet = useMemo(() => {
    if (!availableSampleIds) return null;
    return new Set(availableSampleIds);
  }, [availableSampleIds]);

  const formatSampleBadge = (status: string | null) => {
    if (!status) return "Sample";
    return status
      .split("_")
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(" ");
  };

  const handleResetView = () => {
    onSelectLabware?.(null);
    setFacilityId(null);
    setUnitId(null);
    setSublocationId(null);
  };

  if (loading) {
    return <div className="storage-explorer__state">Loading storage data…</div>;
  }

  if (error) {
    return (
      <div className="storage-explorer__state storage-explorer__state--error">
        {error}
      </div>
    );
  }

  if (facilities.length === 0) {
    return (
      <div className="storage-explorer__state">
        No storage hierarchy available for the current persona.
      </div>
    );
  }

  return (
    <div className="storage-explorer">
      <div className="storage-explorer__controls">
        <label>
          Facility
          <select
            value={facilityId ?? ""}
            onChange={(event) => {
              setFacilityId(event.target.value);
              setUnitId(null);
              setSublocationId(null);
              onSelectLabware?.(null);
            }}
          >
            {facilities.map((facility) => (
              <option key={facility.id} value={facility.id}>
                {facility.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Unit
          <select
            value={unitId ?? ""}
            onChange={(event) => {
              setUnitId(event.target.value);
              setSublocationId(null);
              onSelectLabware?.(null);
            }}
          >
            {units.map((unit) => (
              <option key={unit.id} value={unit.id}>
                {unit.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Sublocation
          <select
            value={sublocationId ?? ""}
            onChange={(event) => {
              setSublocationId(event.target.value || null);
              onSelectLabware?.(null);
            }}
          >
            {sublocations.map((location) => (
              <option key={location.id ?? "null"} value={location.id ?? ""}>
                {location.name}
                {location.capacity ? ` (cap ${location.capacity})` : ""}
              </option>
            ))}
          </select>
        </label>
        <button
          type="button"
          className="storage-explorer__reset"
          onClick={handleResetView}
          disabled={!facilities.length}
        >
          Reset view
        </button>
      </div>

      <div className="storage-explorer__content">
        <div className="storage-explorer__sublocations">
          <h4>Sublocations</h4>
          {sublocations.length === 0 && <p>No sublocations found.</p>}
          <ul>
            {sublocations.map((location) => (
              <li
                key={location.id ?? "null"}
                className={
                  "storage-explorer__sublocation" +
                  (location.id === sublocationId ? " storage-explorer__sublocation--active" : "")
                }
              >
                <button
                  type="button"
                  onClick={() => {
                    setSublocationId(location.id);
                    onSelectLabware?.(null);
                  }}
                >
                  <span className="storage-explorer__sublocation-name">
                    {location.name}
                  </span>
                  <span className="storage-explorer__sublocation-meta">
                    {location.labwareCount} labware • {location.sampleCount} samples
                  </span>
                  <span className="storage-explorer__sublocation-path">
                    {location.storagePath ?? "Untracked location"}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </div>

        <div className="storage-explorer__labware">
          <h4>Labware in selection</h4>
          {sublocationId === null && (
            <p>Select a sublocation to view labware.</p>
          )}
          {sublocationId !== null && labwareInSublocation.length === 0 && (
            <p>No labware currently assigned.</p>
          )}
          <ul>
            {labwareInSublocation.map((labware) => {
              const label = labware.barcode ?? labware.display_name ?? labware.labware_id;
              const isActive = labware.labware_id === selectedLabwareId;
              return (
                <li key={labware.labware_id}>
                  <button
                    type="button"
                    className={
                      "storage-explorer__labware-item" +
                      (isActive ? " storage-explorer__labware-item--active" : "")
                    }
                    onClick={() =>
                      onSelectLabware?.(isActive ? null : labware.labware_id)
                    }
                  >
                    <span className="storage-explorer__labware-label">{label}</span>
                    <span className="storage-explorer__labware-meta">
                      {labware.active_sample_count} sample(s)
                    </span>
                    <span className="storage-explorer__labware-path">
                      {labware.storage_path ?? "Checked out / transit"}
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        </div>

        <div className="storage-explorer__details">
          <h4>Labware details</h4>
          {!selectedLabware && <p>Select labware to view its contents.</p>}
          {selectedLabware && (
            <div className="storage-explorer__details-card">
              <h5>
                {selectedLabware.barcode ?? selectedLabware.display_name ?? selectedLabware.labware_id}
              </h5>
              <button
                type="button"
                className="storage-explorer__clear"
                onClick={() => onSelectLabware?.(null)}
              >
                Clear labware focus
              </button>
              <dl>
                <div>
                  <dt>Type</dt>
                  <dd>{selectedLabware.labware_type ?? "—"}</dd>
                </div>
                <div>
                  <dt>Status</dt>
                  <dd>{selectedLabware.status ?? "—"}</dd>
                </div>
                <div>
                  <dt>Storage path</dt>
                  <dd>{selectedLabware.storage_path ?? "Checked out / transit"}</dd>
                </div>
                <div>
                  <dt>Active samples</dt>
                  <dd>{selectedLabware.active_sample_count}</dd>
                </div>
              </dl>
              {selectedLabware.active_samples &&
                selectedLabware.active_samples.length > 0 && (
                  <div>
                    <h6>Samples in this labware</h6>
                    <ul className="storage-explorer__sample-list">
                      {selectedLabware.active_samples.map((sample) => {
                        const isAvailable = availableSampleIdSet?.has(sample.sample_id) ?? true;
                        return (
                          <li key={sample.sample_id} className="storage-explorer__sample-item">
                            <span className="storage-explorer__sample-badge">
                              {formatSampleBadge(sample.sample_status)}
                            </span>
                            <div className="storage-explorer__sample-body">
                              <span className="storage-explorer__sample-name">
                                {sample.sample_name ?? sample.sample_id}
                              </span>
                              <span className="storage-explorer__sample-status">
                                Status: {sample.sample_status ?? "unknown"}
                              </span>
                              {isAvailable && onSelectSample ? (
                                <button
                                  type="button"
                                  className="storage-explorer__sample-link"
                                  onClick={() => onSelectSample(sample.sample_id)}
                                >
                                  Focus in provenance explorer
                                </button>
                              ) : (
                                <span className="storage-explorer__sample-unavailable">
                                  Not available in provenance explorer
                                </span>
                              )}
                            </div>
                          </li>
                        );
                      })}
                    </ul>
                  </div>
                )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
