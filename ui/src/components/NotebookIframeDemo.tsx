import { useEffect, useRef, useState } from "react";
import type { NotebookDocument } from "../types";

type NotebookIframeDemoProps = {
  token?: string;
  apiBase: string;
};

function createDemoNotebook(): NotebookDocument {
  return {
    cells: [
      {
        cell_type: "markdown",
        metadata: {},
        source: [
          "# Embedded JupyterLite Demo\n",
          "\n",
          "This Pyodide kernel is using the ELN's offline wheelhouse. The REST client should import without any extra setup.\n"
        ]
      },
      {
        cell_type: "code",
        metadata: {},
        source: [
          "from crazylims_postgrest_client.pyodide import build_authenticated_client\n",
          "client = build_authenticated_client()\n",
          "client\n"
        ],
        execution_count: null,
        outputs: []
      }
    ],
    metadata: {
      kernelspec: {
        display_name: "Python (Pyodide)",
        language: "python",
        name: "python"
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

export function NotebookIframeDemo({ token, apiBase }: NotebookIframeDemoProps) {
  const frameRef = useRef<HTMLIFrameElement | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const frame = frameRef.current;
    if (!frame) return;
    const handleMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin) return;
      const data = event.data;
      if (!data || typeof data !== "object") return;
      if (data.type === "eln-lite-ready") {
        setReady(true);
      }
    };
    window.addEventListener("message", handleMessage);
    return () => window.removeEventListener("message", handleMessage);
  }, []);

  useEffect(() => {
    const frame = frameRef.current;
    if (!frame?.contentWindow) return;
    if (!token) return;
    try {
      frame.contentWindow.postMessage(
        { type: "eln-auth-context", authToken: token, apiBase },
        window.location.origin
      );
    } catch (error) {
      console.warn("Unable to forward auth context to JupyterLite demo frame", error);
    }
  }, [token, apiBase]);

  useEffect(() => {
    const frame = frameRef.current;
    if (!frame?.contentWindow || !ready) return;
    const notebook = createDemoNotebook();
    try {
      frame.contentWindow.postMessage(
        {
          type: "eln-open-notebook",
          entryId: "demo-notebook",
          versionNumber: 1,
          content: notebook,
          authToken: token ?? null,
          apiBase
        },
        window.location.origin
      );
    } catch (error) {
      console.warn("Unable to open demo notebook in JupyterLite frame", error);
    }
  }, [ready, token, apiBase]);

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
          ref={frameRef}
          title="Notebook Lite Demo"
          className="notebook-viewer__frame"
          src="/eln/viewer.html"
          allow="clipboard-read; clipboard-write"
        />
      </div>
    </div>
  );
}
