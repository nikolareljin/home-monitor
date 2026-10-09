#!/usr/bin/env bash
# Tests for hm_check_ollama in scripts/project.sh (./dev start): what it hands script-helpers, and
# when it stops the start. The library calls are stubs, so nothing here talks
# to an Ollama or to Docker.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0
check() { # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "  ok  $1"; else echo "FAIL  $1: expected [$2], got [$3]"; failures=$((failures + 1)); fi
}

# run <VAR=value>...: loads project.sh as cli.sh does, with the library
# stubbed, runs hm_check_ollama, prints "<exit>|<url asked for models>|<url asked for reach>".
# shellcheck disable=SC2016  # expanded by the inner bash
run() {
  env -u OLLAMA_BASE_URL_DOCKER -u OLLAMA_MODEL -u OLLAMA_PULL_MISSING -u HOME_MONITOR_SKIP_OLLAMA "$@" bash -c '
    source "$0/scripts/_bootstrap.sh"; shlib_import logging help; source "$0/scripts/project.sh"
    ensure_url=""; reach_url=""
    ollama_project_ensure_models() { ensure_url="$HM_OLLAMA_URL"; return "${ENSURE_RC:-0}"; }
    ollama_endpoint_container_reach() { reach_url="$1"; return "${REACH_RC:-0}"; }
    # _bootstrap.sh turns on set -e: a failing check would end this shell.
    rc=0; hm_check_ollama >/dev/null 2>&1 || rc=$?
    echo "$rc|$ensure_url|$reach_url"
  ' "$root"
}

check "default: the host, through Docker's name for it" "0|http://host.docker.internal:11434|http://host.docker.internal:11434" "$(run X=1)"
check "OLLAMA_BASE_URL_DOCKER is the address asked" "0|http://host.docker.internal:11500|http://host.docker.internal:11500" "$(run OLLAMA_BASE_URL_DOCKER=http://host.docker.internal:11500)"
check "the ollama container URL without OLLAMA_RUNTIME=container is named" "9||" "$(run OLLAMA_BASE_URL_DOCKER=http://ollama:11434)"
check "a host that only starts with ollama is not it" "0|http://ollamabox:11434|http://ollamabox:11434" "$(run OLLAMA_BASE_URL_DOCKER=http://ollamabox:11434)"
check "a missing model stops before the reach check" "5|http://host.docker.internal:11434|" "$(run ENSURE_RC=5)"
check "a container that cannot reach it stops the start" "4|http://host.docker.internal:11434|http://host.docker.internal:11434" "$(run REACH_RC=4)"
# Container fallback: the container is started, the check asks it in docker
# mode through its published port, and there is no bridge to reach.
# shellcheck disable=SC2016  # expanded by the inner bash
container() {
  env -u OLLAMA_BASE_URL_DOCKER -u OLLAMA_MODEL -u OLLAMA_PULL_MISSING -u OLLAMA_RUNTIME "$@" bash -c '
    source "$0/scripts/_bootstrap.sh"; shlib_import logging help; source "$0/scripts/project.sh"
    started=""; reach=""
    hm_start_ollama_container() { started="$1"; }
    ollama_project_ensure_models() { echo "ensure:$HM_OLLAMA_URL:$OLLAMA_MODE:$OLLAMA_HOST_PORT"; }
    ollama_endpoint_container_reach() { reach=1; }
    rc=0; hm_check_ollama 2>/dev/null || rc=$?
    echo "rc=$rc started=$started reach=${reach:-no} backend=$OLLAMA_BASE_URL_DOCKER profiles=${COMPOSE_PROFILES:-}"
  ' "$root" | tr "\n" " " | sed "s/ $//"
}
check "OLLAMA_RUNTIME=container: the container, asked in docker mode" "ensure:http://ollama:11434:docker:11435 rc=0 started=11435 reach=no backend=http://ollama:11434 profiles=ollama" "$(container OLLAMA_RUNTIME=container)"
check "its port is OLLAMA_CONTAINER_PORT" "ensure:http://ollama:11434:docker:11500 rc=0 started=11500 reach=no backend=http://ollama:11434 profiles=ollama" "$(container OLLAMA_RUNTIME=container OLLAMA_CONTAINER_PORT=11500)"
check "an unknown runtime is refused" "rc=9 started= reach=no backend= profiles=" "$(container OLLAMA_RUNTIME=cloud)"
# A taken container port, no terminal: the start stops, naming the setting.
held="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')"
python3 -c 'import socket,time,sys
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(); time.sleep(20)' "$held" &
holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do (exec 3<>"/dev/tcp/127.0.0.1/$held") 2>/dev/null && break; sleep 0.2; done
# shellcheck disable=SC2016  # expanded by the inner bash
taken="$(env -u OLLAMA_RUNTIME bash -c '
  source "$0/scripts/_bootstrap.sh"; shlib_import logging help; source "$0/scripts/project.sh"
  docker_compose() { return 1; }
  hm_start_ollama_container() { echo started; }
  ollama_project_ensure_models() { echo ensure; }
  rc=0; OLLAMA_RUNTIME=container OLLAMA_CONTAINER_PORT="$1" hm_check_ollama </dev/null >"$2" 2>&1 || rc=$?
  echo "rc=$rc started=$(grep -c started "$2") named=$(grep -c "OLLAMA_CONTAINER_PORT=N" "$2")"
