interface Column {
  key: string;
  label: string;
}

interface DataTableProps<Row> {
  columns: Column[];
  rows: Row[];
  loading?: boolean;
  error?: string | null;
  emptyMessage?: string;
}

export const DataTable = <Row extends Record<string, any>>({
  columns,
  rows,
  loading = false,
  error = null,
  emptyMessage = "No records found"
}: DataTableProps<Row>) => {
  if (error) {
    return <div className="table table--error">Error: {error}</div>;
  }

  if (loading) {
    return <div className="table table--loading">Loading…</div>;
  }

  if (!rows.length) {
    return <div className="table table--empty">{emptyMessage}</div>;
  }

  return (
    <div className="table-wrapper">
      <table className="table">
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column.key}>{column.label}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, idx) => (
            <tr key={idx}>
              {columns.map((column) => {
                const value = row[column.key];
                const display =
                  typeof value === "boolean"
                    ? value ? "Yes" : "No"
                    : value ?? "";
                return <td key={column.key}>{display}</td>;
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
