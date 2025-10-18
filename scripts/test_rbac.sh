#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PSQL_COMMAND_OVERRIDE="${PSQL_CMD:-}"
unset PSQL_CMD
declare -a PSQL_CMD

if [[ -n "${PSQL_COMMAND_OVERRIDE}" ]]; then
  # shellcheck disable=SC2206
  PSQL_CMD=(${PSQL_COMMAND_OVERRIDE})
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  PSQL_CMD=(docker compose exec -T db psql -U dev -d lims)
else
  DB_HOST="${DB_HOST:-127.0.0.1}"
  DB_PORT="${DB_PORT:-6432}"
  DB_APP_USER="${DB_APP_USER:-dev}"
  DB_APP_PASSWORD="${DB_APP_PASSWORD:-devpass}"
  DB_NAME="${DB_NAME:-lims}"
  export PGPASSWORD="${PGPASSWORD:-${DB_APP_PASSWORD}}"
  PSQL_CMD=(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_APP_USER}" -d "${DB_NAME}")
fi
JWT_DIR="${ROOT_DIR}/ops/examples/jwts"
# Default to Docker service hostnames inside devcontainer; caller can override.
POSTGREST_URL="${POSTGREST_URL:-http://postgrest:3000}"
POSTGRAPHILE_URL="${POSTGRAPHILE_URL:-http://postgraphile:3001/graphql}"

failures=0
last_body=""
last_status=""

auth_log_success() {
  printf '✅ %s\n' "$1" >&2
}

auth_log_failure() {
  printf '❌ %s\n' "$1" >&2
}

record_failure() {
  auth_log_failure "$1"
  failures=$((failures + 1))
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for RBAC smoke tests" >&2
    exit 1
  fi
}

run_sql() {
  local label="$1" sql="$2"
  if printf '%s\n' "$sql" | "${PSQL_CMD[@]}" -v ON_ERROR_STOP=1 -q >/dev/null; then
    auth_log_success "$label"
  else
    record_failure "$label"
  fi
}

request_postgrest() {
  local label="$1" token_file="$2" expected_status="$3" method="$4" path="$5" body="$6" jq_expr="$7"
  local token url response status body_json

  token="$(<"${JWT_DIR}/${token_file}")"
  url="${POSTGREST_URL}${path}"
  local -a curl_args=(-sS --retry 5 --retry-delay 1 --retry-all-errors -w '\n%{http_code}' -H "Authorization: Bearer ${token}" -X "$method")

  if [[ "$method" == "POST" || "$method" == "PATCH" ]]; then
    curl_args+=(-H "Prefer: return=representation")
  fi

  if [[ -n "$body" ]]; then
    curl_args+=(-H "Content-Type: application/json" -d "$body")
  fi

  curl_args+=("$url")
  response="$(curl "${curl_args[@]}" || true)"

  status="${response##*$'\n'}"
  body_json="${response%$'\n'*}"
  last_status="$status"
  last_body="$body_json"

  if [[ "$status" != "$expected_status" ]]; then
    record_failure "$label (expected ${expected_status}, got ${status})"
    return
  fi

  if [[ -n "$jq_expr" ]]; then
    if ! echo "$body_json" | jq -e "$jq_expr" >/dev/null 2>&1; then
      record_failure "$label body check failed"
      return
    fi
  fi

  auth_log_success "$label"
}

request_graphql() {
  local label="$1" token_file="$2" expected_status="$3" payload="$4" expect_errors="$5" jq_expr="$6"
  local token response status body_json

  token="$(<"${JWT_DIR}/${token_file}")"
  response="$(curl -sS --retry 5 --retry-delay 1 --retry-all-errors -w '\n%{http_code}' -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" "$POSTGRAPHILE_URL" -d "$payload" || true)"
  status="${response##*$'\n'}"
  body_json="${response%$'\n'*}"
  last_status="$status"
  last_body="$body_json"

  if [[ "$status" != "$expected_status" ]]; then
    record_failure "$label (expected ${expected_status}, got ${status})"
    return
  fi

  if [[ "$expect_errors" == "true" ]]; then
    if ! echo "$body_json" | jq -e '.errors | length > 0' >/dev/null 2>&1; then
      record_failure "$label expected GraphQL errors"
      return
    fi
  else
    if ! echo "$body_json" | jq -e '(.errors // []) | length == 0' >/dev/null 2>&1; then
      record_failure "$label unexpected GraphQL errors"
      return
    fi
    if [[ -n "$jq_expr" ]]; then
      if ! echo "$body_json" | jq -e "$jq_expr" >/dev/null 2>&1; then
        record_failure "$label body check failed"
        return
      fi
    fi
  fi

  auth_log_success "$label"
}

