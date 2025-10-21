#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POSTGREST_URL="${POSTGREST_URL:-http://postgrest:3000}"
JWT_SECRET="${PGRST_JWT_SECRET:-dev_jwt_secret_change_me_which_is_at_least_32_characters}"
EXPIRY=4070908800
ISSUER="rest-story-suite"
AUDIENCE="crazy-lims"

declare -i failures=0
last_body=""
last_status=""

sanitize_key() {
  local key="$1"
  LC_ALL=C printf '%s' "${key}" | tr -c 'A-Za-z0-9_' '_'
}

set_scope_id() {
  local key="$1" value="$2" sanitized
  sanitized="$(sanitize_key "${key}")"
  printf -v "SCOPE_ID_${sanitized}" '%s' "${value}"
}

get_scope_id() {
  local key="$1" sanitized var
  sanitized="$(sanitize_key "${key}")"
  var="SCOPE_ID_${sanitized}"
  printf '%s' "${!var:-}"
}

set_user_id() {
  local email="$1" value="$2" sanitized
  sanitized="$(sanitize_key "${email}")"
  printf -v "USER_ID_${sanitized}" '%s' "${value}"
}

get_user_id() {
  local email="$1" sanitized var
  sanitized="$(sanitize_key "${email}")"
  var="USER_ID_${sanitized}"
  printf '%s' "${!var:-}"
}

set_token() {
  local email="$1" value="$2" sanitized
  sanitized="$(sanitize_key "${email}")"
  printf -v "TOKEN_${sanitized}" '%s' "${value}"
}

get_token() {
  local email="$1" sanitized var
  sanitized="$(sanitize_key "${email}")"
  var="TOKEN_${sanitized}"
  printf '%s' "${!var:-}"
}

new_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
  fi
}

declare -a GAMMA_DONORS=()
declare -a GAMMA_PLATE_WELLS=()
declare -a GAMMA_FRAGMENT_WELLS=()
declare -a GAMMA_LIBRARY_WELLS=()
declare -a GAMMA_OPS_DUPLICATES=()
declare -a GAMMA_NORMALIZED_WELLS=()
declare -a GAMMA_DATA_PRODUCTS_OPS=()
declare -a GAMMA_DATA_PRODUCTS_RESEARCH=()

GAMMA_PLATE_ID=""
GAMMA_FRAGMENT_PLATE_ID=""
GAMMA_LIBRARY_PLATE_ID=""
GAMMA_NORMALIZED_PLATE_ID=""
GAMMA_POOL_ID=""

SCENARIO_TS="$(date +%s)"
SCENARIO_KEY="rest-story-${SCENARIO_TS}"
SEED_TAG="rest_api_story_${SCENARIO_TS}"

PROJECT1_CODE="project:gamma-${SCENARIO_TS}"
PROJECT2_CODE="project:zeta-${SCENARIO_TS}"
OPS_FACILITY_CODE="facility:ops-${SCENARIO_TS}"
OPS_LIB_CODE="ops:gamma-lib-${SCENARIO_TS}"
OPS_QUANT_CODE="ops:gamma-quant-${SCENARIO_TS}"
OPS_POOL_CODE="ops:gamma-pool-${SCENARIO_TS}"
OPS_RUN_CODE="ops:gamma-run-${SCENARIO_TS}"

ADMIN_TOKEN=""

TYPE_PLATE=""
TYPE_SAMPLE=""
TYPE_LIBRARY=""
TYPE_POOL=""
TYPE_DATA=""

GAMMA_WELLS=("A01" "A02")

log_ok() {
  printf '✅ %s\n' "$1" >&2
}

log_fail() {
  printf '❌ %s\n' "$1" >&2
}

record_failure() {
  log_fail "$1"
  failures=$((failures + 1))
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for REST story tests" >&2
    exit 1
  fi
}

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

sign_jwt() {
  local signing_input="$1"
  printf '%s' "${signing_input}" | openssl dgst -binary -sha256 -hmac "${JWT_SECRET}" | base64url
}

issue_jwt() {
  local email="$1"
  local preferred="$2"
  local roles_csv="$3"
  local subject="$4"
  local role="$5"

  local header payload header_b64 payload_b64 signature
  header='{"alg":"HS256","typ":"JWT"}'
  header_b64="$(printf '%s' "${header}" | base64url)"
  payload="$(jq -n \
    --arg iss "${ISSUER}" \
    --arg aud "${AUDIENCE}" \
    --arg sub "${subject}" \
    --arg preferred "${preferred}" \
    --arg email "${email}" \
    --arg role "${role}" \
    --arg roles "${roles_csv}" \
    --argjson exp "${EXPIRY}" \
    '{
      iss: $iss,
      aud: $aud,
      sub: $sub,
      preferred_username: $preferred,
      email: $email,
      role: $role,
      roles: ( ($roles | split(",") | map(select(length > 0))) ),
      exp: $exp,
      iat: 1700000000
    }')"
  payload_b64="$(printf '%s' "${payload}" | base64url)"
  signature="$(sign_jwt "${header_b64}.${payload_b64}")"
  printf '%s.%s.%s' "${header_b64}" "${payload_b64}" "${signature}"
}

