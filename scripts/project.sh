#!/usr/bin/env bash
# Home Monitor's part of ./dev (scripts/cli.sh, the script-helpers template).
# cli.sh sources this file; anything not defined here is the shared verb.
#
#   ./dev start [-b] [service...]   check Ollama, then start the stack (-b rebuilds)
#   ./dev run [service...]          the same, in the foreground
#   ./dev stop [args...]            docker compose down
#   ./dev restart                   stop, then start
#   ./dev status | logs [service] | build [service...]
#   ./dev test [args...]            Django tests in the backend container, then tests/*_test.sh
#   ./dev shell [service] [shell]   a shell in a service (default backend, bash)
#   ./dev preflight                 what CI runs, locally
#   ./dev deploy                    not applicable (exit 3)

shlib_import docker env browser ollama_endpoint ports

# The words after a shared verb, as compose arguments. cli.sh takes "backend"
# and "frontend" as the target (DEV_TARGET), not as arguments, so put it back
# in front. A second target word replaces the first in cli.sh, so
# `./dev start backend frontend` reaches here as frontend alone:
# https://github.com/nikolareljin/script-helpers/issues/160
hm_args() {
  HM_ARGS=()
  [[ -z "${DEV_TARGET:-}" ]] || HM_ARGS+=("$DEV_TARGET")
  HM_ARGS+=(${DEV_ARGS[@]+"${DEV_ARGS[@]}"})
}

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

# Which Ollama the stack uses: OLLAMA_RUNTIME=host (default), the machine's
# one Ollama; or container, the fallback: the profiled `ollama` service in
# docker-compose.yml, with its models in this project's ollama_data volume.
# COMPOSE_PROFILES carries the choice to every compose call (up, down, logs).
hm_runtime() {
  HM_RUNTIME="${OLLAMA_RUNTIME:-}"
  [[ -n "$HM_RUNTIME" ]] || HM_RUNTIME="$(ollama_models_file_get "$DEV_REPO_ROOT/.env" OLLAMA_RUNTIME 2>/dev/null)" || HM_RUNTIME=""
  HM_RUNTIME="${HM_RUNTIME:-host}"
  case "$HM_RUNTIME" in
    host) ;;
    container) export COMPOSE_PROFILES=ollama ;;
    *) log_error "OLLAMA_RUNTIME=$HM_RUNTIME: use host (the machine's Ollama) or container (the ollama service in docker-compose.yml)."
       return 9 ;;
  esac
}

# Starts the ollama container and waits until it answers on the host port it
# publishes (OLLAMA_CONTAINER_PORT, 127.0.0.1 only).
hm_start_ollama_container() {
  local port="$1" waited=0
  log_info "OLLAMA_RUNTIME=container: starting the ollama service (port $port on 127.0.0.1)..."
  # External (docker-compose.yml), so compose does not create it.
  docker volume inspect home-monitor_ollama_data >/dev/null 2>&1 \
    || docker volume create home-monitor_ollama_data >/dev/null || return 1
  docker_compose up -d ollama || return 1
  until curl -fsS -m 2 -o /dev/null "http://127.0.0.1:${port}/api/tags" 2>/dev/null; do
    sleep 2; waited=$((waited + 2))
    if [[ "$waited" -ge 60 ]]; then
      log_error "The ollama container did not answer on 127.0.0.1:$port within 60s: ./dev logs ollama"
      return 4
    fi
  done
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
  hm_runtime || return

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

  if [[ "$HM_RUNTIME" == "container" ]]; then
    local port="${OLLAMA_CONTAINER_PORT:-}"
    [[ -n "$port" ]] || port="$(ollama_models_file_get "$root/.env" OLLAMA_CONTAINER_PORT 2>/dev/null)" || port=""
    port="${port:-11435}"
    hm_start_ollama_container "$port" || return
    # The backend reaches the container by its service name; compose reads
    # this for the backend's OLLAMA_BASE_URL.
    export OLLAMA_BASE_URL_DOCKER=http://ollama:11434
    # docker mode: the library asks 127.0.0.1:<published port> and measures
    # Docker's disk, where the ollama_data volume lives.
    export HM_OLLAMA_URL=http://ollama:11434 OLLAMA_URL_VARS=HM_OLLAMA_URL OLLAMA_MODE=docker OLLAMA_HOST_PORT="$port"
    ollama_project_ensure_models "$root/ai-models.env" "$root/.env" OLLAMA_MODEL
    return
  fi

  # The address the backend container is given (OLLAMA_BASE_URL_DOCKER in
  # .env); the library reads host.docker.internal on the host as this machine.
  url="${OLLAMA_BASE_URL_DOCKER:-}"
  [[ -n "$url" ]] || url="$(ollama_models_file_get "$root/.env" OLLAMA_BASE_URL_DOCKER 2>/dev/null)" || url=""
  url="${url:-http://host.docker.internal:11434}"
  # The ollama service only runs with OLLAMA_RUNTIME=container.
  case "$url" in
    ollama|ollama:*|http://ollama|http://ollama[:/]*|https://ollama|https://ollama[:/]*)
      log_error "OLLAMA_BASE_URL_DOCKER=$url names the ollama container, which runs only with OLLAMA_RUNTIME=container."
      log_error "Set OLLAMA_RUNTIME=container in .env for it, or set OLLAMA_BASE_URL_DOCKER=http://host.docker.internal:11434 (the machine's own Ollama), or delete the line."
      return 9
      ;;
  esac

  export HM_OLLAMA_URL="$url" OLLAMA_URL_VARS=HM_OLLAMA_URL
  local rc=0
  ollama_project_ensure_models "$root/ai-models.env" "$root/.env" OLLAMA_MODEL || rc=$?
  if [[ "$rc" -eq 4 ]]; then
    log_error "No Ollama on this machine answers. Install one, or use the container fallback: OLLAMA_RUNTIME=container in .env."
  fi
  [[ "$rc" -eq 0 ]] || return "$rc"
  # Answering on 127.0.0.1 does not prove the container can reach it.
  ollama_endpoint_container_reach "$url"
}

