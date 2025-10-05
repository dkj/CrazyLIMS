#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JWT_DIR="${ROOT_DIR}/ops/examples/jwts"
POSTGREST_URL="${POSTGREST_URL:-http://localhost:3000}"
POSTGRAPHILE_URL="${POSTGRAPHILE_URL:-http://localhost:3001/graphql}"

failures=0
PROJECT_PRJ001=""
PROJECT_PRJ003=""

log_success() {
  printf '✅ %s\n' "$1" >&2
}

log_failure() {
  printf '❌ %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for RBAC smoke tests" >&2
    exit 1
  fi
}

request_postgrest() {
  local persona="$1" token_file="$2" expected_status="$3" method="$4" path="$5" body="$6" jq_expr="$7"
  local token body_json status

  token="$(<"${JWT_DIR}/${token_file}")"
  if [[ -n "${body}" ]]; then
    body_json="$(curl -sS --retry 12 --retry-delay 1 --retry-all-errors -w '\n%{http_code}' -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" -X "${method}" "${POSTGREST_URL}${path}" -d "${body}" || true)"
  else
    body_json="$(curl -sS --retry 12 --retry-delay 1 --retry-all-errors -w '\n%{http_code}' -H "Authorization: Bearer ${token}" -X "${method}" "${POSTGREST_URL}${path}" || true)"
  fi
  status="${body_json##*$'\n'}"
  body_json="${body_json%$'\n'*}"

  if [[ "${status}" != "${expected_status}" ]]; then
    log_failure "PostgREST ${persona} ${method} ${path} expected ${expected_status} got ${status}"
    return
  fi

  if [[ -n "${jq_expr}" ]]; then
    if ! echo "${body_json}" | jq -e "${jq_expr}" >/dev/null 2>&1; then
      log_failure "PostgREST ${persona} ${method} ${path} body check failed"
      return
    fi
  fi

  log_success "PostgREST ${persona} ${method} ${path} ${status}"
}

request_graphql() {
  local persona="$1" token_file="$2" expected_status="$3" query="$4" expect_errors="$5" jq_expr="$6"
  local token response status body_json

  token="$(<"${JWT_DIR}/${token_file}")"
  response="$(curl -sS --retry 12 --retry-delay 1 --retry-all-errors -w '\n%{http_code}' -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" "${POSTGRAPHILE_URL}" -d "${query}" || true)"
  status="${response##*$'\n'}"
  body_json="${response%$'\n'*}"

  if [[ "${status}" != "${expected_status}" ]]; then
    log_failure "GraphQL ${persona} expected ${expected_status} got ${status}"
    return
  fi

  if [[ "${expect_errors}" == "true" ]]; then
    if ! echo "${body_json}" | jq -e '.errors | length > 0' >/dev/null 2>&1; then
      log_failure "GraphQL ${persona} expected authorization errors"
      return
    fi
  else
    if ! echo "${body_json}" | jq -e '(.errors // []) | length == 0' >/dev/null 2>&1; then
      log_failure "GraphQL ${persona} unexpected errors"
      return
    fi
    if [[ -n "${jq_expr}" ]]; then
      if ! echo "${body_json}" | jq -e "${jq_expr}" >/dev/null 2>&1; then
        log_failure "GraphQL ${persona} data check failed"
        return
      fi
    fi
  fi

  log_success "GraphQL ${persona} status ${status}"
}

fetch_project_id() {
  local code="$1" token="$2" project_id

  project_id="$(curl -sS -H "Authorization: Bearer ${token}" "${POSTGREST_URL}/projects?select=id&project_code=eq.${code}" | jq -r '.[0].id // empty')"

  if [[ -z "${project_id}" ]]; then
    echo "Failed to resolve project id for ${code}" >&2
    exit 1
  fi

  printf '%s' "${project_id}"
}

