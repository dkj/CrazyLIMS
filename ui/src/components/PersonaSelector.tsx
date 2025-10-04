import { useEffect, useState } from "react";

interface PersonaSelectorProps {
  personas: Record<string, string>;
  selected: string | null;
  onSelect: (persona: string | null) => void;
}

export const PersonaSelector = ({ personas, selected, onSelect }: PersonaSelectorProps) => {
  const [available, setAvailable] = useState<string[]>([]);

  useEffect(() => {
    // Determine which persona tokens are present in /tokens
    const entries = Object.entries(personas);
    Promise.all(
      entries.map(async ([key]) => {
        try {
          const res = await fetch(`/tokens/${key}.jwt`, { method: "HEAD" });
          return res.ok ? key : null;
        } catch (err) {
          console.warn(`Token for persona ${key} unavailable`, err);
          return null;
        }
      })
    ).then((results) => {
      const present = results.filter((r): r is string => r !== null);
      setAvailable(present.length ? present : Object.keys(personas));
    });
  }, [personas]);

  const handleChange = (evt: React.ChangeEvent<HTMLSelectElement>) => {
    const value = evt.target.value;
    onSelect(value === "" ? null : value);
  };

  return (
    <div className="persona-selector">
      <label htmlFor="persona">Persona</label>
      <select id="persona" value={selected ?? ""} onChange={handleChange}>
        <option value="">Select…</option>
        {available.map((key) => (
          <option key={key} value={key}>
            {personas[key]}
          </option>
        ))}
      </select>
    </div>
  );
};
