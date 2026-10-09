#!/usr/bin/env bash
# Home Monitor's part of ./dev (scripts/cli.sh, the script-helpers template).
# cli.sh sources this file; anything not defined here is the shared verb.
#
#   ./dev start [-b] [service...]   check Ollama, then start the stack (-b rebuilds)
#   ./dev run [service...]          the same, in the foreground
#   ./dev stop [args...]            docker compose down
#   ./dev restart                   stop, then start
#   ./dev status | logs [service] | build [service...]
#   ./dev test [args...]            Django tests in the backend container, then tests/
#   ./dev shell [service] [shell]   a shell in a service (default backend, bash)
#   ./dev preflight                 what CI runs, locally
#   ./dev deploy                    not applicable (exit 3)

shlib_import docker env browser ollama_endpoint

# Hide the default helper error so we can print a more actionable message.
hm_ensure_prereqs() {
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
}

# Checks the machine's Ollama before the stack starts: it has the model
# ai-models.env names (a value in .env wins), and the backend container can
# reach it. A missing model is listed with its size and pulled after a yes;
# with no terminal the start stops and names the pull. A failed check stops
# the start: a dashboard whose advice silently falls back to heuristics looks
# like it works. HOME_MONITOR_SKIP_OLLAMA=1 skips it.
hm_check_ollama() {
  local root="$DEV_REPO_ROOT" url chosen default
  if [[ "${HOME_MONITOR_SKIP_OLLAMA:-}" == "1" ]]; then
    log_info "Skipping the Ollama check (HOME_MONITOR_SKIP_OLLAMA=1)."
    return 0
  fi
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

# hm_up <detach:true|false> [-b|--build] [service...]
hm_up() {
  local detach="$1" build=false rc=0 args=() extra=()
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -b|--build) build=true ;;
      *) extra+=("$1") ;;
    esac
    shift
  done
  hm_ensure_prereqs
  hm_check_ollama || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    log_error "Not starting: the Ollama check failed (exit $rc); the message above says why. HOME_MONITOR_SKIP_OLLAMA=1 starts without it."
    exit "$rc"
  fi
  $build && args+=(--build)
  $detach && args+=(-d)
  log_info "Starting docker compose stack..."
  docker_compose up ${args[@]+"${args[@]}"} ${extra[@]+"${extra[@]}"}
  $detach || return 0
  log_info "Backend API: http://localhost:${API_PORT:-8000}/api/summary/"
  log_info "Frontend: http://localhost:${FRONTEND_PORT:-8080}"
  open_frontend_when_ready "${FRONTEND_WAIT_TIMEOUT:-120}"
}

project_start() { hm_up true ${DEV_ARGS[@]+"${DEV_ARGS[@]}"}; }
project_run() { hm_up false ${DEV_ARGS[@]+"${DEV_ARGS[@]}"}; }

project_stop() {
  hm_ensure_prereqs
  log_info "Stopping docker compose stack..."
  docker_compose down ${DEV_ARGS[@]+"${DEV_ARGS[@]}"}
}

project_restart() {
  project_stop
  project_start
}

project_build() {
  hm_ensure_prereqs
  log_info "Building images..."
  docker_compose build ${DEV_ARGS[@]+"${DEV_ARGS[@]}"}
}

project_status() {
  hm_ensure_prereqs
  docker_status
}

project_logs() {
  hm_ensure_prereqs
  docker_compose logs -f ${DEV_ARGS[@]+"${DEV_ARGS[@]}"}
}

project_test() {
  hm_ensure_prereqs
  log_info "Running Django tests..."
  docker_compose run --rm backend python manage.py test ${DEV_ARGS[@]+"${DEV_ARGS[@]}"}
  bash "$DEV_REPO_ROOT/tests/check_ollama_test.sh"
}

# A verb of this repository's own: ./dev shell [service] [shell] [args...].
project_shell() {
  local service="${1:-backend}" shell_cmd="${2:-bash}"
  shift $(( $# < 2 ? $# : 2 ))
  hm_ensure_prereqs
  docker_compose exec "$service" "$shell_cmd" "$@"
}

# What CI runs (.github/workflows/ci.yml), through the same script-helpers
# runners. The shared preflight has no Django stack and skips a Node project
# with no test script, so it would check almost nothing here. Remove this
# once it does: https://github.com/nikolareljin/script-helpers/issues/159
project_preflight() {
  local h="$SCRIPT_HELPERS_DIR/scripts" rc=0
  log_info "preflight: backend (Django tests and migrations check, sqlite)"
  # In a python image: the host's Python may refuse pip installs (PEP 668).
  bash "$h/ci_django.sh" --workdir backend --python-image python:3.12-slim || rc=1
  log_info "preflight: frontend (npm ci, lint, build)"
  bash "$h/ci_node.sh" --workdir frontend --skip-test || rc=1
  log_info "preflight: shell (shellcheck, tests/check_ollama_test.sh)"
  shellcheck -S warning scripts/project.sh tests/*.sh start stop restart status logs || rc=1
  bash tests/check_ollama_test.sh || rc=1
  return "$rc"
}

project_deploy() {
  not_applicable deploy "Home Monitor runs from docker compose on the machine; there is no deploy target"
}
