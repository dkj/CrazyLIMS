import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  NavLink,
  Navigate,
  Route,
  Routes,
  useLocation,
  useNavigate
} from "react-router-dom";
import { PersonaSelector } from "./components/PersonaSelector";
import { DataTable } from "./components/DataTable";
import type { Column } from "./components/DataTable";
import { SampleProvenanceExplorer } from "./components/SampleProvenanceExplorer";
import { StorageExplorer } from "./components/StorageExplorer";
import { NotebookWorkbench } from "./components/NotebookWorkbench";
import { NotebookIframeDemo } from "./components/NotebookIframeDemo";
import type {
  SampleOverviewRow,
  LabwareContentRow,
  InventoryStatusRow,
  UserRow,
  ProjectAccessRow,
  SampleLineageRow,
  LabwareInventoryRow,
  StorageTreeRow,
  TransactionContextActivityRow,
  AuditRecentActivityRow,
  HandoverOverviewRow,
  ScopeTransferOverviewRow
} from "./types";

const POSTGREST_URL: string = (globalThis as any).__POSTGREST_URL__;
const API_BASE = POSTGREST_URL.replace(/\/$/, "");

const personaLabels: Record<string, string> = {
  admin: "Administrator",
  operator: "Ops Operator",
  researcher: "Researcher (Alice)",
  researcher_bob: "Researcher (Bob)",
  roberto: "Researcher (Roberto – Alpha Virtual)",
  phillipa: "Researcher (Phillipa – Alpha Lab Lead)",
  ross: "Researcher (Ross – Alpha Lab Tech)",
  eric: "Researcher (Eric – Beta)",
  lucy: "Ops Tech (Lucy)",
  fred: "Ops Tech (Fred)",
  instrument_alpha: "Instrument (Alpha Sequencer)",
  external: "External Collaborator"
};

const personaTokenPaths: Record<string, string> = {
  admin: "/tokens/admin.jwt",
  operator: "/tokens/operator.jwt",
  researcher: "/tokens/researcher.jwt",
  researcher_bob: "/tokens/researcher_bob.jwt",
  roberto: "/tokens/roberto.jwt",
  phillipa: "/tokens/phillipa.jwt",
  ross: "/tokens/ross.jwt",
  eric: "/tokens/eric.jwt",
  lucy: "/tokens/lucy.jwt",
  fred: "/tokens/fred.jwt",
  instrument_alpha: "/tokens/instrument_alpha.jwt",
  external: "/tokens/external.jwt"
};

function decodeJwt(token: string | undefined) {
  if (!token) return null;
  const parts = token.split(".");
  if (parts.length < 2) return null;

  try {
    const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = decodeURIComponent(
      atob(base64)
        .split("")
        .map((char) => `%${char.charCodeAt(0).toString(16).padStart(2, "0")}`)
        .join("")
    );
    return JSON.parse(json) as Record<string, unknown>;
  } catch (error) {
    console.error("Failed to decode JWT", error);
    return null;
  }
}

function usePersonaToken(selected: string | null): string | undefined {
  const [token, setToken] = useState<string | undefined>(undefined);

  useEffect(() => {
    if (!selected) {
      setToken(undefined);
      return;
    }

    const path = personaTokenPaths[selected];
    fetch(path)
      .then(async (res) => {
        if (!res.ok) throw new Error(`Failed to load token for ${selected}`);
        const text = await res.text();
        setToken(text.trim());
      })
      .catch((err) => {
        console.error(err);
        setToken(undefined);
      });
  }, [selected]);

  return token;
}