admin_transaction_smoke() {
  run_sql "admin transaction context" "$(cat <<'SQL'
RESET ROLE;
SET ROLE app_admin;
DO $$
DECLARE
  v_txn uuid;
  v_user_id uuid;
  v_email text := format('cli-%s@example.org', substr(gen_random_uuid()::text, 1, 8));
  v_audit_count integer;
BEGIN
  v_txn := app_security.start_transaction_context(
    p_actor_id => (SELECT id FROM app_core.users WHERE email = 'admin@example.org'),
    p_actor_identity => 'cli-admin',
    p_effective_roles => ARRAY['app_admin'],
    p_client_app => 'rbac-smoke'
  );

  INSERT INTO app_core.users (external_id, email, full_name, default_role)
  VALUES ('urn:cli:' || v_email, v_email, 'CLI Admin Smoke', 'app_researcher')
  RETURNING id INTO v_user_id;

  UPDATE app_core.users
  SET full_name = 'CLI Admin Smoke Updated'
  WHERE id = v_user_id;

  DELETE FROM app_core.users WHERE id = v_user_id;

  SELECT count(*) INTO v_audit_count
  FROM app_security.audit_log
  WHERE txn_id = v_txn AND table_name = 'users';

  IF v_audit_count <> 3 THEN
    RAISE EXCEPTION 'Expected 3 audit rows, saw %', v_audit_count;
  END IF;

  PERFORM app_security.finish_transaction_context(v_txn, 'committed', 'cli smoke');
END;
$$;
RESET ROLE;
SQL
)"
}

researcher_rls_smoke() {
  run_sql "researcher rls guard rails" "$(cat <<'SQL'
RESET ROLE;
SET ROLE app_admin;
SELECT set_config('session.alice_id', (SELECT id::text FROM app_core.users WHERE email = 'alice@example.org'), false);
RESET ROLE;
SET ROLE app_researcher;
DO $$
DECLARE
  v_self_id uuid := current_setting('session.alice_id', false)::uuid;
  v_count integer;
BEGIN
  EXECUTE format('SET app.actor_id = %L', v_self_id::text);
  EXECUTE format('SET app.roles = %L', 'app_researcher');

  SELECT count(*) INTO v_count FROM app_core.users;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Researcher should only see self, saw %', v_count;
  END IF;

  BEGIN
    INSERT INTO app_core.users (email, full_name, default_role) VALUES ('fail@example.org', 'Fail', 'app_researcher');
    RAISE EXCEPTION 'Researcher should not insert users';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM NOT LIKE '%permission denied%' AND SQLERRM NOT LIKE '%violates row-level security%' THEN
        RAISE;
      END IF;
  END;
END;
$$;
RESET ROLE;
SQL
)"
}