request_postgrest() {
  local label="$1"
  local token="$2"
  local expected_status="$3"
  local method="$4"
  local path="$5"
  local body="$6"
  local jq_expr="$7"
  local profile="${8:-}"
  local prefer="${9:-return=representation}"

  local url="${POSTGREST_URL}${path}"
  local -a curl_args=(-sS --retry 5 --retry-delay 1 --retry-all-errors -w '\n%{http_code}' -H "Authorization: Bearer ${token}" -X "${method}")

  if [[ "${method}" == "POST" || "${method}" == "PATCH" ]]; then
    if [[ -n "${prefer}" ]]; then
      curl_args+=(-H "Prefer: ${prefer}")
    fi
  fi

  if [[ -n "${profile}" ]]; then
    curl_args+=(-H "Accept-Profile: ${profile}")
    if [[ "${method}" != "GET" && "${method}" != "HEAD" ]]; then
      curl_args+=(-H "Content-Profile: ${profile}")
    fi
  fi

  if [[ -n "${body}" ]]; then
    curl_args+=(-H "Content-Type: application/json" -d "${body}")
  fi

  curl_args+=("${url}")
  local response status body_json
  response="$(curl "${curl_args[@]}" || true)"
  status="${response##*$'\n'}"
  body_json="${response%$'\n'*}"

  last_status="${status}"
  last_body="${body_json}"

  local normalized_expected
  normalized_expected="${expected_status//,/ }"
  normalized_expected="${normalized_expected//|/ }"
  local -a __expected_statuses=()
  read -ra __expected_statuses <<<"${normalized_expected}"
  if [[ ${#__expected_statuses[@]} -eq 0 ]]; then
    __expected_statuses=("${expected_status}")
  fi

  local matched="false"
  local candidate
  for candidate in "${__expected_statuses[@]}"; do
    if [[ -n "${candidate}" && "${status}" == "${candidate}" ]]; then
      matched="true"
      break
    fi
  done

  if [[ "${matched}" != "true" ]]; then
    record_failure "${label} (expected ${expected_status}, got ${status})"
    return 1
  fi

  if [[ -n "${jq_expr}" ]]; then
    if ! echo "${body_json}" | jq -e "${jq_expr}" >/dev/null 2>&1; then
      record_failure "${label} body check failed"
      return 1
    fi
  fi

  log_ok "${label}"
  return 0
}

lookup_single_id() {
  local token="$1"
  local path="$2"
  local field="$3"
  local profile="${4:-}"

  if ! request_postgrest "lookup ${field} ${path}" "${token}" "200" "GET" "${path}" "" "length == 1 and .[0].${field} != null" "${profile}"; then
    echo ""
    return
  fi
  echo "${last_body}" | jq -r ".[0].${field}"
}

admin_get_user_id() {
  local email="$1"
  lookup_single_id "${ADMIN_TOKEN}" "/users?select=id,email&email=eq.${email}" "id"
}

create_scope() {
  local scope_key="$1"
  local scope_type="$2"
  local display_name="$3"
  local parent_scope_key="$4"

  local parent_id=""
  if [[ -n "${parent_scope_key}" ]]; then
    parent_id="$(get_scope_id "${parent_scope_key}")"
  fi

  local body
  body="$(jq -n \
    --arg scope_key "${scope_key}" \
    --arg scope_type "${scope_type}" \
    --arg name "${display_name}" \
    --arg seed "${SEED_TAG}" \
    --arg parent "${parent_id}" \
    '{
      scope_key: $scope_key,
      scope_type: $scope_type,
      display_name: $name,
      metadata: {seed: $seed, scenario: "'${SCENARIO_KEY}'"},
      parent_scope_id: (if $parent == "" then null else $parent end)
    }')"

  if ! request_postgrest "create scope ${scope_key}" "${ADMIN_TOKEN}" "201" "POST" "/scopes" "${body}" ".[0].scope_id != null" "app_security"; then
    return 1
  fi
  local scope_id
  scope_id="$(echo "${last_body}" | jq -r '.[0].scope_id')"
  set_scope_id "${scope_key}" "${scope_id}"
  return 0
}

create_user() {
  local email="$1"
  local full_name="$2"
  local default_role="$3"
  local is_service="${4:-false}"

  local body
  body="$(jq -n \
    --arg email "${email}" \
    --arg name "${full_name}" \
    --arg role "${default_role}" \
    --argjson service "$(if [[ "${is_service}" == "true" ]]; then echo "true"; else echo "false"; fi)" \
    --arg seed "${SEED_TAG}" \
    '{
      email: $email,
      full_name: $name,
      default_role: $role,
      is_service_account: $service,
      metadata: {seed: $seed, scenario: "'${SCENARIO_KEY}'"}
    }')"

  if ! request_postgrest "create user ${email}" "${ADMIN_TOKEN}" "201|200" "POST" "/users?on_conflict=email" "${body}" ".[0].id != null" "" "return=representation,resolution=merge-duplicates"; then
    return 1
  fi
  local user_id
  user_id="$(echo "${last_body}" | jq -r '.[0].id')"
  set_user_id "${email}" "${user_id}"
  return 0
}

grant_user_role() {
  local email="$1"
  local role_name="$2"
  local granted_by="$3"

  local user_id
  user_id="$(get_user_id "${email}")"
  if [[ -z "${user_id}" ]]; then
    record_failure "grant role ${role_name} to ${email} (user missing)"
    return 1
  fi

  local body
  body="$(jq -n \
    --arg user "${user_id}" \
    --arg role "${role_name}" \
    --arg gb "${granted_by}" \
    '{
      user_id: $user,
      role_name: $role,
      granted_by: (if $gb == "" then null else $gb end)
    }')"

  request_postgrest "grant role ${role_name} to ${email}" "${ADMIN_TOKEN}" "201|200" "POST" "/user_roles?on_conflict=user_id,role_name" "${body}" "" "" "return=representation,resolution=merge-duplicates"
}

add_scope_membership() {
  local email="$1"
  local scope_key="$2"
  local role_name="$3"

  local user_id scope_id
  user_id="$(get_user_id "${email}")"
  scope_id="$(get_scope_id "${scope_key}")"

  if [[ -z "${user_id}" || -z "${scope_id}" ]]; then
    record_failure "add scope membership ${email} -> ${scope_key} (missing ids)"
    return 1
  fi

  local body
  body="$(jq -n \
    --arg user "${user_id}" \
    --arg scope "${scope_id}" \
    --arg role "${role_name}" \
    --arg seed "${SEED_TAG}" \
    '{
      user_id: $user,
      scope_id: $scope,
      role_name: $role,
      metadata: {seed: $seed, scenario: "'${SCENARIO_KEY}'"}
    }')"

  request_postgrest "scope membership ${email} -> ${scope_key}" "${ADMIN_TOKEN}" "201|200" "POST" "/scope_memberships?on_conflict=user_id,scope_id,role_name" "${body}" "" "app_security" "return=representation,resolution=merge-duplicates"
}

