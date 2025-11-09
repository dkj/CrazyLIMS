import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type FormEvent
} from "react";
import type {
  AccessibleScopeRow,
  NotebookDocument,
  NotebookEntryOverview,
  NotebookVersionRow
} from "../types";

type NotebookWorkbenchProps = {
  token?: string;
  apiBase: string;
};

const STATUS_LABELS: Record<string, string> = {
  draft: "Draft",
  submitted: "Submitted",
  locked: "Locked"
};

const JUPYTERLITE_BASE_PATH = "/eln/lite";

function createInitialNotebook(): NotebookDocument {
  return {
    cells: [
      {
        cell_type: "markdown",
        metadata: {},
        source: ["# New ELN Entry\n", "\n", "Describe your experiment here.\n"]
      },
      {
        cell_type: "code",
        metadata: {},
        source: ['print("Hello from CrazyLIMS ELN")\n'],
        execution_count: null,
        outputs: []
      }
    ],
    metadata: {
      kernelspec: {
        display_name: "Python 3 (Pyodide)",
        language: "python",
        name: "python3"
      },
      language_info: {
        name: "python",
        version: "3.11"
      }
    },
    nbformat: 4,
    nbformat_minor: 5
  };
}

function cloneNotebook(doc: NotebookDocument): NotebookDocument {
  return JSON.parse(JSON.stringify(doc));
}