rest_smoke_tests() {
  local admin_payload operator_check researcher_check external_check automation_check
  local rest_email="rest-admin-$(date +%s%N)@example.org"
  local rest_payload
  rest_payload="$(jq -n --arg email "$rest_email" '{email:$email, full_name:"REST Admin Smoke", default_role:"app_researcher"}')"

  request_postgrest "admin GET /users" admin.jwt 200 GET "/users?select=email" "" 'length >= 4'
  request_postgrest "operator GET /users" operator.jwt 200 GET "/users?select=email" "" 'length == 1 and .[0].email == "ops@example.org"'
  request_postgrest "researcher GET /users" researcher.jwt 200 GET "/users?select=email" "" 'length == 1 and .[0].email == "alice@example.org"'
  request_postgrest "external GET /users" external.jwt 200 GET "/users?select=email" "" 'length == 1 and .[0].email == "external@example.org"'
  request_postgrest "automation GET /users" automation.jwt 200 GET "/users?select=email" "" 'length == 1 and .[0].email == "automation@example.org"'

  request_postgrest "admin POST /users" admin.jwt 201 POST "/users" "$rest_payload" ".[0].email == \"$rest_email\""
  local rest_user_id
  rest_user_id="$(echo "$last_body" | jq -r '.[0].id')"
  if [[ -n "$rest_user_id" && "$rest_user_id" != "null" ]]; then
    request_postgrest "admin DELETE /users" admin.jwt 204 DELETE "/users?id=eq.${rest_user_id}" "" ""
  else
    record_failure "admin POST /users missing id"
  fi

  local deny_email="rest-denied-$(date +%s%N)@example.org"
  local deny_payload
  deny_payload="$(jq -n --arg email "$deny_email" '{email:$email, full_name:"Denied", default_role:"app_researcher"}')"

  request_postgrest "operator POST /users denied" operator.jwt 403 POST "/users" "$deny_payload" ""
  request_postgrest "researcher POST /users denied" researcher.jwt 403 POST "/users" "$deny_payload" ""
  request_postgrest "external POST /users denied" external.jwt 403 POST "/users" "$deny_payload" ""
  request_postgrest "automation POST /users denied" automation.jwt 403 POST "/users" "$deny_payload" ""
}

graphql_smoke_tests() {
  local query_admin query_operator query_researcher query_external query_automation

  query_admin='{"query":"query { allUsers(first:20) { nodes { email } } }"}'
  request_graphql "admin GraphQL allUsers" admin.jwt 200 "$query_admin" false '.data.allUsers.nodes | length >= 4'

  query_operator='{"query":"query { allUsers(first:5) { nodes { email } } }"}'
  request_graphql "operator GraphQL allUsers" operator.jwt 200 "$query_operator" false '.data.allUsers.nodes | length == 1 and .[0].email == "ops@example.org"'

  query_researcher='{"query":"query { allUsers(first:5) { nodes { email } } }"}'
  request_graphql "researcher GraphQL allUsers" researcher.jwt 200 "$query_researcher" false '.data.allUsers.nodes | length == 1 and .[0].email == "alice@example.org"'

  query_external='{"query":"query { allUsers(first:5) { nodes { email } } }"}'
  request_graphql "external GraphQL allUsers" external.jwt 200 "$query_external" false '.data.allUsers.nodes | length == 1 and .[0].email == "external@example.org"'

  query_automation='{"query":"query { allUsers(first:5) { nodes { email } } }"}'
  request_graphql "automation GraphQL allUsers" automation.jwt 200 "$query_automation" false '.data.allUsers.nodes | length == 1 and .[0].email == "automation@example.org"'

  local gql_email="graphql-admin-$(date +%s%N)@example.org"
  local mutation
  mutation="$(jq -n --arg query 'mutation($email: String!, $fullName: String!){ createUser(input:{user:{email:$email, fullName:$fullName, defaultRole:"app_researcher"}}){ user { id email } }}' --arg email "$gql_email" --arg fullName "GraphQL Admin Smoke" '{query:$query, variables:{email:$email, fullName:$fullName}}')"
  request_graphql "admin GraphQL createUser" admin.jwt 200 "$mutation" false ".data.createUser.user.email == \"$gql_email\""
  local gql_user_id
  gql_user_id="$(echo "$last_body" | jq -r '.data.createUser.user.id')"
  if [[ -n "$gql_user_id" && "$gql_user_id" != "null" ]]; then
    local delete_mutation
    delete_mutation="$(jq -n --arg query 'mutation($id: UUID!){ deleteUserById(input:{id:$id}){ deletedUserId }}' --arg id "$gql_user_id" '{query:$query, variables:{id:$id}}')"
    request_graphql "admin GraphQL deleteUser" admin.jwt 200 "$delete_mutation" false '.data.deleteUserById.deletedUserId != null'
  else
    record_failure "admin GraphQL createUser missing id"
  fi

  local denied_email="graphql-denied-$(date +%s%N)@example.org"
  local denied_mutation
  denied_mutation="$(jq -n --arg query 'mutation($email: String!, $fullName: String!){ createUser(input:{user:{email:$email, fullName:$fullName, defaultRole:"app_researcher"}}){ user { id email } }}' --arg email "$denied_email" --arg fullName "GraphQL Denied" '{query:$query, variables:{email:$email, fullName:$fullName}}')"
  request_graphql "researcher GraphQL createUser denied" researcher.jwt 200 "$denied_mutation" true ''
}