load_admin_token() {
  local path="${ROOT_DIR}/ops/examples/jwts/admin.jwt"
  if [[ ! -f "${path}" ]]; then
    echo "missing admin token at ${path}" >&2
    exit 1
  fi
  ADMIN_TOKEN="$(<"${path}")"
}

lookup_type_ids() {
  TYPE_PLATE="$(lookup_single_id "${ADMIN_TOKEN}" "/artefact_types?select=artefact_type_id&type_key=eq.container_plate_96" "artefact_type_id" "app_provenance")"
  TYPE_SAMPLE="$(lookup_single_id "${ADMIN_TOKEN}" "/artefact_types?select=artefact_type_id&type_key=eq.dna_extract" "artefact_type_id" "app_provenance")"
  TYPE_LIBRARY="$(lookup_single_id "${ADMIN_TOKEN}" "/artefact_types?select=artefact_type_id&type_key=eq.library" "artefact_type_id" "app_provenance")"
  TYPE_POOL="$(lookup_single_id "${ADMIN_TOKEN}" "/artefact_types?select=artefact_type_id&type_key=eq.pooled_library" "artefact_type_id" "app_provenance")"
  TYPE_DATA="$(lookup_single_id "${ADMIN_TOKEN}" "/artefact_types?select=artefact_type_id&type_key=eq.data_product_sequence" "artefact_type_id" "app_provenance")"

  if [[ -z "${TYPE_PLATE}" || -z "${TYPE_SAMPLE}" || -z "${TYPE_LIBRARY}" || -z "${TYPE_POOL}" || -z "${TYPE_DATA}" ]]; then
    echo "failed to lookup required artefact types" >&2
    exit 1
  fi
}

issue_story_tokens() {
  local pairs=(
    "gail.gamma@crazy.example|gamma-virtual|app_researcher,app_operator|urn:story:gamma-virtual|app_operator"
    "helen.gamma@crazy.example|gamma-plate|app_researcher,app_operator|urn:story:gamma-plate|app_operator"
    "ian.gamma@crazy.example|gamma-labtech|app_researcher,app_operator|urn:story:gamma-labtech|app_operator"
    "zara.zeta@crazy.example|zeta-researcher|app_researcher,app_operator|urn:story:zeta|app_operator"
    "ollie.ops@crazy.example|ops-tech1|app_operator|urn:story:ops-tech1|app_operator"
    "poppy.ops@crazy.example|ops-tech2|app_operator|urn:story:ops-tech2|app_operator"
    "instrument.gamma@crazy.example|instrument-gamma|app_automation|urn:story:instrument-gamma|app_automation"
  )

  local entry
  for entry in "${pairs[@]}"; do
    IFS='|' read -r email preferred roles subject role <<<"${entry}"
    set_token "${email}" "$(issue_jwt "${email}" "${preferred}" "${roles}" "${subject}" "${role}")"
  done
}

user_token() {
  local email="$1"
  get_token "${email}"
}

artefact_scope_body() {
  local artefact_id="$1"
  local scope_key="$2"
  local note="$3"
  local scope_id
  scope_id="$(get_scope_id "${scope_key}")"
  jq -n \
    --arg artefact "${artefact_id}" \
    --arg scope "${scope_id}" \
    --arg seed "${SEED_TAG}" \
    --arg note "${note}" \
    '{
      artefact_id: $artefact,
      scope_id: $scope,
      relationship: "primary",
      metadata: {seed: $seed, scenario: "'${SCENARIO_KEY}'", note: $note}
    }'
}

relationship_body() {
  local parent="$1"
  local child="$2"
  local rtype="$3"
  local step="$4"
  jq -n \
    --arg parent "${parent}" \
    --arg child "${child}" \
    --arg rtype "${rtype}" \
    --arg seed "${SEED_TAG}" \
    --arg step "${step}" \
    '{
      parent_artefact_id: $parent,
      child_artefact_id: $child,
      relationship_type: $rtype,
      metadata: {seed: $seed, scenario: "'${SCENARIO_KEY}'", step: $step}
    }'
}

create_gamma_donors() {
  local email="gail.gamma@crazy.example"
  local token
  token="$(user_token "${email}")"
  local idx=0
  for well in "${GAMMA_WELLS[@]}"; do
    idx=$((idx + 1))
    local label
    printf -v label "%02d" "${idx}"
    local name="Gamma Virtual Donor ${label}"
    local external="gamma-${SCENARIO_TS}-donor-${label}"
    local artefact_id
    artefact_id="$(new_uuid)"
    local body
    body="$(jq -n \
      --arg id "${artefact_id}" \
      --arg type "${TYPE_SAMPLE}" \
      --arg name "${name}" \
      --arg ext "${external}" \
      --arg seed "${SEED_TAG}" \
      --arg idx "${idx}" \
      --arg scope "${PROJECT1_CODE}" \
      --arg scenario "${SCENARIO_KEY}" \
      '{
        artefact_id: $id,
        artefact_type_id: $type,
        name: $name,
        external_identifier: $ext,
        status: "active",
        is_virtual: true,
        metadata: {
          seed: $seed,
          scenario: $scenario,
          project_scope: $scope,
          donor_index: ($idx|tonumber)
        }
      }')"

    if ! request_postgrest "gamma donor ${label}" "${token}" "201" "POST" "/artefacts" "${body}" "" "app_provenance" "return=minimal"; then
      continue
    fi
    GAMMA_DONORS+=("${artefact_id}")

    local scope_body
    scope_body="$(artefact_scope_body "${artefact_id}" "${PROJECT1_CODE}" "gamma donor")"
    request_postgrest "gamma donor scope ${label}" "${token}" "201" "POST" "/artefact_scopes" "${scope_body}" "" "app_provenance" "return=minimal"
  done
}

