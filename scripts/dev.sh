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

# Fast-fail with setup guidance if the helper library is missing
if [[ ! -r "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  cat <<'EOF'
The script-helpers library is not present. Fetch it before running host helpers:
  1) Recommended: ./update
  2) Manual: git submodule update --init --recursive
If you just pulled the repo, run ./update to sync submodules, then re-run this command.
EOF
  exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging docker env browser help

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

cmd_up() {
  ensure_prereqs
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

main "$@"