main() {
  require_jq

  if [[ ! -d "${JWT_DIR}" ]]; then
    printf 'JWT fixtures not found in %s. Run make jwt/dev first.\n' "${JWT_DIR}" >&2
    exit 1
  fi

  local admin_token
  admin_token="$(<"${JWT_DIR}/admin.jwt")"
  PROJECT_PRJ001="$(fetch_project_id "PRJ-001" "${admin_token}")"
  PROJECT_PRJ003="$(fetch_project_id "PRJ-003" "${admin_token}")"

  request_postgrest "admin" "admin.jwt" "200" "GET" "/users" '' 'length > 0'
  request_postgrest "operator" "operator.jwt" "200" "GET" "/users" '' 'length > 0'
  request_postgrest "researcher" "researcher.jwt" "200" "GET" "/users" '' 'length <= 1 and (length == 0 or .[0].email == "alice@example.org")'
  request_postgrest "admin" "admin.jwt" "200" "GET" "/v_sample_overview" '' 'length > 0'
  request_postgrest "researcher" "researcher.jwt" "200" "GET" "/v_sample_overview?select=name" '' 'map(.name) | sort == ["PBMC Aliquot A","PBMC Batch 001","Serum Plate Control","Serum Tube A"]'
  request_postgrest "researcher-bob" "researcher_bob.jwt" "200" "GET" "/v_sample_overview?select=name" '' 'map(.name) == ["Neutralizing Panel B"]'
  request_postgrest "researcher-projects" "researcher.jwt" "200" "GET" "/projects?select=project_code" '' 'map(.project_code) | sort == ["PRJ-001","PRJ-002"]'
  request_postgrest "researcher-bob-projects" "researcher_bob.jwt" "200" "GET" "/projects?select=project_code" '' 'map(.project_code) == ["PRJ-003"]'
  request_postgrest "researcher-inventory" "researcher.jwt" "403" "GET" "/inventory_items" '' ''

  request_postgrest "operator-create" "operator.jwt" "201" "POST" "/samples" '{"name":"Automation Smoke","sample_type":"test","project_code":"PRJ-TEST"}' ''
  request_postgrest "researcher-create" "researcher.jwt" "403" "POST" "/samples" '{"name":"Researcher Fail","sample_type":"test"}' ''

  request_graphql "admin" "admin.jwt" "200" '{"query":"query{ allUsers(first:10){ nodes { email } } }"}' false '.data.allUsers.nodes | length > 0'
  request_graphql "researcher" "researcher.jwt" "200" '{"query":"query{ allUsers(first:10){ nodes { email } } }"}' false '.data.allUsers.nodes | length == 1 and .[0].email == "alice@example.org"'
  request_graphql "operator" "operator.jwt" "200" '{"query":"query{ allSamples(first:5){ nodes { name } } }"}' false '.data.allSamples.nodes | length > 0'

  local operator_mutation researcher_mutation
  operator_mutation="$(jq -n \
    --arg query 'mutation($projectId: UUID!){ createSample(input:{sample:{name:"GraphQL Smoke", sampleType:"test", projectId:$projectId, projectCode:"PRJ-001"}}){ sample { name projectId } }}' \
    --arg pid "${PROJECT_PRJ001}" \
    '{query:$query, variables:{projectId:$pid}}')"
  request_graphql "operator-mutate" "operator.jwt" "200" "${operator_mutation}" false '.data.createSample.sample.name == "GraphQL Smoke"'

  researcher_mutation="$(jq -n \
    --arg query 'mutation($projectId: UUID!){ createSample(input:{sample:{name:"GraphQL Denied", sampleType:"test", projectId:$projectId, projectCode:"PRJ-003"}}){ sample { name } }}' \
    --arg pid "${PROJECT_PRJ003}" \
    '{query:$query, variables:{projectId:$pid}}')"
  request_graphql "researcher-mutate" "researcher.jwt" "200" "${researcher_mutation}" true ''

  if [[ ${failures} -gt 0 ]]; then
    printf '\nRBAC smoke tests failed: %d issues\n' "${failures}" >&2
    exit 1
  fi

  printf '\nRBAC smoke tests passed.\n'
}

main "$@"