create_gamma_plate() {
  local email="helen.gamma@crazy.example"
  local token
  token="$(user_token "${email}")"

  GAMMA_PLATE_ID="$(new_uuid)"
  local plate_body
  plate_body="$(jq -n \
    --arg id "${GAMMA_PLATE_ID}" \
    --arg type "${TYPE_PLATE}" \
    --arg seed "${SEED_TAG}" \
    --arg scenario "${SCENARIO_KEY}" \
    '{
      artefact_id: $id,
      artefact_type_id: $type,
      name: "Gamma Source Plate GSP1",
      external_identifier: "gamma-plate-gsp1-'${SCENARIO_TS}'",
      status: "active",
      metadata: {
        seed: $seed,
        scenario: $scenario,
        plate: "GSP1",
        barcode: "GSP1"
      }
    }')"

  request_postgrest "gamma plate GSP1" "${token}" "201" "POST" "/artefacts" "${plate_body}" "" "app_provenance" "return=minimal"

  local plate_scope
  plate_scope="$(artefact_scope_body "${GAMMA_PLATE_ID}" "${PROJECT1_CODE}" "gamma source plate")"
  request_postgrest "gamma plate scope" "${token}" "201" "POST" "/artefact_scopes" "${plate_scope}" "" "app_provenance" "return=minimal"

  local idx=0
  for well in "${GAMMA_WELLS[@]}"; do
    idx=$((idx + 1))
    local donor="${GAMMA_DONORS[$((idx-1))]}"
    local well_id
    well_id="$(new_uuid)"
    local sample_body
    sample_body="$(jq -n \
      --arg id "${well_id}" \
      --arg type "${TYPE_SAMPLE}" \
      --arg seed "${SEED_TAG}" \
      --arg scenario "${SCENARIO_KEY}" \
      --arg well "${well}" \
      --arg plate "${GAMMA_PLATE_ID}" \
      --arg scenets "${SCENARIO_TS}" \
      '{
        artefact_id: $id,
        artefact_type_id: $type,
        name: ("Gamma GSP1 " + $well),
        external_identifier: ("gamma-gsp1-" + ($well | ascii_downcase) + "-" + $scenets),
        status: "active",
        container_artefact_id: $plate,
        metadata: {
          seed: $seed,
          scenario: $scenario,
          plate: "GSP1",
          well_position: $well
        }
      }')"

    request_postgrest "gamma GSP1 well ${well}" "${token}" "201" "POST" "/artefacts" "${sample_body}" "" "app_provenance" "return=minimal"
    GAMMA_PLATE_WELLS+=("${well_id}")

    local scope_body
    scope_body="$(artefact_scope_body "${well_id}" "${PROJECT1_CODE}" "gamma source well")"
    request_postgrest "gamma GSP1 scope ${well}" "${token}" "201" "POST" "/artefact_scopes" "${scope_body}" "" "app_provenance" "return=minimal"

    local rel_body
    rel_body="$(relationship_body "${donor}" "${well_id}" "virtual_source" "gamma-plate-intake")"
    request_postgrest "gamma donor link ${well}" "${token}" "201" "POST" "/artefact_relationships" "${rel_body}" "" "app_provenance" "return=minimal"
  done
}

create_gamma_fragment() {
  local email="helen.gamma@crazy.example"
  local token
  token="$(user_token "${email}")"

  GAMMA_FRAGMENT_PLATE_ID="$(new_uuid)"
  local plate_body
  plate_body="$(jq -n \
    --arg id "${GAMMA_FRAGMENT_PLATE_ID}" \
    --arg type "${TYPE_PLATE}" \
    --arg seed "${SEED_TAG}" \
    --arg scenario "${SCENARIO_KEY}" \
    '{
      artefact_id: $id,
      artefact_type_id: $type,
      name: "Gamma Fragment Plate GFR1",
      external_identifier: "gamma-plate-gfr1-'${SCENARIO_TS}'",
      status: "active",
      metadata: {
        seed: $seed,
        scenario: $scenario,
        plate: "GFR1",
        barcode: "GFR1"
      }
    }')"

  request_postgrest "gamma fragment plate GFR1" "${token}" "201" "POST" "/artefacts" "${plate_body}" "" "app_provenance" "return=minimal"

  local scope_body
  scope_body="$(artefact_scope_body "${GAMMA_FRAGMENT_PLATE_ID}" "${PROJECT1_CODE}" "gamma fragment plate")"
  request_postgrest "gamma fragment plate scope" "${token}" "201" "POST" "/artefact_scopes" "${scope_body}" "" "app_provenance" "return=minimal"

  local idx=0
  for well in "${GAMMA_WELLS[@]}"; do
    idx=$((idx + 1))
    local parent="${GAMMA_PLATE_WELLS[$((idx-1))]}"
    local frag_id
    frag_id="$(new_uuid)"
    local sample_body
    sample_body="$(jq -n \
      --arg id "${frag_id}" \
      --arg type "${TYPE_SAMPLE}" \
      --arg seed "${SEED_TAG}" \
      --arg scenario "${SCENARIO_KEY}" \
      --arg well "${well}" \
      --arg plate "${GAMMA_FRAGMENT_PLATE_ID}" \
      --arg scenets "${SCENARIO_TS}" \
      '{
        artefact_id: $id,
        artefact_type_id: $type,
        name: ("Gamma GFR1 " + $well),
        external_identifier: ("gamma-gfr1-" + ($well | ascii_downcase) + "-" + $scenets),
        status: "active",
        container_artefact_id: $plate,
        metadata: {
          seed: $seed,
          scenario: $scenario,
          plate: "GFR1",
          well_position: $well
        }
      }')"

    request_postgrest "gamma fragment well ${well}" "${token}" "201" "POST" "/artefacts" "${sample_body}" "" "app_provenance" "return=minimal"
    GAMMA_FRAGMENT_WELLS+=("${frag_id}")

    local scope_json
    scope_json="$(artefact_scope_body "${frag_id}" "${PROJECT1_CODE}" "gamma fragment well")"
    request_postgrest "gamma fragment scope ${well}" "${token}" "201" "POST" "/artefact_scopes" "${scope_json}" "" "app_provenance" "return=minimal"

    local rel_json
    rel_json="$(relationship_body "${parent}" "${frag_id}" "derived_from" "gamma-fragmentation")"
    request_postgrest "gamma fragment link ${well}" "${token}" "201" "POST" "/artefact_relationships" "${rel_json}" "" "app_provenance" "return=minimal"
  done
}

