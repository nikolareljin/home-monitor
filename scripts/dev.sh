#!/usr/bin/env bash
# SCRIPT: dev.sh
# DESCRIPTION: Host helper for building, running, and inspecting the Home Monitor Docker stack.
# USAGE: ./scripts/dev.sh <command> [options]
# PARAMETERS:
#   command: up|down|build|status|logs|test-backend|shell|help
# EXAMPLE: ./scripts/dev.sh up --no-build
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$SCRIPT_DIR/script-helpers}"

# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging docker env browser help ollama_endpoint

init_include

usage() {
  show_help "$0"
  cat <<'EOF'

Commands:
 up [--no-build] [--attach] [service...]   Build (unless --no-build) and start the stack
 down [args...]                            Stop containers (passes args to docker compose down)
 build [service...]                        Build images
 status                                    Show Docker engine + compose service status
 logs [service]                            Tail logs (all services by default)
 test-backend [args...]                    Run Django tests via docker compose run
 shell [service] [shell]                   Open a shell inside a service (default: backend/bash)
 help                                      Show this help text

Flags:
 -h, --help                                Show this help text
EOF
}

ensure_prereqs() {
  # Hide the default helper error so we can print a more actionable message
  if ! check_docker >/dev/null 2>&1; then
    if ! command -v docker >/dev/null 2>&1; then
      log_error "Docker CLI not found. Install Docker (Desktop/Engine) and retry."
      exit 1
    fi
    local info_out
    info_out=$(docker info 2>&1 || true)
    if echo "$info_out" | grep -Eiq "permission denied|operation not permitted"; then
      log_error "Docker is installed but current user cannot talk to the daemon."
      log_info "On Linux, add your user to the docker group: sudo usermod -aG docker \"$USER\" && newgrp docker"
    else
      log_error "Docker daemon is not running or not accessible."
      log_info "Start Docker Desktop/Engine (or colima/podman socket) and rerun the command."
    fi
    exit 1
  fi
  check_project_root
}

# Checks the machine's Ollama before the stack starts: it has the model
# ai-models.env names (a value in .env wins), and the backend container can
# reach it. A missing model is listed with its size and pulled after a yes;
# with no terminal the start stops and names the pull. A failed check stops
# the start: a dashboard whose advice silently falls back to heuristics looks
# like it works. HOME_MONITOR_SKIP_OLLAMA=1 skips it.
check_ollama() {
  local root url chosen default
  if [[ "${HOME_MONITOR_SKIP_OLLAMA:-}" == "1" ]]; then
    log_info "Skipping the Ollama check (HOME_MONITOR_SKIP_OLLAMA=1)."
    return 0
  fi
  root="$(cd "$SCRIPT_DIR/.." && pwd)"
  # The address the backend container is given (OLLAMA_BASE_URL_DOCKER in
  # .env); the library reads host.docker.internal on the host as this machine.
  url="${OLLAMA_BASE_URL_DOCKER:-}"
  [[ -n "$url" ]] || url="$(ollama_models_file_get "$root/.env" OLLAMA_BASE_URL_DOCKER 2>/dev/null)" || url=""
  url="${url:-http://host.docker.internal:11434}"
  # The old env.example pointed at an Ollama container compose no longer starts.
  case "$url" in
    ollama|ollama:*|http://ollama|http://ollama[:/]*|https://ollama|https://ollama[:/]*)
      log_error "OLLAMA_BASE_URL_DOCKER=$url names the Ollama container Home Monitor no longer runs."
      log_error "Set it to http://host.docker.internal:11434 in .env (the machine's own Ollama), or delete the line."
      return 9
      ;;
  esac

  # A model in .env wins over ai-models.env. Older .env files were copied from
  # the old example (llama2), so say which one is used.
  chosen="${OLLAMA_MODEL:-}"
  [[ -n "$chosen" ]] || chosen="$(ollama_models_file_get "$root/.env" OLLAMA_MODEL 2>/dev/null)" || chosen=""
  default="$(ollama_models_file_get "$root/ai-models.env" OLLAMA_MODEL 2>/dev/null)" || default=""
  if [[ -n "$chosen" && "$chosen" != "$default" ]]; then
    log_warn "OLLAMA_MODEL=$chosen in .env or the environment wins over $default from ai-models.env. Remove it there to use ai-models.env."
  fi

  # Ask before pulling unless .env or the environment says otherwise (empty is
  # no value: the library reads it as "pull unasked").
  if [[ -z "${OLLAMA_PULL_MISSING:-}" ]] && [[ -z "$(ollama_models_file_get "$root/.env" OLLAMA_PULL_MISSING 2>/dev/null)" ]]; then
    export OLLAMA_PULL_MISSING=ask
  fi
  export HM_OLLAMA_URL="$url" OLLAMA_URL_VARS=HM_OLLAMA_URL
  ollama_project_ensure_models "$root/ai-models.env" "$root/.env" OLLAMA_MODEL || return
  # Answering on 127.0.0.1 does not prove the container can reach it.
  ollama_endpoint_container_reach "$url"
}