main() {
  require_jq
  admin_transaction_smoke
  researcher_rls_smoke
  rest_smoke_tests

  graphql_smoke_tests

  if (( failures > 0 )); then
    printf '\nSecurity smoke checks failed: %d issue(s)\n' "$failures" >&2
    exit 1
  fi

  request_postgrest "admin" "admin.jwt" "200" "GET" "/users" '' 'length > 0'
  request_postgrest "operator" "operator.jwt" "200" "GET" "/users" '' 'length > 0'
  request_postgrest "researcher" "researcher.jwt" "200" "GET" "/users" '' 'length <= 1 and (length == 0 or .[0].email == "alice@example.org")'
  request_postgrest "admin" "admin.jwt" "200" "GET" "/v_sample_overview" '' 'length > 0'
  request_postgrest "researcher" "researcher.jwt" "200" "GET" "/v_sample_overview?select=name" '' '([.[] | .name] | (index("Organoid Expansion Batch RDX-01") != null and index("PBMC Batch 001") != null))'
  request_postgrest "researcher-bob" "researcher_bob.jwt" "200" "GET" "/v_sample_overview?select=name" '' '([.[] | .name] | index("Neutralizing Panel B") != null)'
  request_postgrest "researcher-labware" "researcher.jwt" "200" "GET" "/v_labware_inventory?select=barcode" '' 'map(.barcode) | sort == ["PLATE-0001","PLATE-DNA-0001","PLATE-DNA-0002","PLATE-LIB-0001","POOL-SEQ-0001","TUBE-0001"]'
  request_postgrest "researcher-bob-labware" "researcher_bob.jwt" "200" "GET" "/v_labware_inventory?select=barcode" '' '([.[] | .barcode] | index("TUBE-0002") != null)'
  request_postgrest "researcher-projects" "researcher.jwt" "200" "GET" "/v_project_access_overview?select=project_code" '' '([.[] | .project_code | ascii_upcase] | (index("PRJ-001") != null and index("PRJ-002") != null))'
  request_postgrest "researcher-bob-projects" "researcher_bob.jwt" "200" "GET" "/v_project_access_overview?select=project_code,access_via" '' '([.[] | select((.project_code | ascii_upcase) == "PRJ-003" and .access_via == "direct")] | length) >= 1'
  request_postgrest "researcher-project-summary" "researcher.jwt" "200" "GET" "/v_project_access_overview?select=project_code,access_via,sample_count&order=project_code" '' '((all(.[]; .access_via == "direct")) and ([.[] | .project_code | ascii_upcase] | (index("PRJ-001") != null and index("PRJ-002") != null)))'
  request_postgrest "researcher-bob-project-summary" "researcher_bob.jwt" "200" "GET" "/v_project_access_overview?select=project_code,access_via,sample_count" '' '([.[] | select((.project_code | ascii_upcase) == "PRJ-003" and .access_via == "direct")] | length) >= 1'
  request_postgrest "researcher-storage" "researcher.jwt" "200" "GET" "/v_storage_tree?select=sublocation_name" '' '([.[] | .sublocation_name] | index("Shelf 1") != null)'
  request_postgrest "researcher-bob-storage" "researcher_bob.jwt" "200" "GET" "/v_storage_tree?select=sublocation_name" '' '([.[] | .sublocation_name] | index("Shelf 1") != null)'

  if [[ ${failures} -gt 0 ]]; then
    printf '\nRBAC smoke tests failed: %d issues\n' "${failures}" >&2
    exit 1
  fi

  printf '\nRBAC smoke tests passed.\n'
}

main "$@"
