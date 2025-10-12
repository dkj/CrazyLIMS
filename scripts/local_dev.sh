#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${ROOT_DIR}/.localdev"
BIN_DIR="${ROOT_DIR}/.local/bin"
LOG_DIR="${LOCAL_DIR}/logs"
PID_DIR="${LOCAL_DIR}/pids"
PGDATA="${LOCAL_DIR}/pgdata"

PGHOST="${PGHOST:-127.0.0.1}"
PG_PORT="${PG_PORT:-6432}"
PG_SUPERUSER="${PG_SUPERUSER:-postgres}"
PG_SUPERPASS="${PG_SUPERPASS:-postgres}"
PG_LISTEN="${PG_LISTEN:-127.0.0.1}"
POSTGREST_PORT="${POSTGREST_PORT:-3000}"
POSTGRAPHILE_PORT="${POSTGRAPHILE_PORT:-3001}"
JWT_SECRET="${PGRST_JWT_SECRET:-dev_jwt_secret_change_me_which_is_at_least_32_characters}"
POSTGRAPHILE_JWT_AUD="${POSTGRAPHILE_JWT_AUD:-lims-dev}"
POSTGRAPHILE_JWT_ISS="${POSTGRAPHILE_JWT_ISS:-dev-issuer}"
POSTGREST_VERSION="${POSTGREST_VERSION:-v13.0.7}"

POSTGREST_BIN="${BIN_DIR}/postgrest"
POSTGREST_PID_FILE="${PID_DIR}/postgrest.pid"
POSTGREST_CONFIG="${LOCAL_DIR}/postgrest.conf"
POSTGREST_LOG="${LOG_DIR}/postgrest.log"
POSTGRAPHILE_PID_FILE="${PID_DIR}/postgraphile.pid"
POSTGRAPHILE_LOG="${LOG_DIR}/postgraphile.log"
POSTGRES_LOG="${LOG_DIR}/postgres.log"

DATABASE_URL="postgres://${PG_SUPERUSER}:${PG_SUPERPASS}@${PGHOST}:${PG_PORT}/lims?sslmode=disable"
LOCAL_DB_PORT="${PG_PORT}"

PG_RUNTIME_USER="${PG_RUNTIME_USER:-}"
if [[ -z "${PG_RUNTIME_USER}" ]]; then
  if [[ $EUID -eq 0 ]]; then
    PG_RUNTIME_USER=postgres
  else
    PG_RUNTIME_USER="$(id -un)"
  fi
fi

ensure_dirs() {
  mkdir -p "${LOCAL_DIR}" "${BIN_DIR}" "${LOG_DIR}" "${PID_DIR}"
  if [[ $EUID -eq 0 ]]; then
    chown "${PG_RUNTIME_USER}:${PG_RUNTIME_USER}" "${LOG_DIR}" "${PID_DIR}" >/dev/null 2>&1 || true
    touch "${POSTGRES_LOG}"
    chown "${PG_RUNTIME_USER}:${PG_RUNTIME_USER}" "${POSTGRES_LOG}" >/dev/null 2>&1 || true
  fi
}

print_note() {
  printf '[local-dev] %s\n' "$1"
}

run_as_pg_user() {
  if [[ "$(id -un)" == "${PG_RUNTIME_USER}" ]]; then
    "$@"
    return
  fi

  if command -v runuser >/dev/null 2>&1; then
    runuser -u "${PG_RUNTIME_USER}" -- "$@"
  else
    local cmd
    cmd="$(printf '%q ' "$@")"
    su - "${PG_RUNTIME_USER}" -s /bin/sh -c "${cmd% }"
  fi
}