cmd_up() {
  ensure_prereqs
  local rc=0
  check_ollama || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    log_error "Not starting: the Ollama check failed (exit $rc); the message above says why. HOME_MONITOR_SKIP_OLLAMA=1 starts without it."
    exit "$rc"
  fi
  local build=true detach=true extra=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-build) build=false ;;
      --attach) detach=false ;;
      *) extra+=("$1") ;;
    esac
    shift
  done

  local args=()
  $build && args+=(--build)
  $detach && args+=(-d)

  log_info "Starting docker compose stack${build:+ (with build)}${detach:+ (detached)}..."
  docker_compose up "${args[@]}" "${extra[@]}"

  # If we reach here, services should be running; print useful links
  local api_url="http://localhost:${API_PORT:-8000}"
  local frontend_url="http://localhost:${FRONTEND_PORT:-8080}"
  log_info "Backend API: ${api_url}/api/summary/"
  log_info "Frontend: ${frontend_url}"

  # Attempt to open the frontend in a browser when available
  open_frontend_when_ready "${FRONTEND_WAIT_TIMEOUT:-120}"
}

cmd_down() {
  ensure_prereqs
  log_info "Stopping docker compose stack..."
  docker_compose down "$@"
}

cmd_build() {
  ensure_prereqs
  log_info "Building images..."
  docker_compose build "$@"
}

cmd_status() {
  ensure_prereqs
  docker_status
}

cmd_logs() {
  ensure_prereqs
  log_info "Tailing logs..."
  docker_compose logs -f "$@"
}

cmd_test_backend() {
  ensure_prereqs
  log_info "Running Django tests..."
  docker_compose run --rm backend python manage.py test "$@"
}

cmd_shell() {
  ensure_prereqs
  local service="${1:-backend}"; shift || true
  local shell_cmd="${1:-bash}"; shift || true
  log_info "Opening shell in service '$service'..."
  docker_compose exec "$service" "$shell_cmd" "$@"
}

main() {
  local cmd="${1:-help}"; shift || true

  # Global help flag support (e.g., './dev.sh -h' or './dev.sh up -h')
  for arg in "$cmd" "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
      usage
      exit 0
    fi
  done

  case "$cmd" in
    up) cmd_up "$@" ;;
    down) cmd_down "$@" ;;
    build) cmd_build "$@" ;;
    status) cmd_status "$@" ;;
    logs) cmd_logs "$@" ;;
    test-backend) cmd_test_backend "$@" ;;
    shell) cmd_shell "$@" ;;
    help|--help|-h) usage ;;
    *) log_error "Unknown command: $cmd"; usage; exit 1 ;;
  esac
}

# Sourced (tests), only the functions are defined.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