create_gamma_library() {
  local email="ian.gamma@crazy.example"
  local token
  token="$(user_token "${email}")"

  GAMMA_LIBRARY_PLATE_ID="$(new_uuid)"
  local plate_body
  plate_body="$(jq -n \
    --arg id "${GAMMA_LIBRARY_PLATE_ID}" \
    --arg type "${TYPE_PLATE}" \
    --arg seed "${SEED_TAG}" \
    --arg scenario "${SCENARIO_KEY}" \
    '{
      artefact_id: $id,
      artefact_type_id: $type,
      name: "Gamma Library Plate GLB1",
      external_identifier: "gamma-plate-glb1-'${SCENARIO_TS}'",
      status: "active",
      metadata: {
        seed: $seed,
        scenario: $scenario,
        plate: "GLB1",
        barcode: "GLB1"
      }
    }')"

  request_postgrest "gamma library plate GLB1" "${token}" "201" "POST" "/artefacts" "${plate_body}" "" "app_provenance" "return=minimal"

  local scope_body
  scope_body="$(artefact_scope_body "${GAMMA_LIBRARY_PLATE_ID}" "${PROJECT1_CODE}" "gamma library plate")"
  request_postgrest "gamma library plate scope" "${token}" "201" "POST" "/artefact_scopes" "${scope_body}" "" "app_provenance" "return=minimal"

  local idx=0
  for well in "${GAMMA_WELLS[@]}"; do
    idx=$((idx + 1))
    local parent="${GAMMA_FRAGMENT_WELLS[$((idx-1))]}"
    local lib_id
    lib_id="$(new_uuid)"
    local lib_body
    lib_body="$(jq -n \
      --arg id "${lib_id}" \
      --arg type "${TYPE_LIBRARY}" \
      --arg seed "${SEED_TAG}" \
      --arg scenario "${SCENARIO_KEY}" \
      --arg well "${well}" \
      --arg plate "${GAMMA_LIBRARY_PLATE_ID}" \
      --arg scenets "${SCENARIO_TS}" \
      '{
        artefact_id: $id,
        artefact_type_id: $type,
        name: ("Gamma GLB1 " + $well),
        external_identifier: ("gamma-glb1-" + ($well | ascii_downcase) + "-" + $scenets),
        status: "active",
        container_artefact_id: $plate,
        metadata: {
          seed: $seed,
          scenario: $scenario,
          plate: "GLB1",
          well_position: $well,
          index_pair: ("IDX-" + ($well | ascii_upcase))
        }
      }')"

    request_postgrest "gamma library well ${well}" "${token}" "201" "POST" "/artefacts" "${lib_body}" "" "app_provenance" "return=minimal"
    GAMMA_LIBRARY_WELLS+=("${lib_id}")

    local scope_json
    scope_json="$(artefact_scope_body "${lib_id}" "${PROJECT1_CODE}" "gamma library well")"
    request_postgrest "gamma library scope ${well}" "${token}" "201" "POST" "/artefact_scopes" "${scope_json}" "" "app_provenance" "return=minimal"

    local rel_json
    rel_json="$(relationship_body "${parent}" "${lib_id}" "derived_from" "gamma-library-index")"
    request_postgrest "gamma library link ${well}" "${token}" "201" "POST" "/artefact_relationships" "${rel_json}" "" "app_provenance" "return=minimal"
  done
}

handover_gamma_libraries() {
  local email="ian.gamma@crazy.example"
  local token
  token="$(user_token "${email}")"

  local artefact_array
  artefact_array="$(printf '%s\n' "${GAMMA_LIBRARY_WELLS[@]}" | jq -R . | jq -s .)"

  local body
  body="$(jq -n \
    --arg scope_id "$(get_scope_id "${PROJECT1_CODE}")" \
    --arg ops_scope "${OPS_LIB_CODE}" \
    --argjson artefacts "${artefact_array}" \
    '{
      p_research_scope_id: $scope_id,
      p_ops_scope_key: $ops_scope,
      p_artefact_ids: $artefacts,
      p_field_whitelist: ["well_position","index_pair"]
    }')"

  request_postgrest "gamma handover to ops" "${token}" "200" "POST" "/rpc/sp_handover_to_ops" "${body}" "" "app_provenance"

  GAMMA_OPS_DUPLICATES=()
  local lib_id rel_body child_id
  for lib_id in "${GAMMA_LIBRARY_WELLS[@]}"; do
    rel_body="/artefact_relationships?select=child_artefact_id&relationship_type=eq.handover_duplicate&parent_artefact_id=eq.${lib_id}"
    if request_postgrest "lookup ops duplicate ${lib_id}" "${ADMIN_TOKEN}" "200" "GET" "${rel_body}" "" "length == 1 and .[0].child_artefact_id != null" "app_provenance"; then
      child_id="$(echo "${last_body}" | jq -r '.[0].child_artefact_id')"
      GAMMA_OPS_DUPLICATES+=("${child_id}")
    else
      record_failure "missing ops duplicate for ${lib_id}"
    fi
  done
}