ensure_postgres_binaries() {
  local missing=0
  for tool in initdb pg_ctl pg_isready psql; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      missing=1
      break
    fi
  done

  if (( missing == 0 )); then
    discover_postgres_bin
    return
  fi

  if [[ ${LOCAL_DEV_SKIP_APT:-0} == 1 ]]; then
    echo "PostgreSQL client/server tools are required (initdb, pg_ctl, pg_isready, psql)." >&2
    echo "Install PostgreSQL 15+ and ensure those binaries are on PATH." >&2
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
    echo "PostgreSQL tools not found. Re-run with sudo or install PostgreSQL manually." >&2
    exit 1
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "PostgreSQL tools not found and automatic installation is unavailable." >&2
    echo "Install PostgreSQL 15+ using your package manager." >&2
    exit 1
  fi

  print_note "Installing PostgreSQL client/server packages via apt-get"
  apt-get update -y >/dev/null
  apt-get install -y postgresql postgresql-contrib >/dev/null

  discover_postgres_bin
}

discover_postgres_bin() {
  if command -v initdb >/dev/null 2>&1 && command -v pg_ctl >/dev/null 2>&1; then
    return
  fi

  for dir in /usr/lib/postgresql/*/bin; do
    if [[ -x "${dir}/initdb" && -x "${dir}/pg_ctl" ]]; then
      print_note "Using PostgreSQL binaries from ${dir}"
      PATH="${dir}:${PATH}"
      export PATH
      break
    fi
  done

  if ! command -v initdb >/dev/null 2>&1 || ! command -v pg_ctl >/dev/null 2>&1; then
    echo "PostgreSQL binaries not found on PATH. Ensure /usr/lib/postgresql/<version>/bin is exported." >&2
    exit 1
  fi
}

pg_initialized() {
  [[ -f "${PGDATA}/PG_VERSION" ]]
}

init_postgres() {
  ensure_dirs
  if pg_initialized; then
    return
  fi

  print_note "Initializing PostgreSQL data directory at ${PGDATA}"
  rm -rf "${PGDATA}"
  mkdir -p "${PGDATA}"
  if [[ $EUID -eq 0 ]]; then
    chown -R "${PG_RUNTIME_USER}:${PG_RUNTIME_USER}" "${PGDATA}"
  fi

  local pwfile
  pwfile="$(mktemp)"
  printf '%s\n' "${PG_SUPERPASS}" >"${pwfile}"
  chmod 600 "${pwfile}"
  if [[ $EUID -eq 0 ]]; then
    chown "${PG_RUNTIME_USER}:${PG_RUNTIME_USER}" "${pwfile}"
  fi

  run_as_pg_user initdb -D "${PGDATA}" -U "${PG_SUPERUSER}" -A scram-sha-256 --pwfile="${pwfile}" >/dev/null
  rm -f "${pwfile}"

  {
    printf "listen_addresses = '%s'\n" "${PG_LISTEN}"
    printf "port = %s\n" "${PG_PORT}"
    printf "shared_buffers = 128MB\n"
    printf "max_connections = 100\n"
  } >>"${PGDATA}/postgresql.conf"

  {
    printf "host    all             all             127.0.0.1/32            scram-sha-256\n"
    printf "host    all             all             ::1/128                 scram-sha-256\n"
  } >>"${PGDATA}/pg_hba.conf"
}

pg_running() {
  run_as_pg_user pg_ctl -D "${PGDATA}" status >/dev/null 2>&1
}

start_postgres() {
  ensure_postgres_binaries
  init_postgres

  if pg_running; then
    return
  fi

  print_note "Starting PostgreSQL on ${PG_LISTEN}:${PG_PORT}"
  run_as_pg_user pg_ctl -D "${PGDATA}" -l "${POSTGRES_LOG}" -w start >/dev/null
}

stop_postgres() {
  if pg_running; then
    print_note "Stopping PostgreSQL"
    run_as_pg_user pg_ctl -D "${PGDATA}" -m fast stop >/dev/null
  fi
}

wait_for_postgres() {
  print_note "Waiting for PostgreSQL to become ready"
  for _ in {1..60}; do
    if PGUSER="${PG_SUPERUSER}" PGPASSWORD="${PG_SUPERPASS}" pg_isready -h "${PGHOST}" -p "${PG_PORT}" >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done
  echo "Timed out waiting for PostgreSQL" >&2
  exit 1
}

ensure_dbmate() {
  DBMATE_MODE=local LOCAL_DB_PORT="${PG_PORT}" "${ROOT_DIR}/ops/db/bin/dbmate" --help >/dev/null 2>&1 || true
}

run_dbmate() {
  DBMATE_MODE=local LOCAL_DB_PORT="${PG_PORT}" DATABASE_URL="${DATABASE_URL}" "${ROOT_DIR}/ops/db/bin/dbmate" "$@"
}

ensure_database() {
  start_postgres
  wait_for_postgres
  ensure_dbmate
  print_note "Ensuring lims database exists and migrations are applied"
  if ! run_dbmate create >/dev/null 2>&1; then
    print_note "lims database already present"
  fi
  run_dbmate migrate
}

postgrest_download() {
  if [[ -x "${POSTGREST_BIN}" ]]; then
    return
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to download PostgREST" >&2
    exit 1
  fi

  local url="https://github.com/PostgREST/postgrest/releases/download/${POSTGREST_VERSION}/postgrest-${POSTGREST_VERSION}-linux-static-x86-64.tar.xz"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  print_note "Downloading PostgREST ${POSTGREST_VERSION}"
  if ! curl -fsSL "${url}" -o "${tmp_dir}/postgrest.tar.xz"; then
    echo "Failed to download PostgREST from ${url}" >&2
    rm -rf "${tmp_dir}"
    exit 1
  fi

  if ! tar -xJf "${tmp_dir}/postgrest.tar.xz" -C "${tmp_dir}" >/dev/null 2>&1; then
    echo "Failed to extract PostgREST archive" >&2
    rm -rf "${tmp_dir}"
    exit 1
  fi

  if [[ ! -f "${tmp_dir}/postgrest" ]]; then
    echo "Unexpected PostgREST archive contents" >&2
    rm -rf "${tmp_dir}"
    exit 1
  fi

  mv "${tmp_dir}/postgrest" "${POSTGREST_BIN}"
  chmod +x "${POSTGREST_BIN}"
  rm -rf "${tmp_dir}"
}

postgrest_running() {
  if [[ -f "${POSTGREST_PID_FILE}" ]]; then
    local pid
    pid="$(<"${POSTGREST_PID_FILE}")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

write_postgrest_config() {
  cat >"${POSTGREST_CONFIG}" <<CFG
db-uri = "postgres://postgrest_authenticator:postgrestpass@${PGHOST}:${PG_PORT}/lims"
db-schemas = "app_core,app_security,public"
db-anon-role = "web_anon"
db-pre-request = "app_security.pre_request"
jwt-secret = "${JWT_SECRET}"
openapi-server-proxy-uri = "http://127.0.0.1:${POSTGREST_PORT}"
server-host = "127.0.0.1"
server-port = ${POSTGREST_PORT}
CFG
}

start_postgrest() {
  ensure_dirs
  postgrest_download
  write_postgrest_config

  if postgrest_running; then
    return
  fi

  print_note "Starting PostgREST on http://127.0.0.1:${POSTGREST_PORT}"
  "${POSTGREST_BIN}" "${POSTGREST_CONFIG}" >"${POSTGREST_LOG}" 2>&1 &
  echo $! >"${POSTGREST_PID_FILE}"
  sleep 1
}

stop_postgrest() {
  if postgrest_running; then
    local pid
    pid="$(<"${POSTGREST_PID_FILE}")"
    print_note "Stopping PostgREST"
    kill "${pid}" >/dev/null 2>&1 || true
    wait "${pid}" 2>/dev/null || true
  fi
  rm -f "${POSTGREST_PID_FILE}"
}

postgraphile_running() {
  if [[ -f "${POSTGRAPHILE_PID_FILE}" ]]; then
    local pid
    pid="$(<"${POSTGRAPHILE_PID_FILE}")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

ensure_postgraphile_dependencies() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "npm is required to run PostGraphile" >&2
    exit 1
  fi
  (cd "${ROOT_DIR}/ops/postgraphile" && npm install --no-package-lock >/dev/null)
}

start_postgraphile() {
  ensure_postgraphile_dependencies

  if postgraphile_running; then
    return
  fi

  print_note "Starting PostGraphile on http://127.0.0.1:${POSTGRAPHILE_PORT}"
  (
    cd "${ROOT_DIR}/ops/postgraphile"
    POSTGRAPHILE_DB_URI="postgres://postgraphile_authenticator:postgraphilepass@${PGHOST}:${PG_PORT}/lims" \
    POSTGRAPHILE_SCHEMAS="app_core" \
    POSTGRAPHILE_DEFAULT_ROLE="web_anon" \
    POSTGRAPHILE_JWT_SECRET="${JWT_SECRET}" \
    POSTGRAPHILE_JWT_AUD="${POSTGRAPHILE_JWT_AUD}" \
    POSTGRAPHILE_JWT_ISS="${POSTGRAPHILE_JWT_ISS}" \
    POSTGRAPHILE_PORT="${POSTGRAPHILE_PORT}" \
    POSTGRAPHILE_OWNER_CONNECTION="postgres://${PG_SUPERUSER}:${PG_SUPERPASS}@${PGHOST}:${PG_PORT}/lims" \
    node server.js >"${POSTGRAPHILE_LOG}" 2>&1 &
    echo $! >"${POSTGRAPHILE_PID_FILE}"
  )
  sleep 1
}

stop_postgraphile() {
  if postgraphile_running; then
    local pid
    pid="$(<"${POSTGRAPHILE_PID_FILE}")"
    print_note "Stopping PostGraphile"
    kill "${pid}" >/dev/null 2>&1 || true
    wait "${pid}" 2>/dev/null || true
  fi
  rm -f "${POSTGRAPHILE_PID_FILE}"
}

start_services() {
  ensure_dirs
  ensure_database
  start_postgrest
  start_postgraphile
  print_note "Services are ready"
}

stop_services() {
  stop_postgraphile
  stop_postgrest
  stop_postgres
}

status_services() {
  if pg_running; then
    print_note "PostgreSQL running (port ${PG_PORT})"
  else
    print_note "PostgreSQL stopped"
  fi

  if postgrest_running; then
    print_note "PostgREST running (port ${POSTGREST_PORT})"
  else
    print_note "PostgREST stopped"
  fi

  if postgraphile_running; then
    print_note "PostGraphile running (port ${POSTGRAPHILE_PORT})"
  else
    print_note "PostGraphile stopped"
  fi
}

reset_environment() {
  stop_services
  rm -rf "${PGDATA}" "${POSTGREST_CONFIG}"
  print_note "Local environment reset"
}

psql_dev() {
  ensure_database
  PGPASSWORD="devpass" psql -h "${PGHOST}" -p "${PG_PORT}" -U dev -d lims "$@"
}

tail_logs() {
  ensure_dirs
  touch "${POSTGRES_LOG}" "${POSTGREST_LOG}" "${POSTGRAPHILE_LOG}"
  print_note "Tailing local logs (press Ctrl+C to stop)"
  tail -n 100 -F "${POSTGRES_LOG}" "${POSTGREST_LOG}" "${POSTGRAPHILE_LOG}"
}

usage() {
  cat <<USAGE
Usage: ${0##*/} <command>

Commands:
  up|start       Start PostgreSQL, PostgREST, and PostGraphile locally
  ensure         Same as start (kept for compatibility)
  down|stop      Stop all local services
  status         Show status of local services
  reset          Stop services and remove the local database directory
  migrate        Run database migrations using dbmate
  psql [args]    Open a psql shell authenticated as dev
  logs           Tail service logs for Postgres/PostgREST/PostGraphile
USAGE
}

command="${1:-}"; shift || true
case "${command}" in
  up|start|ensure)
    start_services
    ;;
  down|stop)
    stop_services
    ;;
  status)
    status_services
    ;;
  reset)
    reset_environment
    ;;
  migrate)
    ensure_database
    run_dbmate migrate
    ;;
  psql)
    psql_dev "$@"
    ;;
  logs)
    tail_logs
    ;;
  "")
    usage
    exit 1
    ;;
  *)
    echo "Unknown command: ${command}" >&2
    usage
    exit 1
    ;;
esac
