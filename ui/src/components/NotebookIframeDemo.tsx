export function NotebookIframeDemo() {
  return (
    <div className="notebook-demo">
      <h2>Notebook Lite Demo</h2>
      <p>
        This page embeds the locally vendored JupyterLite build (served from <code>/eln/lite</code>).
        If the Lab UI loads and you can launch a Pyodide kernel here, the ELN workbench will be able
        to stream notebooks into the same runtime.
      </p>
      <div className="notebook-demo__iframe">
        <iframe
          title="Notebook Lite Demo"
          className="notebook-viewer__frame"
          src="/eln/lite/lab/index.html?kernel=python"
          allow="clipboard-read; clipboard-write"
        />
      </div>
    </div>
  );
}