function useGet<T>(endpoint: string, token: string | undefined) {
  const [data, setData] = useState<T[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) {
      setData([]);
      setError(null);
      return;
    }

    let cancelled = false;

    const fetchData = async () => {
      setLoading(true);
      setError(null);

      try {
        const res = await fetch(`${API_BASE}${endpoint}`, {
          headers: {
            Authorization: `Bearer ${token}`
          }
        });

        if (res.status === 401 || res.status === 403) {
          if (!cancelled) {
            setData([]);
            setError("You do not have access to this data.");
          }
          return;
        }

        if (!res.ok) {
          const body = await res.text();
          throw new Error(`${res.status} ${res.statusText}: ${body}`);
        }

        const payload: T[] = await res.json();
        if (!cancelled) {
          setData(payload);
        }
      } catch (err) {
        console.error(err);
        if (!cancelled) {
          setError(err instanceof Error ? err.message : String(err));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    fetchData();

    return () => {
      cancelled = true;
    };
  }, [endpoint, token]);

  return { data, loading, error };
}

type SectionDefinition = {
  path: string;
  label: string;
  element: JSX.Element;
};

export default function App() {
  const [persona, setPersona] = useState<string | null>(null);
  const token = usePersonaToken(persona);
  const claims = useMemo(() => decodeJwt(token), [token]);
  const location = useLocation();
  const navigate = useNavigate();

  const activeRoles = useMemo(() => {
    if (!claims) return [] as string[];
    const rolesClaim = (claims["roles"] ?? claims["role"]) as unknown;

    if (Array.isArray(rolesClaim)) {
      return Array.from(new Set(rolesClaim.map((role) => String(role))));
    }

    if (typeof rolesClaim === "string") {
      return [rolesClaim];
    }

    return [];
  }, [claims]);

  const displayName = useMemo(() => {
    if (!claims) return null;
    const fullName = claims["full_name"];
    const email = claims["email"];
    if (typeof fullName === "string") return fullName;
    if (typeof email === "string") return email;
    return null;
  }, [claims]);

  const personaLabel = persona ? personaLabels[persona] : null;

  const sampleView = useGet<SampleOverviewRow>("/v_sample_overview", token);
  const labwareView = useGet<LabwareContentRow>("/v_labware_contents", token);
  const inventoryView = useGet<InventoryStatusRow>("/v_inventory_status", token);
  const usersView = useGet<UserRow>("/users", token);
  const projectSummaryView = useGet<ProjectAccessRow>(
    "/v_project_access_overview",
    token
  );
  const sampleLineageView = useGet<SampleLineageRow>(
    "/v_sample_lineage",
    token
  );
  const handoverOverviewView = useGet<HandoverOverviewRow>(
    "/v_handover_overview",
    token
  );
  const scopeTransferView = useGet<ScopeTransferOverviewRow>(
    "/v_scope_transfer_overview",
    token
  );
  const labwareInventoryView = useGet<LabwareInventoryRow>(
    "/v_labware_inventory",
    token
  );
  const storageTreeView = useGet<StorageTreeRow>("/v_storage_tree", token);
  const availableSampleIds = useMemo(
    () => sampleView.data.map((row) => row.id),
    [sampleView.data]
  );
  const txnActivityView = useGet<TransactionContextActivityRow>(
    "/v_transaction_context_activity",
    token
  );
  const auditActivityView = useGet<AuditRecentActivityRow>(
    "/v_audit_recent_activity",
    token
  );

  const [focusedLabwareId, setFocusedLabwareId] = useState<string | null>(null);
  const [focusedSampleId, setFocusedSampleId] = useState<string | null>(null);

  useEffect(() => {
    setFocusedLabwareId(null);
    setFocusedSampleId(null);
  }, [token]);

  useEffect(() => {
    if (!focusedSampleId) return;
    if (!sampleView.data.some((row) => row.id === focusedSampleId)) {
      setFocusedSampleId(null);
    }
  }, [focusedSampleId, sampleView.data]);

  const samplesSectionRef = useRef<HTMLDivElement | null>(null);
  const storageSectionRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!persona) return;
    const path = location.pathname;
    if (path.startsWith("/storage")) {
      storageSectionRef.current?.focus();
    } else if (path.startsWith("/samples")) {
      samplesSectionRef.current?.focus();
    }
  }, [location.pathname, persona]);

  const handleLabwareSelection = (labwareId: string | null) => {
    setFocusedLabwareId(labwareId);
  };

  const handleLabwareSelectionWithNavigation = (labwareId: string | null) => {
    setFocusedLabwareId(labwareId);
    if (!labwareId) return;

    if (!location.pathname.startsWith("/storage")) {
      navigate("/storage");
    } else {
      storageSectionRef.current?.focus();
    }
  };

const handleSampleFocus = (sampleId: string) => {
  setFocusedSampleId(sampleId);
};

const handleSampleFocusWithNavigation = (sampleId: string) => {
  setFocusedSampleId(sampleId);
  if (!location.pathname.startsWith("/samples")) {
    navigate("/samples");
  } else {
    samplesSectionRef.current?.focus();
  }
};

