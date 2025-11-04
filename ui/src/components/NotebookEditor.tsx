import { useCallback, useMemo, useState } from "react";
import type { NotebookDocument, NotebookOutput } from "../types";

declare global {
  interface Window {
    loadPyodide?: (options: { indexURL: string }) => Promise<any>;
    __pyodidePromise?: Promise<any>;
  }
}

type NotebookEditorProps = {
  notebook: NotebookDocument;
  onChange: (doc: NotebookDocument) => void;
  onDirtyChange: (dirty: boolean) => void;
  readOnly: boolean;
  pyodideIndexUrl: string;
};

type PyodideState = "idle" | "loading" | "ready" | "error";

function cloneNotebook(doc: NotebookDocument): NotebookDocument {
  return JSON.parse(JSON.stringify(doc));
}

function sourceToText(source: string[]): string {
  return source.join("");
}

function textToSource(text: string): string[] {
  const normalized = text.replace(/\r\n/g, "\n");
  const lines = normalized.split("\n");
  return lines.map((line, index) =>
    index < lines.length - 1 ? `${line}\n` : line
  );
}

export function NotebookEditor({
  notebook,
  onChange,
  onDirtyChange,
  readOnly,
  pyodideIndexUrl
}: NotebookEditorProps) {
  const [pyodideState, setPyodideState] = useState<PyodideState>("idle");
  const [pyodideError, setPyodideError] = useState<string | null>(null);
  const [runningCellIndex, setRunningCellIndex] = useState<number | null>(null);

  const codeCellCount = useMemo(
    () => notebook.cells.filter((cell) => cell.cell_type === "code").length,
    [notebook.cells]
  );

  const ensurePyodide = useCallback(async () => {
    if (!window.__pyodidePromise) {
      if (typeof window.loadPyodide === "function") {
        setPyodideState("loading");
        window.__pyodidePromise = window
          .loadPyodide({ indexURL: pyodideIndexUrl })
          .then((instance) => {
            setPyodideState("ready");
            return instance;
          })
          .catch((error) => {
            console.error(error);
            setPyodideState("error");
            setPyodideError(
              error instanceof Error ? error.message : "Failed to initialise Pyodide"
            );
            window.__pyodidePromise = undefined;
            throw error;
          });
      } else {
        setPyodideState("loading");
        window.__pyodidePromise = new Promise((resolve, reject) => {
          const script = document.createElement("script");
          script.src = `${pyodideIndexUrl}pyodide.js`;
          script.async = true;
          script.onload = () => {
            if (typeof window.loadPyodide !== "function") {
              reject(new Error("Pyodide runtime failed to expose loadPyodide"));
              return;
            }
            window
              .loadPyodide({ indexURL: pyodideIndexUrl })
              .then((instance) => {
                setPyodideState("ready");
                resolve(instance);
              })
              .catch((error) => {
                reject(error);
              });
          };
          script.onerror = () => {
            reject(new Error("Failed to load Pyodide runtime"));
          };
          document.body.appendChild(script);
        })
          .then((instance) => {
            return instance;
          })
          .catch((error) => {
            console.error(error);
            setPyodideState("error");
            setPyodideError(
              error instanceof Error ? error.message : "Failed to initialise Pyodide"
            );
            window.__pyodidePromise = undefined;
            throw error;
          });
      }
    }

    try {
      const pyodide = await window.__pyodidePromise!;
      setPyodideState("ready");
      setPyodideError(null);
      return pyodide;
    } catch (error) {
      throw error;
    }
  }, [pyodideIndexUrl]);

  const updateNotebook = useCallback(
    (updater: (doc: NotebookDocument) => void) => {
      const clone = cloneNotebook(notebook);
      updater(clone);
      onChange(clone);
      onDirtyChange(true);
    },
    [notebook, onChange, onDirtyChange]
  );

  const handleRunCell = async (index: number) => {
    setRunningCellIndex(index);
    try {
      const pyodide = await ensurePyodide();
      const cell = notebook.cells[index];
      if (!cell || cell.cell_type !== "code") {
        return;
      }

      let stdout = "";
      let stderr = "";
      const previousStdout = pyodide.setStdout
        ? pyodide.setStdout({
            batched: (text: string) => {
              stdout += text;
            }
          })
        : undefined;
      const previousStderr = pyodide.setStderr
        ? pyodide.setStderr({
            batched: (text: string) => {
              stderr += text;
            }
          })
        : undefined;

      try {
        await pyodide.runPythonAsync(sourceToText(cell.source));
        updateNotebook((doc) => {
          const target = doc.cells[index];
          if (target && target.cell_type === "code") {
            const outputs: NotebookOutput[] = [];
            const trimmedStdout = stdout.trimEnd();
            const trimmedStderr = stderr.trimEnd();
            if (trimmedStdout) {
              outputs.push({
                output_type: "stream",
                name: "stdout",
                text: trimmedStdout
              });
            }
            if (trimmedStderr) {
              outputs.push({
                output_type: "stream",
                name: "stderr",
                text: trimmedStderr
              });
            }
            if (outputs.length === 0) {
              outputs.push({
                output_type: "stream",
                name: "stdout",
                text: "Execution completed without output."
              });
            }
            target.outputs = outputs;
            target.execution_count = (target.execution_count ?? 0) + 1;
          }
        });
      } catch (error) {
        const message =
          error instanceof Error
            ? error.message
            : "An error occurred while executing the cell";
        updateNotebook((doc) => {
          const target = doc.cells[index];
          if (target && target.cell_type === "code") {
            target.outputs = [
              {
                output_type: "error",
                ename: "Error",
                evalue: message,
                text: [message]
              }
            ];
            target.execution_count = (target.execution_count ?? 0) + 1;
          }
        });
      } finally {
        if (pyodide.setStdout) {
          pyodide.setStdout(previousStdout || undefined);
        }
        if (pyodide.setStderr) {
          pyodide.setStderr(previousStderr || undefined);
        }
      }
    } catch (error) {
      console.error(error);
    } finally {
      setRunningCellIndex(null);
    }
  };

  const handleClearOutputs = (index: number) => {
    updateNotebook((doc) => {
      const cell = doc.cells[index];
      if (cell && cell.cell_type === "code") {
        cell.outputs = [];
      }
    });
  };

  const handleCellSourceChange = (index: number, text: string) => {
    updateNotebook((doc) => {
      const cell = doc.cells[index];
      if (cell) {
        cell.source = textToSource(text);
      }
    });
  };

  const handleDeleteCell = (index: number) => {
    updateNotebook((doc) => {
      doc.cells.splice(index, 1);
    });
  };

  const handleAddCell = (cellType: "markdown" | "code") => {
    updateNotebook((doc) => {
      if (cellType === "markdown") {
        doc.cells.push({
          cell_type: "markdown",
          metadata: {},
          source: ["New markdown cell\n"]
        });
      } else {
        doc.cells.push({
          cell_type: "code",
          metadata: {},
          source: ["# write python here\n"],
          execution_count: null,
          outputs: []
        });
      }
    });
  };

  return (
    <div className="notebook-editor">
      <div className="notebook-editor__toolbar">
        <div className="notebook-editor__summary">
          <span>{notebook.cells.length} cells</span>
          <span>{codeCellCount} code</span>
        </div>
        <div className="notebook-editor__actions">
          <button
            type="button"
            className="button button--secondary"
            onClick={() => handleAddCell("markdown")}
            disabled={readOnly}
          >
            Add Markdown
          </button>
          <button
            type="button"
            className="button button--secondary"
            onClick={() => handleAddCell("code")}
            disabled={readOnly}
          >
            Add Code
          </button>
        </div>
      </div>

      {pyodideState === "error" && pyodideError && (
        <div className="notebook-editor__banner notebook-editor__banner--error">
          {pyodideError}
        </div>
      )}

      {pyodideState === "loading" && (
        <div className="notebook-editor__banner">Loading Python runtime…</div>
      )}

      {notebook.cells.map((cell, index) => (
        <div
          key={index}
          className={
            "notebook-editor__cell" +
            (cell.cell_type === "code" ? " notebook-editor__cell--code" : "")
          }
        >
          <header className="notebook-editor__cell-header">
            <span className="notebook-editor__cell-type">
              {cell.cell_type === "code" ? "Code" : "Markdown"}
            </span>
            <div className="notebook-editor__cell-actions">
              {cell.cell_type === "code" && (
                <>
                  <button
                    type="button"
                    className="button button--secondary"
                    onClick={() => handleRunCell(index)}
                    disabled={readOnly || runningCellIndex === index}
                  >
                    {runningCellIndex === index ? "Running…" : "Run Cell"}
                  </button>
                  <button
                    type="button"
                    className="button button--tertiary"
                    onClick={() => handleClearOutputs(index)}
                    disabled={readOnly}
                  >
                    Clear Output
                  </button>
                </>
              )}
              <button
                type="button"
                className="button button--tertiary"
                onClick={() => handleDeleteCell(index)}
                disabled={readOnly}
              >
                Delete
              </button>
            </div>
          </header>
          <textarea
            className="notebook-editor__textarea"
            value={sourceToText(cell.source)}
            onChange={(event) => handleCellSourceChange(index, event.target.value)}
            rows={cell.cell_type === "code" ? 8 : 6}
            readOnly={readOnly}
          />
          {cell.cell_type === "code" && cell.outputs && cell.outputs.length > 0 && (
            <div className="notebook-editor__outputs">
              {cell.outputs.map((output, outputIndex) => {
                const text = Array.isArray(output.text)
                  ? output.text.join("")
                  : output.text ?? "";
                const className =
                  "notebook-editor__output" +
                  (output.output_type === "error"
                    ? " notebook-editor__output--error"
                    : "");
                return (
                  <pre key={outputIndex} className={className}>
                    {text}
                  </pre>
                );
              })}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