create_zeta_donors() {
  local email="zara.zeta@crazy.example"
  local token
  token="$(user_token "${email}")"

  local idx
  for idx in 1 2; do
    local label name external
    printf -v label "%02d" "${idx}"
    name="Zeta Virtual Donor ${label}"
    external="zeta-${SCENARIO_TS}-${label}"
    local body
    body="$(jq -n \
      --arg type "${TYPE_SAMPLE}" \
      --arg name "${name}" \
      --arg ext "${external}" \
      --arg seed "${SEED_TAG}" \
      --arg scenario "${SCENARIO_KEY}" \
      --arg idx "${idx}" \
      --arg project "${PROJECT2_CODE}" \
      '{
        artefact_type_id: $type,
        name: $name,
        external_identifier: $ext,
        status: "active",
        is_virtual: true,
        metadata: {
          seed: $seed,
          scenario: $scenario,
          project_scope: $project,
          donor_index: ($idx|tonumber)
        }
      }')"

    local artefact_id
    artefact_id="$(new_uuid)"
    body="$(jq -n \
      --arg id "${artefact_id}" \
      --arg type "${TYPE_SAMPLE}" \
      --arg name "${name}" \
      --arg ext "${external}" \
      --arg seed "${SEED_TAG}" \
      --arg scenario "${SCENARIO_KEY}" \
      --arg idx "${idx}" \
      --arg project "${PROJECT2_CODE}" \
      '{
        artefact_id: $id,
        artefact_type_id: $type,
        name: $name,
        external_identifier: $ext,
        status: "active",
        is_virtual: true,
        metadata: {
          seed: $seed,
          scenario: $scenario,
          project_scope: $project,
          donor_index: ($idx|tonumber)
        }
      }')"

    request_postgrest "zeta donor ${label}" "${token}" "201" "POST" "/artefacts" "${body}" "" "app_provenance" "return=minimal"
    local scope_body
    scope_body="$(artefact_scope_body "${artefact_id}" "${PROJECT2_CODE}" "zeta donor")"
    request_postgrest "zeta donor scope ${label}" "${token}" "201" "POST" "/artefact_scopes" "${scope_body}" "" "app_provenance" "return=minimal"
  done
}

create_gamma_normalized() {
  local email="ollie.ops@crazy.example"
  local token
  token="$(user_token "${email}")"

  GAMMA_NORMALIZED_PLATE_ID="$(new_uuid)"
  local plate_body
  plate_body="$(jq -n \
    --arg id "${GAMMA_NORMALIZED_PLATE_ID}" \
    --arg type "${TYPE_PLATE}" \
    --arg seed "${SEED_TAG}" \
    --arg scenario "${SCENARIO_KEY}" \
    '{
      artefact_id: $id,
      artefact_type_id: $type,
      name: "Gamma Normalized Plate GNM1",
      external_identifier: "gamma-plate-gnm1-'${SCENARIO_TS}'",
      status: "active",
      metadata: {
        seed: $seed,
        scenario: $scenario,
        plate: "GNM1",
        barcode: "GNM1"
      }
    }')"

  request_postgrest "gamma normalized plate" "${token}" "201" "POST" "/artefacts" "${plate_body}" "" "app_provenance" "return=minimal"

  local scope_body
  scope_body="$(artefact_scope_body "${GAMMA_NORMALIZED_PLATE_ID}" "${OPS_QUANT_CODE}" "gamma normalized plate")"
  request_postgrest "gamma normalized plate scope" "${token}" "201" "POST" "/artefact_scopes" "${scope_body}" "" "app_provenance" "return=minimal"

  GAMMA_NORMALIZED_WELLS=()
  local idx=0
  for well in "${GAMMA_WELLS[@]}"; do
    idx=$((idx + 1))
    local src="${GAMMA_OPS_DUPLICATES[$((idx-1))]}"
    local norm_id
    norm_id="$(new_uuid)"
    local body
    body="$(jq -n \
      --arg id "${norm_id}" \
      --arg type "${TYPE_SAMPLE}" \
      --arg seed "${SEED_TAG}" \
      --arg scenario "${SCENARIO_KEY}" \
      --arg plate "${GAMMA_NORMALIZED_PLATE_ID}" \
      --arg well "${well}" \
      --arg scenets "${SCENARIO_TS}" \
      '{
        artefact_id: $id,
        artefact_type_id: $type,
        name: ("Gamma GNM1 " + $well),
        external_identifier: ("gamma-gnm1-" + ($well | ascii_downcase) + "-" + $scenets),
        status: "active",
        container_artefact_id: $plate,
        metadata: {
          seed: $seed,
          scenario: $scenario,
          plate: "GNM1",
          well_position: $well,
          normalised: true
        }
      }')"

    request_postgrest "gamma normalized well ${well}" "${token}" "201" "POST" "/artefacts" "${body}" "" "app_provenance" "return=minimal"
    GAMMA_NORMALIZED_WELLS+=("${norm_id}")

    local scope_json
    scope_json="$(artefact_scope_body "${norm_id}" "${OPS_QUANT_CODE}" "gamma normalized well")"
    request_postgrest "gamma normalized scope ${well}" "${token}" "201" "POST" "/artefact_scopes" "${scope_json}" "" "app_provenance" "return=minimal"

    local rel_json
    rel_json="$(relationship_body "${src}" "${norm_id}" "derived_from" "gamma-normalisation")"
    request_postgrest "gamma normalized link ${well}" "${token}" "201" "POST" "/artefact_relationships" "${rel_json}" "" "app_provenance" "return=minimal"
  done
}

