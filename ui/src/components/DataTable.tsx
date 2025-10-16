import { useEffect, useMemo, useState } from "react";
import type { KeyboardEvent, ReactNode } from "react";

export interface Column<Row> {
  key: string;
  label: string;
  render?: (row: Row) => ReactNode;
}

interface DataTableProps<Row> {
  columns: Column<Row>[];
  rows: Row[];
  loading?: boolean;
  error?: string | null;
  emptyMessage?: string;
  pageSizeOptions?: number[];
  initialPageSize?: number;
  onRowClick?: (row: Row) => void;
  getRowClassName?: (row: Row) => string | undefined;
  rowKey?: (row: Row, index: number) => string | number;
}

export const DataTable = <Row extends Record<string, any>>({
  columns,
  rows,
  loading = false,
  error = null,
  emptyMessage = "No records found",
  pageSizeOptions = [10, 25, 50, 100],
  initialPageSize = 10,
  onRowClick,
  getRowClassName,
  rowKey
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

  const normalizedOptions = useMemo(() => {
    const options = new Set<number>();
    [...pageSizeOptions, initialPageSize]
      .filter((size): size is number => typeof size === "number" && size > 0)
      .forEach((size) => options.add(size));
    const sorted = Array.from(options).sort((a, b) => a - b);
    return sorted.length ? sorted : [25];
  }, [pageSizeOptions, initialPageSize]);

  const [pageSize, setPageSize] = useState(
    normalizedOptions.includes(initialPageSize)
      ? initialPageSize
      : normalizedOptions[0]
  );
  const [page, setPage] = useState(0);

  useEffect(() => {
    setPageSize((current) =>
      normalizedOptions.includes(current) ? current : normalizedOptions[0]
    );
  }, [normalizedOptions]);

  useEffect(() => {
    setPage(0);
  }, [rows.length, pageSize]);

  const pageCount = Math.max(1, Math.ceil(rows.length / pageSize));
  useEffect(() => {
    const maxPage = Math.max(0, pageCount - 1);
    if (page > maxPage) {
      setPage(maxPage);
    }
  }, [page, pageCount]);

  const displayedRows = useMemo(() => {
    const start = page * pageSize;
    const end = start + pageSize;
    return rows.slice(start, end);
  }, [rows, page, pageSize]);

  const rangeStart = rows.length ? page * pageSize + 1 : 0;
  const rangeEnd = rows.length
    ? Math.min(rows.length, page * pageSize + displayedRows.length)
    : 0;
  const shouldPaginate = rows.length > pageSize;

  const handleRowKeyDown = (event: KeyboardEvent<HTMLTableRowElement>, row: Row) => {
    if (!onRowClick) return;
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      onRowClick(row);
    }
  };

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
          {displayedRows.map((row, idx) => {
            const key = rowKey ? rowKey(row, idx + page * pageSize) : idx + page * pageSize;
            const isClickable = Boolean(onRowClick);
            const classNames = ["table__row"];
            if (isClickable) classNames.push("table__row--clickable");
            const extraClass = getRowClassName?.(row);
            if (extraClass) classNames.push(extraClass);
            return (
              <tr
                key={key}
                className={classNames.join(" ")}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                onKeyDown={(event) => handleRowKeyDown(event, row)}
                tabIndex={onRowClick ? 0 : undefined}
                role={onRowClick ? "button" : undefined}
              >
                {columns.map((column) => {
                  const value = column.render ? column.render(row) : row[column.key];
                  const display =
                    typeof value === "boolean"
                      ? value ? "Yes" : "No"
                      : value ?? "";
                  return <td key={column.key}>{display}</td>;
                })}
              </tr>
            );
          })}
        </tbody>
      </table>
      <div className="table__footer">
        <div className="table__footer-info">
          Showing {rangeStart}-{rangeEnd} of {rows.length}
        </div>
        <div className="table__pagination">
          <label className="table__page-size">
            Rows per page
            <select
              value={pageSize}
              onChange={(event) => {
                const next = Number(event.target.value);
                if (!Number.isNaN(next) && next > 0) {
                  setPageSize(next);
                  setPage(0);
                }
              }}
            >
              {normalizedOptions.map((size) => (
                <option key={size} value={size}>
                  {size}
                </option>
              ))}
            </select>
          </label>
          <div className="table__pager">
            <button
              type="button"
              onClick={() => setPage((current) => Math.max(current - 1, 0))}
              disabled={page === 0}
            >
              Previous
            </button>
            <span className="table__page-indicator">
              Page {page + 1} of {pageCount}
            </span>
            <button
              type="button"
              onClick={() =>
                setPage((current) => Math.min(current + 1, pageCount - 1))
              }
              disabled={!shouldPaginate || page >= pageCount - 1}
            >
              Next
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
