#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$REPO_ROOT/.cache/jupyterlite"
VENV_DIR="$CACHE_DIR/venv"
STAMP_FILE="$CACHE_DIR/vendor.stamp"
OUTPUT_DIR="$REPO_ROOT/ui/public/eln/lite"
DIST_LITE_DIR="$REPO_ROOT/ui/dist/eln/lite"
CONTENTS_DIR="$REPO_ROOT/ui/jupyterlite-contents"
PY_CLIENT_DIR="$REPO_ROOT/ui/python-postgrest-client"
PIP_WHEEL_DIR="$OUTPUT_DIR/pypi"
PYODIDE_EXTRA_WHEELS=("comm==0.2.2")

JUPYTERLITE_VERSION="0.7.0"
PYODIDE_KERNEL_VERSION="0.7.0"
PYODIDE_VERSION="0.29.0"
PYODIDE_ARCHIVE="pyodide-${PYODIDE_VERSION}.tar.bz2"
PYODIDE_URL="https://github.com/pyodide/pyodide/releases/download/${PYODIDE_VERSION}/${PYODIDE_ARCHIVE}"
PYODIDE_CACHE="$CACHE_DIR/${PYODIDE_ARCHIVE}"
PYODIDE_SRC="$CACHE_DIR/pyodide-${PYODIDE_VERSION}"

mkdir -p "$CACHE_DIR" "$OUTPUT_DIR" "$CONTENTS_DIR"

if [ ! -f "$PYODIDE_CACHE" ]; then
  echo "Downloading Pyodide ${PYODIDE_VERSION}"
  curl -L "$PYODIDE_URL" -o "$PYODIDE_CACHE"
fi

if [ ! -d "$PYODIDE_SRC" ]; then
  echo "Extracting Pyodide ${PYODIDE_VERSION}"
  rm -rf "$PYODIDE_SRC"
  tar -xjf "$PYODIDE_CACHE" -C "$CACHE_DIR"
  mv "$CACHE_DIR/pyodide" "$PYODIDE_SRC"
fi

# Remove stale Lite bundles that would otherwise be treated as source configs
if [ -d "$DIST_LITE_DIR" ]; then
  echo "Cleaning previous Lite artefacts in $DIST_LITE_DIR"
  rm -rf "$DIST_LITE_DIR"
fi

if [ ! -d "$VENV_DIR" ] || [ ! -x "$VENV_DIR/bin/python" ]; then
  rm -rf "$VENV_DIR"
  python3 -m venv "$VENV_DIR"
fi

PYTHON="$VENV_DIR/bin/python"
JUPYTER="$VENV_DIR/bin/jupyter"

"$PYTHON" -m pip install --upgrade --quiet pip
"$PYTHON" -m pip install --quiet \
  "jupyterlite==$JUPYTERLITE_VERSION" \
  "jupyterlite-core==$JUPYTERLITE_VERSION" \
  "jupyterlite-pyodide-kernel==$PYODIDE_KERNEL_VERSION" \
  "jupyter-server>=2.14.1,<3"

echo "Building JupyterLite assets into $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"

"$JUPYTER" lite build \
  --output-dir "$OUTPUT_DIR" \
  --contents "$CONTENTS_DIR" \
  --apps lab --apps notebook --apps repl \
  --base-url /eln/lite \
  --debug

rm -rf "$OUTPUT_DIR/pyodide"
cp -a "$PYODIDE_SRC" "$OUTPUT_DIR/pyodide"

# Build a local wheelhouse for the generated PostgREST client so Pyodide can install it offline
echo "Preparing Pyodide wheelhouse in $PIP_WHEEL_DIR"
rm -rf "$PIP_WHEEL_DIR"
mkdir -p "$PIP_WHEEL_DIR"

if [ ! -d "$PY_CLIENT_DIR" ]; then
  echo "Missing Python client sources at $PY_CLIENT_DIR" >&2
  exit 1
fi

"$PYTHON" -m pip wheel "$PY_CLIENT_DIR" --wheel-dir "$PIP_WHEEL_DIR" >/dev/null
if [ "${#PYODIDE_EXTRA_WHEELS[@]}" -gt 0 ]; then
  "$PYTHON" -m pip wheel "${PYODIDE_EXTRA_WHEELS[@]}" --wheel-dir "$PIP_WHEEL_DIR" >/dev/null
fi

CLIENT_INDEX_SHA=$("$PYTHON" - <<'PY' "$PIP_WHEEL_DIR" "${PIP_WHEEL_DIR}/all.json"
import hashlib
import json
import pathlib
import sys
import time

wheel_dir = pathlib.Path(sys.argv[1])
index_path = pathlib.Path(sys.argv[2])

index: dict[str, dict] = {}
timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
for wheel in sorted(wheel_dir.glob("*.whl")):
    parts = wheel.name.split("-")
    if len(parts) < 2:
        continue
    package = parts[0].replace("_", "-")
    version = parts[1]
    sha = hashlib.sha256(wheel.read_bytes()).hexdigest()
    entry = {
        "comment_text": "",
        "digests": {"md5": "", "sha256": sha},
        "downloads": -1,
        "filename": wheel.name,
        "has_sig": False,
        "md5_digest": "",
        "packagetype": "bdist_wheel",
        "python_version": "py3",
        "requires_python": ">=3.9",
        "size": wheel.stat().st_size,
        "upload_time": timestamp,
        "upload_time_iso_8601": timestamp,
        "url": f"./{wheel.name}",
        "yanked": False,
        "yanked_reason": None,
    }
    releases = index.setdefault(package, {"releases": {}})["releases"]
    releases.setdefault(version, []).append(entry)

index_path.write_text(json.dumps(index, indent=2))
print(hashlib.sha256(index_path.read_bytes()).hexdigest())
PY
)

# ensure window.jupyterapp is exposed for the iframe bridge and wire up piplite to the wheelhouse
"$PYTHON" - <<'PY' "$OUTPUT_DIR/jupyter-lite.json" "$CLIENT_INDEX_SHA"
import json
import sys

path = sys.argv[1]
client_index_sha = sys.argv[2]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

config = data.setdefault("jupyter-config-data", {})
config["exposeAppInBrowser"] = True
config["pyodideUrl"] = "./pyodide/"

kernel_settings = config.setdefault("litePluginSettings", {}).setdefault(
    "@jupyterlite/pyodide-kernel-extension:kernel", {}
)
existing_urls = kernel_settings.setdefault("pipliteUrls", [])
kernel_settings["pipliteUrls"] = [
    url for url in existing_urls if not url.startswith("./pypi/all.json?")
]
client_index_url = f"./pypi/all.json?sha256={client_index_sha}"
if client_index_url not in kernel_settings["pipliteUrls"]:
    kernel_settings["pipliteUrls"].append(client_index_url)

required_packages = [
    "crazylims-postgrest-client",
    "pyodide-http",
    "httpx",
    "attrs",
    "python-dateutil",
]
packages = kernel_settings.get("packages", [])
for package in required_packages:
    if package not in packages:
        packages.append(package)
kernel_settings["packages"] = packages

# Pin the Pyodide runtime to the locally vendored bundle instead of the CDN default
base_pyodide_url = config.get("pyodideUrl", "./pyodide/").rstrip("/")
kernel_settings["pyodideUrl"] = f"{base_pyodide_url}/pyodide.js"

with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY

date +%s >"$STAMP_FILE"

echo "JupyterLite assets refreshed."