create_gamma_pool() {
  local email="poppy.ops@crazy.example"
  local token
  token="$(user_token "${email}")"

  GAMMA_POOL_ID="$(new_uuid)"
  local body
  body="$(jq -n \
    --arg id "${GAMMA_POOL_ID}" \
    --arg type "${TYPE_POOL}" \
    --arg seed "${SEED_TAG}" \
    --arg scenario "${SCENARIO_KEY}" \
    '{
      artefact_id: $id,
      artefact_type_id: $type,
      name: "Gamma Pool Tube GPL1",
      external_identifier: "gamma-pool-gpl1-'${SCENARIO_TS}'",
      status: "active",
      metadata: {
        seed: $seed,
        scenario: $scenario,
        pool: "GPL1"
      }
    }')"

  request_postgrest "gamma pool GPL1" "${token}" "201" "POST" "/artefacts" "${body}" "" "app_provenance" "return=minimal"

  local scope_body
  scope_body="$(artefact_scope_body "${GAMMA_POOL_ID}" "${OPS_POOL_CODE}" "gamma pooling output")"
  request_postgrest "gamma pool scope" "${token}" "201" "POST" "/artefact_scopes" "${scope_body}" "" "app_provenance" "return=minimal"

  local input
  for input in "${GAMMA_NORMALIZED_WELLS[@]}"; do
    local rel_json
    rel_json="$(relationship_body "${input}" "${GAMMA_POOL_ID}" "pooled_input" "gamma-pooling")"
    request_postgrest "gamma pooled input ${input}" "${token}" "201" "POST" "/artefact_relationships" "${rel_json}" "" "app_provenance" "return=minimal"
  done
}

create_gamma_data_products() {
  local instrument_token
  instrument_token="$(user_token "instrument.gamma@crazy.example")"
  local ops_token
  ops_token="$(user_token "poppy.ops@crazy.example")"

  GAMMA_DATA_PRODUCTS_OPS=()
  local idx=0
  for _ in "${GAMMA_WELLS[@]}"; do
    idx=$((idx + 1))
    local label
    printf -v label "%03d" "${idx}"
    local dp_id
    dp_id="$(new_uuid)"
    local body
    body="$(jq -n \
      --arg id "${dp_id}" \
      --arg type "${TYPE_DATA}" \
      --arg seed "${SEED_TAG}" \
      --arg scenario "${SCENARIO_KEY}" \
      --arg label "${label}" \
      --arg scenets "${SCENARIO_TS}" \
      --arg idx "${idx}" \
      '{
        artefact_id: $id,
        artefact_type_id: $type,
        name: ("Gamma GPL1 Readset " + $label),
        external_identifier: ("gamma-gpl1-read-" + $label + "-" + $scenets),
        status: "active",
        metadata: {
          seed: $seed,
          scenario: $scenario,
          pool: "GPL1",
          readset_index: ($idx|tonumber)
        }
      }')"

    request_postgrest "gamma readset ${label}" "${instrument_token}" "201" "POST" "/artefacts" "${body}" "" "app_provenance" "return=minimal"
    GAMMA_DATA_PRODUCTS_OPS+=("${dp_id}")

    local scope_body
    scope_body="$(artefact_scope_body "${dp_id}" "${OPS_RUN_CODE}" "gamma ops readset")"
    request_postgrest "gamma readset scope ${label}" "${ops_token}" "201" "POST" "/artefact_scopes" "${scope_body}" "" "app_provenance" "return=minimal"

    local rel_json
    rel_json="$(relationship_body "${GAMMA_POOL_ID}" "${dp_id}" "produced_output" "gamma-sequencing")"
    request_postgrest "gamma readset link ${label}" "${ops_token}" "201" "POST" "/artefact_relationships" "${rel_json}" "" "app_provenance" "return=minimal"
  done
}

return_gamma_data_products() {
  local email="poppy.ops@crazy.example"
  local token
  token="$(user_token "${email}")"

  GAMMA_DATA_PRODUCTS_RESEARCH=()
  local dp_id
  for dp_id in "${GAMMA_DATA_PRODUCTS_OPS[@]}"; do
    local body
    body="$(jq -n \
      --arg artefact "${dp_id}" \
      --arg research_scope "$(get_scope_id "${PROJECT1_CODE}")" \
      '{
        p_ops_artefact_id: $artefact,
        p_research_scope_ids: [$research_scope]
      }')"

    request_postgrest "gamma return ${dp_id}" "${token}" "204" "POST" "/rpc/sp_return_from_ops" "${body}" "" "app_provenance" ""

    GAMMA_DATA_PRODUCTS_RESEARCH+=("${dp_id}")
  done
}

visibility_checks() {
  local gamma_virtual_token gamma_labtech_token zeta_token ops_token instrument_token
  gamma_virtual_token="$(user_token "gail.gamma@crazy.example")"
  gamma_labtech_token="$(user_token "ian.gamma@crazy.example")"
  zeta_token="$(user_token "zara.zeta@crazy.example")"
  ops_token="$(user_token "ollie.ops@crazy.example")"
  instrument_token="$(user_token "instrument.gamma@crazy.example")"

  local filter="metadata->>scenario=eq.${SCENARIO_KEY}"

  request_postgrest "gamma researcher sees gamma artefacts" "${gamma_virtual_token}" "200" "GET" "/artefacts?${filter}" "" 'length >= 6' "app_provenance"
  request_postgrest "gamma researcher cannot see zeta artefacts" "${gamma_virtual_token}" "200" "GET" "/artefacts?metadata->>project_scope=eq.${PROJECT2_CODE}" "" 'length == 0' "app_provenance"

  request_postgrest "zeta researcher sees zeta donors" "${zeta_token}" "200" "GET" "/artefacts?metadata->>project_scope=eq.${PROJECT2_CODE}" "" 'length >= 2' "app_provenance"
  request_postgrest "zeta researcher cannot see gamma libraries" "${zeta_token}" "200" "GET" "/artefacts?metadata->>plate=eq.GLB1" "" 'length == 0' "app_provenance"

  request_postgrest "ops tech sees ops duplicates" "${ops_token}" "200" "GET" "/artefacts?metadata->>handover_scope_key=eq.${OPS_LIB_CODE}" "" "length >= 2" "app_provenance"
  request_postgrest "ops tech cannot see gamma donors" "${ops_token}" "200" "GET" "/artefacts?metadata->>project_scope=eq.${PROJECT1_CODE}&is_virtual=is.true" "" 'length == 0' "app_provenance"

  request_postgrest "gamma labtech sees returned readsets" "${gamma_labtech_token}" "200" "GET" "/artefacts?name=ilike.Gamma%20GPL1%20Readset%25&metadata->>pool=eq.GPL1" "" 'length >= 2' "app_provenance"
  request_postgrest "instrument account limited view" "${instrument_token}" "200" "GET" "/artefacts?name=ilike.Gamma%20GPL1%20Readset%25" "" 'length >= 2' "app_provenance"
  request_postgrest "instrument cannot see donors" "${instrument_token}" "200" "GET" "/artefacts?metadata->>project_scope=eq.${PROJECT1_CODE}&is_virtual=is.true" "" 'length == 0' "app_provenance"
}