const navigateToSampleIfVisible = useCallback(
  (artefactId: string | null) => {
    if (!artefactId) return;
    if (availableSampleIds.includes(artefactId)) {
      handleSampleFocusWithNavigation(artefactId);
    }
  },
  [availableSampleIds, handleSampleFocusWithNavigation]
);

  const sampleColumns = useMemo<Column<SampleOverviewRow>[]>(
    () => [
      {
        key: "name",
        label: "Sample",
        render: (row) => (
          <button
            type="button"
            className="table__link-button"
            onClick={(event) => {
              event.stopPropagation();
              handleSampleFocusWithNavigation(row.id);
            }}
          >
            {row.name}
          </button>
        )
      },
      { key: "project_code", label: "Project" },
      { key: "project_name", label: "Project Name" },
      { key: "sample_type_code", label: "Type" },
      { key: "sample_status", label: "Status" },
      { key: "collected_at", label: "Collected" },
      {
        key: "current_labware_barcode",
        label: "Labware",
        render: (row) => {
          if (!row.current_labware_id) {
            return row.current_labware_barcode ?? "—";
          }
          const label =
            row.current_labware_barcode ??
            row.current_labware_name ??
            "View labware";
          return (
            <button
              type="button"
              className="table__link-button"
              onClick={(event) => {
                event.stopPropagation();
                handleLabwareSelectionWithNavigation(row.current_labware_id!);
              }}
            >
              {label}
            </button>
          );
        }
      },
      { key: "storage_path", label: "Storage Path" }
    ],
    [handleLabwareSelectionWithNavigation, handleSampleFocusWithNavigation]
  );

  const labwareColumns = useMemo<Column<LabwareContentRow>[]>(
    () => [
      { key: "barcode", label: "Labware" },
      { key: "display_name", label: "Name" },
      { key: "status", label: "Status" },
      { key: "position_label", label: "Position" },
      { key: "sample_name", label: "Sample" },
      { key: "volume", label: "Volume" },
      { key: "volume_unit", label: "Unit" }
    ],
    []
  );

  const scopeTransferColumns = useMemo<Column<ScopeTransferOverviewRow>[]>(
    () => [
      {
        key: "source_artefact_name",
        label: "Source",
        render: (row) => {
          if (availableSampleIds.includes(row.source_artefact_id)) {
            return (
              <button
                type="button"
                className="table__link-button"
                onClick={() => navigateToSampleIfVisible(row.source_artefact_id)}
              >
                {row.source_artefact_name ?? row.source_artefact_id}
              </button>
            );
          }
          return row.source_artefact_name ?? row.source_artefact_id;
        }
      },
      {
        key: "target_artefact_name",
        label: "Target",
        render: (row) => {
          if (availableSampleIds.includes(row.target_artefact_id)) {
            return (
              <button
                type="button"
                className="table__link-button"
                onClick={() => navigateToSampleIfVisible(row.target_artefact_id)}
              >
                {row.target_artefact_name ?? row.target_artefact_id}
              </button>
            );
          }
          return row.target_artefact_name ?? row.target_artefact_id;
        }
      },
      { key: "relationship_type", label: "Type" },
      {
        key: "allowed_roles",
        label: "Allowed Roles",
        render: (row) => row.allowed_roles?.join(", ") ?? ""
      },
      { key: "handover_at", label: "Handed Over" },
      { key: "returned_at", label: "Returned" }
    ],
    [availableSampleIds, navigateToSampleIfVisible]
  );

  const inventoryColumns = useMemo<Column<InventoryStatusRow>[]>(
    () => [
      { key: "name", label: "Item" },
      { key: "barcode", label: "Barcode" },
      { key: "quantity", label: "Qty" },
      { key: "unit", label: "Unit" },
      { key: "below_threshold", label: "Below Min" },
      { key: "expires_at", label: "Expires" }
    ],
    []
  );

  const userColumns = useMemo<Column<UserRow>[]>(
    () => [
      { key: "email", label: "Email" },
      { key: "full_name", label: "Name" },
      { key: "default_role", label: "Default Role" },
      { key: "is_service_account", label: "Service Account" }
    ],
    []
  );

  const projectColumns = useMemo<Column<ProjectAccessRow>[]>(
    () => [
      { key: "project_code", label: "Code" },
      { key: "name", label: "Project" },
      { key: "access_via", label: "Access Via" },
      { key: "is_member", label: "Member" },
      { key: "sample_count", label: "Samples" },
      { key: "active_labware_count", label: "Active Labware" }
    ],
    []
  );

  const txnActivityColumns = useMemo<Column<TransactionContextActivityRow>[]>(
    () => [
      { key: "started_hour", label: "Started Hour" },
      { key: "client_app", label: "Client" },
      { key: "finished_status", label: "Status" },
      { key: "context_count", label: "Contexts" },
      { key: "open_contexts", label: "Open" }
    ],
    []
  );

  const auditActivityColumns = useMemo<Column<AuditRecentActivityRow>[]>(
    () => [
      { key: "performed_at", label: "Performed At" },
      { key: "operation", label: "Operation" },
      { key: "schema_name", label: "Schema" },
      { key: "table_name", label: "Table" },
      { key: "txn_id", label: "Transaction" },
      { key: "actor_identity", label: "Actor Identity" },
      { key: "actor_roles", label: "Roles" }
    ],
    []
  );

  const overviewSection = (
    <>
      <section>
        <h2>Project Access Overview</h2>
        <p className="section-subtitle">
          Row-level security governs what you can see. Counts only reflect data
          exposed to your current persona.
        </p>
        <DataTable
          columns={projectColumns}
          rows={projectSummaryView.data}
          loading={projectSummaryView.loading}
          error={projectSummaryView.error}
          emptyMessage="No projects visible."
        />
      </section>

      <section>
        <h2>Sample Overview</h2>
        <DataTable
          columns={sampleColumns}
          rows={sampleView.data}
          loading={sampleView.loading}
          error={sampleView.error}
          emptyMessage="No samples available for this persona."
          rowKey={(row) => row.id}
          getRowClassName={(row) =>
            row.id === focusedSampleId ? "table__row--active" : undefined
          }
        />
      </section>

      <section>
        <h2>Inventory Status</h2>
        <DataTable
          columns={inventoryColumns}
          rows={inventoryView.data}
          loading={inventoryView.loading}
          error={inventoryView.error}
          emptyMessage="No inventory items to display."
        />
      </section>
    </>
  );

  const samplesSection = (
    <div
      ref={samplesSectionRef}
      tabIndex={-1}
      className="app__route-focus"
      aria-labelledby="samples-heading"
    >
      <section>
        <h2 id="samples-heading">Sample Provenance Explorer</h2>
        <p className="section-subtitle">
          Traverse sample lineage and jump straight to labware holding each
          material.
        </p>
        <SampleProvenanceExplorer
          samples={sampleView.data}
          lineage={sampleLineageView.data}
          labwareInventory={labwareInventoryView.data}
          handovers={handoverOverviewView.data}
          loading={
            sampleView.loading ||
            sampleLineageView.loading ||
            labwareInventoryView.loading ||
            handoverOverviewView.loading
          }
          error={
            sampleView.error ??
            sampleLineageView.error ??
            labwareInventoryView.error ??
            handoverOverviewView.error
          }
          onSelectLabware={handleLabwareSelectionWithNavigation}
          selectedLabwareId={focusedLabwareId}
          focusedSampleId={focusedSampleId}
          onSampleFocusChange={handleSampleFocus}
        />
      </section>
    </div>
  );

  const storageSection = (
    <div
      ref={storageSectionRef}
      tabIndex={-1}
      className="app__route-focus"
      aria-labelledby="storage-heading"
    >
      <section>
        <h2>Labware Contents</h2>
        <DataTable
          columns={labwareColumns}
          rows={labwareView.data}
          loading={labwareView.loading}
          error={labwareView.error}
          emptyMessage="No labware records visible."
          onRowClick={(row) => handleLabwareSelectionWithNavigation(row.labware_id)}
          rowKey={(row) => row.labware_id}
          getRowClassName={(row) =>
            row.labware_id === focusedLabwareId ? "table__row--active" : undefined
          }
        />
      </section>

      <section>
        <h2 id="storage-heading">Labware &amp; Storage Explorer</h2>
        <p className="section-subtitle">
          Inspect storage hierarchy, locate labware, and review active sample
          assignments.
        </p>
        <StorageExplorer
          storageTree={storageTreeView.data}
          labwareInventory={labwareInventoryView.data}
          loading={storageTreeView.loading || labwareInventoryView.loading}
          error={storageTreeView.error ?? labwareInventoryView.error}
          onSelectLabware={handleLabwareSelection}
          selectedLabwareId={focusedLabwareId}
          onSelectSample={handleSampleFocusWithNavigation}
          availableSampleIds={availableSampleIds}
        />
      </section>
    </div>
  );

  const securitySection = (
    <section>
      <h2>Security Monitoring</h2>
      <p className="section-subtitle">
        Transaction contexts and recent audit entries surface here for quick
        checks during development. Only administrators can see this data.
      </p>
      <div className="grid grid--two">
        <div>
          <h3>Transaction Context Activity</h3>
          <DataTable
            columns={txnActivityColumns}
            rows={txnActivityView.data}
            loading={txnActivityView.loading}
            error={txnActivityView.error}
            emptyMessage="No context records yet."
          />
        </div>
        <div>
          <h3>Recent Audit Events</h3>
          <DataTable
            columns={auditActivityColumns}
            rows={auditActivityView.data}
            loading={auditActivityView.loading}
            error={auditActivityView.error}
            emptyMessage="No audit activity recorded."
          />
        </div>
      </div>
    </section>
  );

  const usersSection = (
    <section>
      <h2>Users</h2>
      <DataTable
        columns={userColumns}
        rows={usersView.data}
        loading={usersView.loading}
        error={usersView.error}
        emptyMessage="No user records visible."
      />
    </section>
  );

  const showSecurityMonitoring = activeRoles.includes("app_admin");

  const sections: SectionDefinition[] = [
    { path: "/overview", label: "Overview", element: overviewSection },
    {
      path: "/eln",
      label: "ELN",
      element: (
        <NotebookWorkbench
          token={token}
          apiBase={API_BASE}
        />
      )
    },
    {
      path: "/eln/embed-test",
      label: "ELN Demo",
      element: <NotebookIframeDemo />
    },
    { path: "/samples", label: "Samples", element: samplesSection },
    {
      path: "/transfers",
      label: "Transfers",
      element: (
        <section>
          <h2>Scope Transfers</h2>
          <p className="section-subtitle">
            All scope-to-scope handovers visible to the current persona
          </p>
          <DataTable
            rows={scopeTransferView.data}
            columns={scopeTransferColumns}
            loading={scopeTransferView.loading}
            error={scopeTransferView.error}
            emptyMessage="No transfers visible for this persona."
          />
        </section>
      )
    },
    { path: "/storage", label: "Storage", element: storageSection },
    ...(showSecurityMonitoring
      ? [{ path: "/activity", label: "Security", element: securitySection }]
      : []),
    { path: "/users", label: "Users", element: usersSection }
  ];

  const defaultPath = sections[0]?.path ?? "/overview";

  return (
    <div className="app">
      <header className="app__header">
        <div className="app__header-content">
          <h1>CrazyLIMS – Operations Console</h1>
          {persona && (
            <div className="session-info">
              {displayName && (
                <span>
                  Signed in as <strong>{displayName}</strong>
                </span>
              )}
              {personaLabel && (
                <span>
                  Persona: {personaLabel}
                </span>
              )}
              {!!activeRoles.length && (
                <span>
                  Active roles: {activeRoles.join(", ")}
                </span>
              )}
            </div>
          )}
        </div>
        <PersonaSelector
          personas={personaLabels}
          selected={persona}
          onSelect={setPersona}
        />
      </header>

      {!persona ? (
        <main className="app__main app__main--empty">
          <div className="placeholder">Select a persona to begin</div>
        </main>
      ) : (
        <div className="app__layout">
          <nav className="app__sidebar" aria-label="Sections">
            <div className="app__sidebar-header">
              <span className="app__sidebar-title">Sections</span>
            </div>
            <ul className="app__nav-list">
              {sections.map((section) => (
                <li key={section.path}>
                  <NavLink
                    to={section.path}
                    end
                    className={({ isActive }) =>
                      "app__nav-link" + (isActive ? " app__nav-link--active" : "")
                    }
                  >
                    {section.label}
                  </NavLink>
                </li>
              ))}
            </ul>
          </nav>
          <main className="app__main">
            <Routes>
              <Route
                path="/"
                element={<Navigate to={defaultPath} replace />}
              />
              {sections.map((section) => (
                <Route
                  key={section.path}
                  path={section.path}
                  element={section.element}
                />
              ))}
              <Route
                path="*"
                element={<Navigate to={defaultPath} replace />}
              />
            </Routes>
          </main>
        </div>
      )}
    </div>
  );
}
