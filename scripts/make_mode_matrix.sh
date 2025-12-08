#!/usr/bin/env bash
set -euo pipefail

# Print the commands each Make target would run in Docker vs local modes without
# actually executing them. Useful for verifying parity after Makefile refactors.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

default_targets=(
  up
  down
  logs
  contracts/export
  test/security
  test/rest-story
  db/test
  ci
)

targets=("${@:-}")
if [[ ${#targets[@]} -eq 0 || -z "${targets[0]}" ]]; then
  targets=("${default_targets[@]}")
fi

for mode in yes no; do
  echo "=== USE_DOCKER=${mode} ==="
  for target in "${targets[@]}"; do
    echo "-- make -n ${target}"
    USE_DOCKER="${mode}" make -n "${target}"
    echo
  done
  echo
done