' "$root" "$held" "$(mktemp)")"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
check "a taken container port stops the start before it runs, naming the setting" "rc=1 started=0 named=1" "$taken"

# Read from .env (the real reader, not a stub): a temporary root with its own.
envroot="$(mktemp -d)"
printf 'OLLAMA_RUNTIME="container"\nOLLAMA_CONTAINER_PORT=11577  # fallback\n' >"$envroot/.env"
cp "$root/ai-models.env" "$envroot/"
# shellcheck disable=SC2016  # expanded by the inner bash
from_env="$(env -u OLLAMA_RUNTIME -u OLLAMA_CONTAINER_PORT -u OLLAMA_BASE_URL_DOCKER bash -c '
  source "$0/scripts/_bootstrap.sh"; shlib_import logging help; source "$0/scripts/project.sh"
  DEV_REPO_ROOT="$1"
  hm_start_ollama_container() { :; }
  ollama_project_ensure_models() { echo "$OLLAMA_MODE:$OLLAMA_HOST_PORT"; }
  hm_check_ollama 2>/dev/null
' "$root" "$envroot")"
rm -rf "$envroot"
check "OLLAMA_RUNTIME and its port are read from .env" "docker:11577" "$from_env"
check "HOME_MONITOR_SKIP_OLLAMA=1 asks nothing" "0||" "$(run HOME_MONITOR_SKIP_OLLAMA=1)"
# shellcheck disable=SC2016  # expanded by the inner bash
check "pulls are asked about unless set" "ask" "$(env -u OLLAMA_PULL_MISSING bash -c 'source "$0/scripts/_bootstrap.sh"; shlib_import logging help; source "$0/scripts/project.sh"; ollama_project_ensure_models() { echo "$OLLAMA_PULL_MISSING"; }; ollama_endpoint_container_reach() { :; }; hm_check_ollama 2>/dev/null' "$root")"
# shellcheck disable=SC2016  # expanded by the inner bash
check "and a value set is kept" "0" "$(OLLAMA_PULL_MISSING=0 bash -c 'source "$0/scripts/_bootstrap.sh"; shlib_import logging help; source "$0/scripts/project.sh"; ollama_project_ensure_models() { echo "$OLLAMA_PULL_MISSING"; }; ollama_endpoint_container_reach() { :; }; hm_check_ollama 2>/dev/null' "$root")"

if [[ "$failures" -gt 0 ]]; then echo "FAILED: $failures"; exit 1; fi
echo "ALL PASSED"
