#!/usr/bin/env bash
set -euo pipefail

# Ensure Playwright browsers and system dependencies (e.g., libatk-1.0.so.0) are present
# for running UI tests. The install step is idempotent thanks to the stamp file check
# and will re-run automatically if package manifests change.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_ROOT="${SCRIPT_DIR}/.."
STAMP_FILE="${UI_ROOT}/.playwright-installed"
INSTALL_CMD="${PLAYWRIGHT_INSTALL_CMD:-npx playwright install --with-deps chromium}"

cd "${UI_ROOT}"

if [[ -f "${STAMP_FILE}" ]]; then
  if [[ "${STAMP_FILE}" -nt "package-lock.json" && "${STAMP_FILE}" -nt "package.json" ]]; then
    exit 0
  fi
fi

echo "Installing Playwright browsers and system dependencies via: ${INSTALL_CMD}" >&2
bash -lc "${INSTALL_CMD}"
touch "${STAMP_FILE}"