export function NotebookWorkbench({ token, apiBase }: NotebookWorkbenchProps) {
  const [scopes, setScopes] = useState<AccessibleScopeRow[]>([]);
  const [scopeError, setScopeError] = useState<string | null>(null);
  const [entries, setEntries] = useState<NotebookEntryOverview[]>([]);
  const [entriesLoading, setEntriesLoading] = useState(false);
  const [entriesError, setEntriesError] = useState<string | null>(null);
  const [selectedEntryId, setSelectedEntryId] = useState<string | null>(null);
  const [versions, setVersions] = useState<NotebookVersionRow[]>([]);
  const [versionsLoading, setVersionsLoading] = useState(false);
  const [versionError, setVersionError] = useState<string | null>(null);
  const [activeVersionNumber, setActiveVersionNumber] = useState<number | null>(null);
  const [currentNotebook, setCurrentNotebook] = useState<NotebookDocument | null>(null);
  const [actionMessage, setActionMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [newEntryTitle, setNewEntryTitle] = useState("");
  const [newEntryDescription, setNewEntryDescription] = useState("");
  const [newEntryScopeId, setNewEntryScopeId] = useState<string | null>(null);
  const [viewerReady, setViewerReady] = useState(false);
  const [viewerError, setViewerError] = useState<string | null>(null);
  const [viewerLoading, setViewerLoading] = useState(false);
  const viewerIframeRef = useRef<HTMLIFrameElement | null>(null);
  const pendingNotebookRef = useRef<{
    entryId: string;
    versionNumber: number;
    document: NotebookDocument;
  } | null>(null);

  const viewerSrc = "/eln/viewer.html";

  const datasetScopes = useMemo(
    () =>
      scopes.filter(
        (scope) => scope.scope_type && scope.scope_type.toLowerCase() === "dataset"
      ),
    [scopes]
  );
  const projectScopes = useMemo(
    () =>
      scopes.filter(
        (scope) => scope.scope_type && scope.scope_type.toLowerCase() === "project"
      ),
    [scopes]
  );
  const availableScopes = useMemo(
    () => [...datasetScopes, ...projectScopes],
    [datasetScopes, projectScopes]
  );
  const preferredScopes = useMemo(
    () => (datasetScopes.length > 0 ? datasetScopes : projectScopes),
    [datasetScopes, projectScopes]
  );
  const selectedEntry = useMemo(
    () => entries.find((entry) => entry.entry_id === selectedEntryId) ?? null,
    [entries, selectedEntryId]
  );

  const authHeaders = useCallback(
    (headers?: HeadersInit) => {
      const enriched = new Headers(headers);
      if (token) {
        enriched.set("Authorization", `Bearer ${token}`);
      }
      if (!enriched.has("Accept")) {
        enriched.set("Accept", "application/json");
      }
      return enriched;
    },
    [token]
  );

  const loadScopes = useCallback(async () => {
    if (!token) {
      setScopes([]);
      setScopeError(null);
      return;
    }

    try {
      const response = await fetch(`${apiBase}/rpc/actor_accessible_scopes`, {
        method: "POST",
        headers: authHeaders({
          "Content-Type": "application/json"
        }),
        body: JSON.stringify({ p_scope_types: ["dataset", "project"] })
      });

      if (!response.ok) {
        throw new Error(await response.text());
      }

      const payload = (await response.json()) as AccessibleScopeRow[];
      setScopes(payload);
      setScopeError(null);
    } catch (error) {
      console.error(error);
      const message =
        error instanceof Error ? error.message : "Failed to load accessible scopes";
      setScopeError(message);
      setScopes([]);
    }
  }, [apiBase, authHeaders, token]);

  const loadEntries = useCallback(async () => {
    if (!token) {
      setEntries([]);
      setEntriesError(null);
      return;
    }

    setEntriesLoading(true);
    setEntriesError(null);
    try {
      const response = await fetch(
        `${apiBase}/v_notebook_entry_overview?order=updated_at.desc`,
        {
          headers: authHeaders()
        }
      );

      if (!response.ok) {
        throw new Error(await response.text());
      }

      const payload = (await response.json()) as NotebookEntryOverview[];
      setEntries(payload);
      setEntriesError(null);

      if (payload.length > 0) {
        setSelectedEntryId((current) => current ?? payload[0].entry_id);
      } else {
        setSelectedEntryId(null);
      }
    } catch (error) {
      console.error(error);
      const message =
        error instanceof Error ? error.message : "Failed to load notebook entries";
      setEntriesError(message);
      setEntries([]);
    } finally {
      setEntriesLoading(false);
    }
  }, [apiBase, authHeaders, token]);

  const loadVersions = useCallback(
    async (entryId: string | null) => {
      if (!token || !entryId) {
        setVersions([]);
        setCurrentNotebook(null);
        setActiveVersionNumber(null);
        setVersionError(null);
        return;
      }

      setVersionsLoading(true);
      setVersionError(null);
      try {
        const response = await fetch(
          `${apiBase}/notebook_entry_versions?entry_id=eq.${entryId}&order=version_number.desc`,
          {
            headers: authHeaders()
          }
        );

        if (!response.ok) {
          throw new Error(await response.text());
        }

        const payload = (await response.json()) as NotebookVersionRow[];
        setVersions(payload);
        setVersionError(null);

        if (payload.length > 0) {
          setActiveVersionNumber(payload[0].version_number);
          setCurrentNotebook(cloneNotebook(payload[0].notebook_json));
        } else {
          setActiveVersionNumber(null);
          setCurrentNotebook(null);
        }
      } catch (error) {
        console.error(error);
        const message =
          error instanceof Error ? error.message : "Failed to load notebook versions";
        setVersionError(message);
        setVersions([]);
        setCurrentNotebook(null);
        setActiveVersionNumber(null);
      } finally {
        setVersionsLoading(false);
      }
    },
    [apiBase, authHeaders, token]
  );

  const postNotebookToViewer = useCallback(() => {
    if (!pendingNotebookRef.current) {
      return;
    }
    const iframeWindow = viewerIframeRef.current?.contentWindow;
    if (!iframeWindow) {
      return;
    }
    const payload = pendingNotebookRef.current;
    iframeWindow.postMessage(
      {
        type: "eln-open-notebook",
        entryId: payload.entryId,
        versionNumber: payload.versionNumber,
        content: payload.document
      },
      window.location.origin
    );
    pendingNotebookRef.current = null;
  }, []);

  const publishNotebookToLite = useCallback(
    (doc: NotebookDocument, entryId: string, versionNumber: number) => {
      setViewerLoading(true);
      setViewerError(null);
      pendingNotebookRef.current = { entryId, versionNumber, document: doc };
      if (viewerReady) {
        postNotebookToViewer();
      }
    },
    [postNotebookToViewer, viewerReady]
  );

  useEffect(() => {
    loadScopes();
  }, [loadScopes]);

  useEffect(() => {
    loadEntries();
  }, [loadEntries]);

  useEffect(() => {
    loadVersions(selectedEntryId);
  }, [loadVersions, selectedEntryId]);

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin) {
        return;
      }
      const data = event.data;
      if (!data || typeof data !== "object") {
        return;
      }
      if (data.type === "eln-lite-ready") {
        setViewerReady(true);
        if (pendingNotebookRef.current) {
          postNotebookToViewer();
        }
        return;
      }

      if (data.type === "eln-lite-opened") {
        setViewerLoading(false);
        setViewerError(null);
        return;
      }

      if (data.type === "eln-lite-error") {
        setViewerLoading(false);
        setViewerError(
          data.message ?? "Failed to load notebook in JupyterLite iframe."
        );
        return;
      }
    };

    window.addEventListener("message", handleMessage);
    return () => window.removeEventListener("message", handleMessage);
  }, [postNotebookToViewer]);

  useEffect(() => {
    if (selectedEntryId && currentNotebook && activeVersionNumber !== null) {
      publishNotebookToLite(currentNotebook, selectedEntryId, activeVersionNumber);
    } else {
      pendingNotebookRef.current = null;
      setViewerError(null);
      setViewerLoading(false);
    }
  }, [selectedEntryId, currentNotebook, activeVersionNumber, publishNotebookToLite]);

  useEffect(() => {
    if (viewerReady) {
      postNotebookToViewer();
    }
  }, [viewerReady, postNotebookToViewer]);

  useEffect(() => {
    if (availableScopes.length === 0) {
      if (newEntryScopeId !== null) {
        setNewEntryScopeId(null);
      }
      return;
    }

    const hasCurrentSelection =
      newEntryScopeId !== null &&
      availableScopes.some((scope) => scope.scope_id === newEntryScopeId);

    if (!hasCurrentSelection) {
      const fallbackScope = preferredScopes[0] ?? availableScopes[0];
      if (fallbackScope) {
        setNewEntryScopeId(fallbackScope.scope_id);
      }
    }
  }, [availableScopes, preferredScopes, newEntryScopeId]);

  const handleSelectEntry = (entryId: string) => {
    if (entryId !== selectedEntryId) {
      setSelectedEntryId(entryId);
      setActionMessage(null);
      setActionError(null);
    }
  };

  const handleCreateEntry = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!token || !newEntryScopeId) {
      return;
    }

    setCreating(true);
    setActionMessage(null);
    setActionError(null);
    try {
      const response = await fetch(`${apiBase}/notebook_entries`, {
        method: "POST",
        headers: authHeaders({
          "Content-Type": "application/json",
          Prefer: "return=representation"
        }),
        body: JSON.stringify({
          title: newEntryTitle.trim() || "Untitled Notebook",
          description: newEntryDescription.trim() || null,
          primary_scope_id: newEntryScopeId,
          metadata: {}
        })
      });

      if (!response.ok) {
        throw new Error(await response.text());
      }

      const inserted = (await response.json()) as Array<{ entry_id: string }>;
      const entryId = inserted[0]?.entry_id;
      if (!entryId) {
        throw new Error("Notebook entry creation did not return an identifier");
      }

      const initialDoc = createInitialNotebook();
      const versionResponse = await fetch(`${apiBase}/notebook_entry_versions`, {
        method: "POST",
        headers: authHeaders({
          "Content-Type": "application/json",
          Prefer: "return=representation"
        }),
        body: JSON.stringify({
          entry_id: entryId,
          note: "Initial capture",
          notebook_json: initialDoc
        })
      });

      if (!versionResponse.ok) {
        throw new Error(await versionResponse.text());
      }

      setNewEntryTitle("");
      setNewEntryDescription("");
      setActionMessage("Notebook entry created");

      await loadEntries();
      setSelectedEntryId(entryId);
      await loadVersions(entryId);
    } catch (error) {
      console.error(error);
      const message =
        error instanceof Error ? error.message : "Failed to create notebook entry";
      setActionError(message);
    } finally {
      setCreating(false);
    }
  };

  const handleSelectVersion = (version: NotebookVersionRow) => {
    setActiveVersionNumber(version.version_number);
    setCurrentNotebook(cloneNotebook(version.notebook_json));
    setActionMessage(null);
    setActionError(null);
  };

  const updateStatus = async (status: "draft" | "submitted" | "locked") => {
    if (!token || !selectedEntryId) {
      return;
    }

    setUpdatingStatus(true);
    setActionMessage(null);
    setActionError(null);
    try {
      const response = await fetch(
        `${apiBase}/notebook_entries?entry_id=eq.${selectedEntryId}`,
        {
          method: "PATCH",
          headers: authHeaders({
            "Content-Type": "application/json",
            Prefer: "return=representation"
          }),
          body: JSON.stringify({ status })
        }
      );

      if (!response.ok) {
        throw new Error(await response.text());
      }

      setActionMessage(`Notebook status updated to ${STATUS_LABELS[status] ?? status}`);
      await loadEntries();
      await loadVersions(selectedEntryId);
    } catch (error) {
      console.error(error);
      const message =
        error instanceof Error ? error.message : "Failed to update notebook status";
      setActionError(message);
    } finally {
      setUpdatingStatus(false);
    }
  };

  if (!token) {
    return (
      <div className="notebook-workbench__placeholder">
        Select a persona to work with notebook entries.
      </div>
    );
  }

  return (
    <div className="notebook-workbench">
      <aside className="notebook-workbench__sidebar">
        <section>
          <h3>Create Notebook</h3>
          <form className="notebook-workbench__form" onSubmit={handleCreateEntry}>
            <label className="notebook-workbench__label" htmlFor="notebook-form-title">
              Title
              <input
                id="notebook-form-title"
                className="notebook-workbench__input"
                type="text"
                value={newEntryTitle}
                onChange={(event) => setNewEntryTitle(event.target.value)}
                placeholder="Notebook title"
              />
            </label>
            <label className="notebook-workbench__label" htmlFor="notebook-form-description">
              Description
              <textarea
                id="notebook-form-description"
                className="notebook-workbench__textarea"
                rows={3}
                value={newEntryDescription}
                onChange={(event) => setNewEntryDescription(event.target.value)}
                placeholder="Optional description"
              />
            </label>
            <label className="notebook-workbench__label" htmlFor="notebook-form-scope">
              Scope
              <select
                id="notebook-form-scope"
                className="notebook-workbench__select"
                value={newEntryScopeId ?? ""}
                disabled={availableScopes.length === 0}
                onChange={(event) => setNewEntryScopeId(event.target.value)}
                required
              >
                <option value="" disabled>
                  Select a project or dataset
                </option>
                {datasetScopes.length > 0 && (
                  <optgroup label="Datasets">
                    {datasetScopes.map((scope) => (
                      <option key={scope.scope_id} value={scope.scope_id}>
                        {scope.display_name} ({scope.scope_key})
                      </option>
                    ))}
                  </optgroup>
                )}
                {projectScopes.length > 0 && (
                  <optgroup label="Projects">
                    {projectScopes.map((scope) => (
                      <option key={scope.scope_id} value={scope.scope_id}>
                        {scope.display_name} ({scope.scope_key})
                      </option>
                    ))}
                  </optgroup>
                )}
              </select>
            </label>
            {scopeError && (
              <p className="notebook-workbench__error">{scopeError}</p>
            )}
            <button
              className="button"
              type="submit"
              disabled={creating || !newEntryScopeId}
            >
              {creating ? "Creating…" : "Create Notebook"}
            </button>
          </form>
        </section>

        <section className="notebook-workbench__entries">
          <h3>Notebook Entries</h3>
          {entriesLoading && <div className="notebook-workbench__loading">Loading…</div>}
          {entriesError && (
            <p className="notebook-workbench__error">{entriesError}</p>
          )}
          {!entriesLoading && !entriesError && entries.length === 0 && (
            <p className="notebook-workbench__empty">No notebook entries available.</p>
          )}
          <ul className="notebook-entry-list">
            {entries.map((entry) => (
              <li key={entry.entry_id}>
                <button
                  type="button"
                  className={
                    "notebook-entry-list__button" +
                    (entry.entry_id === selectedEntryId
                      ? " notebook-entry-list__button--active"
                      : "")
                  }
                  onClick={() => handleSelectEntry(entry.entry_id)}
                >
                  <span className="notebook-entry-list__title">{entry.title}</span>
                  <span className={`notebook-entry-list__status status-${entry.status}`}>
                    {STATUS_LABELS[entry.status] ?? entry.status}
                  </span>
                  <span className="notebook-entry-list__meta">
                    {entry.latest_version
                      ? `v${entry.latest_version}`
                      : "No versions yet"}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </section>
      </aside>

      <section className="notebook-workbench__main">
        {!selectedEntry && (
          <div className="notebook-workbench__placeholder">
            Select or create a notebook entry to begin.
          </div>
        )}

        {selectedEntry && (
          <>
            <header className="notebook-workbench__header">
              <div>
                <h2>{selectedEntry.title}</h2>
                <p className="notebook-workbench__subheading">
                  Scope: {selectedEntry.primary_scope_name ?? selectedEntry.primary_scope_key}
                </p>
              </div>
              <div className="notebook-workbench__actions">
                <span className={`status-pill status-pill--${selectedEntry.status}`}>
                  {STATUS_LABELS[selectedEntry.status] ?? selectedEntry.status}
                </span>
                <button
                  type="button"
                  className="button button--secondary"
                  onClick={() => updateStatus("draft")}
                  disabled={
                    updatingStatus ||
                    selectedEntry.status === "draft"
                  }
                >
                  Re-open Draft
                </button>
                <button
                  type="button"
                  className="button button--secondary"
                  onClick={() => updateStatus("submitted")}
                  disabled={
                    updatingStatus ||
                    selectedEntry.status !== "draft"
                  }
                >
                  Submit for Review
                </button>
                <button
                  type="button"
                  className="button button--secondary"
                  onClick={() => updateStatus("locked")}
                  disabled={
                    updatingStatus ||
                    selectedEntry.status !== "submitted"
                  }
                >
                  Lock Entry
                </button>
              </div>
            </header>

            {(actionMessage || actionError) && (
              <div
                className={
                  "notebook-workbench__banner" +
                  (actionError ? " notebook-workbench__banner--error" : "")
                }
              >
                {actionError ?? actionMessage}
              </div>
            )}

            <div className="notebook-workbench__content">
              <aside className="notebook-workbench__versions">
                <h3>Versions</h3>
                {versionsLoading && (
                  <div className="notebook-workbench__loading">Loading versions…</div>
                )}
                {versionError && (
                  <p className="notebook-workbench__error">{versionError}</p>
                )}
                {!versionsLoading && !versionError && versions.length === 0 && (
                  <p className="notebook-workbench__empty">No saved versions yet.</p>
                )}
                <ul className="notebook-version-list">
                  {versions.map((version) => (
                    <li key={version.version_id}>
                      <button
                        type="button"
                        className={
                          "notebook-version-list__button" +
                          (version.version_number === activeVersionNumber
                            ? " notebook-version-list__button--active"
                            : "")
                        }
                        onClick={() => handleSelectVersion(version)}
                      >
                        <span>v{version.version_number}</span>
                        <span className="notebook-version-list__timestamp">
                          {new Date(version.created_at).toLocaleString()}
                        </span>
                        {version.note && (
                          <span className="notebook-version-list__note">
                            {version.note}
                          </span>
                        )}
                      </button>
                    </li>
                  ))}
                </ul>
              </aside>

              <div className="notebook-workbench__viewer">
                {viewerError ? (
                  <p className="notebook-workbench__error notebook-workbench__error--inline">
                    {viewerError}
                  </p>
                ) : viewerLoading ? (
                  <div className="notebook-workbench__placeholder">
                    Preparing notebook in JupyterLite…
                  </div>
                ) : !viewerReady ? (
                  <div className="notebook-workbench__placeholder">
                    Loading embedded JupyterLite workspace…
                  </div>
                ) : !selectedEntry ? (
                  <div className="notebook-workbench__placeholder">
                    Select a version to view the notebook contents.
                  </div>
                ) : null}
                <iframe
                  title="JupyterLite notebook"
                  className="notebook-viewer__frame"
                  src={viewerSrc}
                  allow="clipboard-read; clipboard-write"
                  ref={viewerIframeRef}
                  data-testid="jupyterlite-frame"
                />
              </div>
            </div>
          </>
        )}
      </section>
    </div>
  );
}