# The host ports the stack publishes. A taken one is not swapped silently: on
# a terminal the person picks another (port_choose) and it is saved to .env;
# with no terminal the start stops and names the setting.
hm_choose_ports() {
  local entry var default service inner current chosen
  # setting:default host port:compose service:port inside the container
  for entry in API_PORT:8000:backend:8000 FRONTEND_PORT:8080:frontend:80; do
    IFS=: read -r var default service inner <<<"$entry"
    current="${!var:-}"
    [[ -n "$current" ]] || current="$(ollama_models_file_get "$DEV_REPO_ROOT/.env" "$var" 2>/dev/null)" || current=""
    current="${current:-$default}"
    # Held by this stack already (a second ./dev start): not taken.
    if docker_compose port "$service" "$inner" 2>/dev/null | grep -q ":${current}\$"; then
      export "$var=$current"
      continue
    fi
    chosen="$(port_choose "$current" "$var=N in .env")" || return 1
    if [[ "$chosen" != "$current" ]]; then
      env_set_value "$DEV_REPO_ROOT/.env" "$var" "$chosen"
      log_info "$var=$chosen saved in .env"
    fi
    export "$var=$chosen"
  done
}

# An .env copied from the old example names the API by host port
# (http://localhost:8000/api). The frontend then skips its /api proxy and
# breaks when API_PORT moves; it is read at build time, so -b applies a fix.
hm_warn_api_url() {
  local api_url="${VITE_API_BASE_URL:-}"
  [[ -n "$api_url" ]] || api_url="$(ollama_models_file_get "$DEV_REPO_ROOT/.env" VITE_API_BASE_URL 2>/dev/null)" || api_url=""
  if [[ -n "$api_url" && "$api_url" != "/api" ]]; then
    log_warn "VITE_API_BASE_URL=$api_url bypasses the frontend's /api proxy, and breaks when API_PORT changes. Set it to /api in .env, then ./dev start -b."
  fi
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
  # Ports first: cheap, and a taken port found after a model download of
  # several GB would waste it.
  hm_choose_ports || exit 1
  hm_warn_api_url
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
  log_info "Backend API: http://localhost:${API_PORT}/api/summary/"
  log_info "Frontend: http://localhost:${FRONTEND_PORT}"
  # Only for a person at a terminal: the helper opens the URL even when the
  # frontend never answers, and a script or test must not open a browser.
  # HOME_MONITOR_NO_BROWSER=1 turns it off at a terminal too.
  if [[ -t 0 && -t 1 && "${HOME_MONITOR_NO_BROWSER:-}" != "1" ]]; then
    open_frontend_when_ready "${FRONTEND_WAIT_TIMEOUT:-120}"
  fi
}

project_start() { hm_args; hm_up true ${HM_ARGS[@]+"${HM_ARGS[@]}"}; }
project_run() { hm_args; hm_up false ${HM_ARGS[@]+"${HM_ARGS[@]}"}; }

project_stop() {
  hm_ensure_prereqs
  # Every profile: an ollama container started under OLLAMA_RUNTIME=container
  # stops too after switching back to host. Its models volume is kept.
  export COMPOSE_PROFILES=ollama
  log_info "Stopping docker compose stack..."
  hm_args
  docker_compose down ${HM_ARGS[@]+"${HM_ARGS[@]}"}
}

project_restart() {
  project_stop
  project_start
}

project_build() {
  hm_ensure_prereqs
  hm_runtime || exit $?
  log_info "Building images..."
  hm_args
  docker_compose build ${HM_ARGS[@]+"${HM_ARGS[@]}"}
}

project_status() {
  hm_ensure_prereqs
  hm_runtime || exit $?
  docker_status
}

project_logs() {
  hm_ensure_prereqs
  hm_runtime || exit $?
  hm_args
  docker_compose logs -f ${HM_ARGS[@]+"${HM_ARGS[@]}"}
}

project_test() {
  hm_ensure_prereqs
  hm_runtime || exit $?
  log_info "Running Django tests..."
  hm_args
  docker_compose run --rm backend python manage.py test ${HM_ARGS[@]+"${HM_ARGS[@]}"}
  bash "$DEV_REPO_ROOT/tests/check_ollama_test.sh"
  bash "$DEV_REPO_ROOT/tests/dev_verbs_test.sh"
}

# A verb of this repository's own: ./dev shell [service] [shell] [args...].
project_shell() {
  local service="${1:-backend}" shell_cmd="${2:-bash}"
  shift $(( $# < 2 ? $# : 2 ))
  hm_ensure_prereqs
  hm_runtime || exit $?
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
  log_info "preflight: shell (shellcheck, tests/*_test.sh)"
  shellcheck -S warning scripts/project.sh tests/*.sh start stop restart status logs || rc=1
  bash tests/check_ollama_test.sh || rc=1
  bash tests/dev_verbs_test.sh || rc=1
  return "$rc"
}

project_deploy() {
  not_applicable deploy "Home Monitor runs from docker compose on the machine; there is no deploy target"
}
