#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: export_postgrest_openapi.sh <base-url> <jwt-file> <output-path>

Fetches the PostgREST OpenAPI description for the default schema plus
the app_security and app_provenance profiles, merges them, and writes
the result to <output-path>. Exits non-zero if the expected REST-story
endpoints are missing.
USAGE
}

if [[ $# -ne 3 ]]; then
  usage
  exit 1
fi

BASE_URL="${1%/}"
JWT_FILE="$2"
OUTPUT_PATH="$3"

if [[ -z "${BASE_URL}" ]]; then
  echo "Base URL is required" >&2
  exit 1
fi

if [[ ! -f "${JWT_FILE}" ]]; then
  echo "JWT file not found: ${JWT_FILE}" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to export the OpenAPI contract" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to export the OpenAPI contract" >&2
  exit 1
fi

TOKEN="$(<"${JWT_FILE}")"

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

fetch_profile() {
  local profile="$1"
  local destination="$2"
  local label="$3"

  local -a curl_args=(-sS --fail --retry 24 --retry-delay 1 --retry-all-errors
    -H "Accept: application/openapi+json"
    -H "Authorization: Bearer ${TOKEN}")

  if [[ -n "${profile}" ]]; then
    curl_args+=(-H "Accept-Profile: ${profile}")
  fi

  local attempt
  for attempt in $(seq 1 60); do
    if curl "${curl_args[@]}" "${BASE_URL}/" -o "${destination}"; then
      if jq -e '.swagger == "2.0"' "${destination}" >/dev/null 2>&1; then
        return 0
      fi
    fi
    sleep 1
  done

  echo "Failed to fetch OpenAPI for ${label} profile" >&2
  return 1
}

CORE_SPEC="${WORK_DIR}/core.json"
SEC_SPEC="${WORK_DIR}/security.json"
PROV_SPEC="${WORK_DIR}/provenance.json"

fetch_profile "" "${CORE_SPEC}" "default"
fetch_profile "app_security" "${SEC_SPEC}" "app_security"
fetch_profile "app_provenance" "${PROV_SPEC}" "app_provenance"

MERGED="${WORK_DIR}/merged.json"
jq -s '
  reduce (.[1:][]) as $spec (.[0];
    .paths = ((.paths // {}) + ($spec.paths // {}))
    | .definitions = ((.definitions // {}) + ($spec.definitions // {}))
    | .parameters = ((.parameters // {}) + ($spec.parameters // {}))
    | .responses = ((.responses // {}) + ($spec.responses // {}))
    | .securityDefinitions = ((.securityDefinitions // {}) + ($spec.securityDefinitions // {}))
    | .tags = (((.tags // []) + ($spec.tags // [])) | unique)
  )
' "${CORE_SPEC}" "${SEC_SPEC}" "${PROV_SPEC}" > "${MERGED}"

EXPECTED_CHECK='
  (.paths | has("/scopes"))
  and (.paths | has("/artefacts"))
  and (.paths | has("/artefact_scopes"))
  and (.paths | has("/artefact_relationships"))
  and (.paths | has("/rpc/sp_handover_to_ops"))
'

if ! jq -e "${EXPECTED_CHECK}" "${MERGED}" >/dev/null 2>&1; then
  echo "Merged OpenAPI missing expected REST-story endpoints" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_PATH}")"
mv "${MERGED}" "${OUTPUT_PATH}"
