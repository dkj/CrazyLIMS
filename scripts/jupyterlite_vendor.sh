#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$REPO_ROOT/.cache/jupyterlite"
VENV_DIR="$CACHE_DIR/venv"
STAMP_FILE="$CACHE_DIR/vendor.stamp"
OUTPUT_DIR="$REPO_ROOT/ui/public/eln/lite"
CONTENTS_DIR="$REPO_ROOT/ui/jupyterlite-contents"

JUPYTERLITE_VERSION="0.6.4"
PYODIDE_KERNEL_VERSION="0.6.1"

mkdir -p "$CACHE_DIR" "$OUTPUT_DIR" "$CONTENTS_DIR"

if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

pip install --upgrade --quiet pip
pip install --quiet \
  "jupyterlite==$JUPYTERLITE_VERSION" \
  "jupyterlite-core==$JUPYTERLITE_VERSION" \
  "jupyterlite-pyodide-kernel==$PYODIDE_KERNEL_VERSION" \
  "jupyter-server>=2.14.1,<3"

echo "Building JupyterLite assets into $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"

jupyter lite build \
  --output-dir "$OUTPUT_DIR" \
  --contents "$CONTENTS_DIR" \
  --apps lab --apps notebook --apps repl \
  --base-url /eln/lite \
  --debug

# ensure window.jupyterapp is exposed for the iframe bridge
python3 - <<'PY' "$OUTPUT_DIR/jupyter-lite.json"
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

config = data.setdefault("jupyter-config-data", {})
config["exposeAppInBrowser"] = True

with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY

date +%s >"$STAMP_FILE"

echo "JupyterLite assets refreshed."
