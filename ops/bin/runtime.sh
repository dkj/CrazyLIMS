#!/usr/bin/env bash
set -euo pipefail

# Cache Docker availability so repeated lookups are cheap.
_crazylims_docker_status=""

crazylims_docker_available() {
  if [[ -z "${_crazylims_docker_status}" ]]; then
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
      _crazylims_docker_status="yes"
    else
      _crazylims_docker_status="no"
    fi
  fi

  [[ "${_crazylims_docker_status}" == "yes" ]]
}

# Normalizes yes/no style values into 1/0. Returns 1 on invalid input.
crazylims_normalize_bool() {
  case "${1:-}" in
    1|[Yy][Ee][Ss]|[Yy]|[Tt][Rr][Uu][Ee]|[Oo][Nn])
      printf '1'
      ;;
    0|[Nn][Oo]|[Nn]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff])
      printf '0'
      ;;
    *)
      return 1
      ;;
  esac
}

# Normalizes docker/local runtime strings. Returns 1 on invalid input.
crazylims_normalize_runtime() {
  local value="${1:-}"
  if [[ -z "${value}" ]]; then
    return 1
  fi
  value="$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]')"
  case "${value}" in
    docker|local)
      printf '%s' "${value}"
      ;;
    *)
      return 1
      ;;
  esac
}

_crazylims_resolved_runtime=""

# Resolves the runtime (docker|local) honoring overrides when present.
crazylims_resolve_runtime() {
  if [[ -n "${_crazylims_resolved_runtime}" ]]; then
    printf '%s\n' "${_crazylims_resolved_runtime}"
    return
  fi

  local requested="" value legacy

  if [[ -n "${CRAZYLIMS_RUNTIME:-}" ]]; then
    if ! value="$(crazylims_normalize_runtime "${CRAZYLIMS_RUNTIME}")"; then
      echo "CRAZYLIMS_RUNTIME must be 'docker' or 'local'" >&2
      exit 1
    fi
    requested="${value}"
  fi

  if [[ -n "${USE_DOCKER:-}" ]]; then
    if ! value="$(crazylims_normalize_bool "${USE_DOCKER}")"; then
      echo "USE_DOCKER must be a boolean (yes/no/true/false/1/0)" >&2
      exit 1
    fi
    if [[ "${value}" == "1" ]]; then
      legacy="docker"
    else
      legacy="local"
    fi
    if [[ -n "${requested}" && "${requested}" != "${legacy}" ]]; then
      echo "CRAZYLIMS_RUNTIME and USE_DOCKER conflict" >&2
      exit 1
    fi
    requested="${legacy}"
  fi

  if [[ -z "${requested}" ]]; then
    if crazylims_docker_available; then
      requested="docker"
    else
      requested="local"
    fi
  fi

  if [[ "${requested}" == "docker" ]] && ! crazylims_docker_available; then
    echo "Docker runtime requested but Docker Compose v2 is not available" >&2
    exit 1
  fi

  _crazylims_resolved_runtime="${requested}"
  printf '%s\n' "${requested}"
}

crazylims_resolve_use_docker() {
  if [[ "$(crazylims_resolve_runtime)" == "docker" ]]; then
    printf 'yes\n'
  else
    printf 'no\n'
  fi
}

# Resolves the repository root on the host when running from a dev container.
crazylims_resolve_host_repo_root() {
  local repo_root="${1:-}"
  if [[ -z "${repo_root}" ]]; then
    echo "usage: crazylims_resolve_host_repo_root <repo_root>" >&2
    exit 1
  fi

  if [[ -n "${LOCAL_WORKSPACE_FOLDER:-}" ]]; then
    printf '%s\n' "${LOCAL_WORKSPACE_FOLDER}"
    return
  fi

  if ! crazylims_docker_available; then
    printf '%s\n' "${repo_root}"
    return
  fi

  local dev_id
  dev_id="$(docker compose ps -q dev 2>/dev/null | head -n1 || true)"
  if [[ -z "${dev_id}" ]]; then
    printf '%s\n' "${repo_root}"
    return
  fi

  local workspace_mount
  workspace_mount="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "${dev_id}" 2>/dev/null || true)"
  if [[ -n "${workspace_mount}" && "${repo_root}" == /workspace* ]]; then
    printf '%s\n' "${workspace_mount}${repo_root#/workspace}"
    return
  fi

  local direct_mount
  direct_mount="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "'"${repo_root}"'"}}{{.Source}}{{end}}{{end}}' "${dev_id}" 2>/dev/null || true)"
  if [[ -n "${direct_mount}" ]]; then
    printf '%s\n' "${direct_mount}"
    return
  fi

  printf '%s\n' "${repo_root}"
}

crazylims_runtime_cli() {
  case "${1:-}" in
    runtime)
      crazylims_resolve_runtime
      ;;
    use-docker)
      crazylims_resolve_use_docker
      ;;
    docker-available)
      if crazylims_docker_available; then
        exit 0
      fi
      exit 1
      ;;
    host-repo-root)
      shift
      crazylims_resolve_host_repo_root "$@"
      ;;
    "")
      echo "usage: $0 <runtime|use-docker|docker-available|host-repo-root>" >&2
      exit 1
      ;;
    *)
      echo "unknown command: ${1}" >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  crazylims_runtime_cli "$@"
fi
