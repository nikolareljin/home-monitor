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
shlib_import logging docker env help

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
EOF
}

ensure_prereqs() {
  check_docker
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