admin_setup() {
  local admin_id
  admin_id="$(admin_get_user_id "admin@example.org")"

  create_scope "${PROJECT1_CODE}" "project" "Project Gamma ${SCENARIO_TS}" ""
  create_scope "${PROJECT2_CODE}" "project" "Project Zeta ${SCENARIO_TS}" ""
  create_scope "${OPS_FACILITY_CODE}" "facility" "Ops Facility ${SCENARIO_TS}" ""
  create_scope "${OPS_LIB_CODE}" "ops" "Gamma Ops Library ${SCENARIO_TS}" "${OPS_FACILITY_CODE}"
  create_scope "${OPS_QUANT_CODE}" "ops" "Gamma Ops Quant ${SCENARIO_TS}" "${OPS_FACILITY_CODE}"
  create_scope "${OPS_POOL_CODE}" "ops" "Gamma Ops Pool ${SCENARIO_TS}" "${OPS_FACILITY_CODE}"
  create_scope "${OPS_RUN_CODE}" "ops" "Gamma Ops Run ${SCENARIO_TS}" "${OPS_FACILITY_CODE}"

  create_user "gail.gamma@crazy.example" "Gail Gamma" "app_researcher" "false"
  create_user "helen.gamma@crazy.example" "Helen Gamma" "app_researcher" "false"
  create_user "ian.gamma@crazy.example" "Ian Gamma" "app_researcher" "false"
  create_user "zara.zeta@crazy.example" "Zara Zeta" "app_researcher" "false"
  create_user "ollie.ops@crazy.example" "Ollie Ops" "app_operator" "false"
  create_user "poppy.ops@crazy.example" "Poppy Ops" "app_operator" "false"
  create_user "instrument.gamma@crazy.example" "Gamma Instrument" "app_automation" "true"

  grant_user_role "gail.gamma@crazy.example" "app_researcher" "${admin_id}"
  grant_user_role "helen.gamma@crazy.example" "app_researcher" "${admin_id}"
  grant_user_role "ian.gamma@crazy.example" "app_researcher" "${admin_id}"
  grant_user_role "zara.zeta@crazy.example" "app_researcher" "${admin_id}"
  grant_user_role "ollie.ops@crazy.example" "app_operator" "${admin_id}"
  grant_user_role "poppy.ops@crazy.example" "app_operator" "${admin_id}"
  grant_user_role "instrument.gamma@crazy.example" "app_automation" "${admin_id}"

  add_scope_membership "gail.gamma@crazy.example" "${PROJECT1_CODE}" "app_researcher"
  add_scope_membership "gail.gamma@crazy.example" "${PROJECT1_CODE}" "app_operator"
  add_scope_membership "helen.gamma@crazy.example" "${PROJECT1_CODE}" "app_researcher"
  add_scope_membership "helen.gamma@crazy.example" "${PROJECT1_CODE}" "app_operator"
  add_scope_membership "ian.gamma@crazy.example" "${PROJECT1_CODE}" "app_researcher"
  add_scope_membership "ian.gamma@crazy.example" "${PROJECT1_CODE}" "app_operator"
  add_scope_membership "zara.zeta@crazy.example" "${PROJECT2_CODE}" "app_researcher"
  add_scope_membership "ollie.ops@crazy.example" "${OPS_FACILITY_CODE}" "app_operator"
  add_scope_membership "poppy.ops@crazy.example" "${OPS_FACILITY_CODE}" "app_operator"
  add_scope_membership "poppy.ops@crazy.example" "${OPS_POOL_CODE}" "app_operator"
  add_scope_membership "poppy.ops@crazy.example" "${OPS_RUN_CODE}" "app_operator"
  add_scope_membership "poppy.ops@crazy.example" "${OPS_QUANT_CODE}" "app_operator"
  add_scope_membership "ollie.ops@crazy.example" "${OPS_QUANT_CODE}" "app_operator"
  add_scope_membership "ollie.ops@crazy.example" "${OPS_LIB_CODE}" "app_operator"
  add_scope_membership "ian.gamma@crazy.example" "${OPS_LIB_CODE}" "app_operator"
  add_scope_membership "instrument.gamma@crazy.example" "${OPS_RUN_CODE}" "app_automation"
}

main() {
  require_jq
  load_admin_token
  issue_story_tokens
  admin_setup
  lookup_type_ids

  create_gamma_donors
  create_gamma_plate
  create_gamma_fragment
  create_gamma_library
  handover_gamma_libraries
  create_zeta_donors
  create_gamma_normalized
  create_gamma_pool
  create_gamma_data_products
  return_gamma_data_products
  visibility_checks

  if (( failures > 0 )); then
    printf '\nREST story tests failed: %d issue(s)\n' "${failures}" >&2
    exit 1
  fi

  printf '\nREST story tests passed for scenario %s.\n' "${SCENARIO_KEY}"
}

main "$@"
