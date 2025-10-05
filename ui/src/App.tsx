import { useEffect, useMemo, useState } from "react";
import { PersonaSelector } from "./components/PersonaSelector";
import { DataTable } from "./components/DataTable";
import type {
  SampleOverviewRow,
  LabwareContentRow,
  InventoryStatusRow,
  UserRow
} from "./types";

const POSTGREST_URL: string = (globalThis as any).__POSTGREST_URL__;
const API_BASE = POSTGREST_URL.replace(/\/$/, "");

const personaLabels: Record<string, string> = {
  admin: "Administrator",
  operator: "Operator",
  researcher: "Researcher (Alice)",
  researcher_bob: "Researcher (Bob)"
};

const personaTokenPaths: Record<string, string> = {
  admin: "/tokens/admin.jwt",
  operator: "/tokens/operator.jwt",
  researcher: "/tokens/researcher.jwt",
  researcher_bob: "/tokens/researcher_bob.jwt"
};

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

export default function App() {
  const [persona, setPersona] = useState<string | null>(null);
  const token = usePersonaToken(persona);

  const sampleView = useGet<SampleOverviewRow>("/v_sample_overview", token);
  const labwareView = useGet<LabwareContentRow>("/v_labware_contents", token);
  const inventoryView = useGet<InventoryStatusRow>("/v_inventory_status", token);
  const usersView = useGet<UserRow>("/users", token);

  const sampleColumns = useMemo(
    () => [
      { key: "name", label: "Sample" },
      { key: "sample_type_code", label: "Type" },
      { key: "sample_status", label: "Status" },
      { key: "collected_at", label: "Collected" },
      { key: "current_labware_barcode", label: "Labware" },
      { key: "storage_path", label: "Storage Path" }
    ],
    []
  );

  const labwareColumns = useMemo(
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

  const inventoryColumns = useMemo(
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

  const userColumns = useMemo(
    () => [
      { key: "email", label: "Email" },
      { key: "full_name", label: "Name" },
      { key: "default_role", label: "Default Role" },
      { key: "is_service_account", label: "Service Account" }
    ],
    []
  );

  return (
    <div className="app">
      <header className="app__header">
        <h1>CrazyLIMS – Operations Console</h1>
        <PersonaSelector
          personas={personaLabels}
          selected={persona}
          onSelect={setPersona}
        />
      </header>

      <main className="app__content">
        {!persona && (
          <div className="placeholder">Select a persona to begin</div>
        )}

        {persona && (
          <>
            <section>
              <h2>Sample Overview</h2>
              <DataTable
                columns={sampleColumns}
                rows={sampleView.data}
                loading={sampleView.loading}
                error={sampleView.error}
                emptyMessage="No samples available for this persona."
              />
            </section>

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

            <section>
              <h2>Labware Contents</h2>
              <DataTable
                columns={labwareColumns}
                rows={labwareView.data}
                loading={labwareView.loading}
                error={labwareView.error}
                emptyMessage="No labware records visible."
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
        )}
      </main>
    </div>
  );
}
