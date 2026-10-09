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
check "the removed ollama container is named, nothing asked" "9||" "$(run OLLAMA_BASE_URL_DOCKER=http://ollama:11434)"
check "a host that only starts with ollama is not it" "0|http://ollamabox:11434|http://ollamabox:11434" "$(run OLLAMA_BASE_URL_DOCKER=http://ollamabox:11434)"
check "a missing model stops before the reach check" "5|http://host.docker.internal:11434|" "$(run ENSURE_RC=5)"
check "a container that cannot reach it stops the start" "4|http://host.docker.internal:11434|http://host.docker.internal:11434" "$(run REACH_RC=4)"
check "HOME_MONITOR_SKIP_OLLAMA=1 asks nothing" "0||" "$(run HOME_MONITOR_SKIP_OLLAMA=1)"
# shellcheck disable=SC2016  # expanded by the inner bash
check "pulls are asked about unless set" "ask" "$(env -u OLLAMA_PULL_MISSING bash -c 'source "$0/scripts/_bootstrap.sh"; shlib_import logging help; source "$0/scripts/project.sh"; ollama_project_ensure_models() { echo "$OLLAMA_PULL_MISSING"; }; ollama_endpoint_container_reach() { :; }; hm_check_ollama 2>/dev/null' "$root")"
# shellcheck disable=SC2016  # expanded by the inner bash
check "and a value set is kept" "0" "$(OLLAMA_PULL_MISSING=0 bash -c 'source "$0/scripts/_bootstrap.sh"; shlib_import logging help; source "$0/scripts/project.sh"; ollama_project_ensure_models() { echo "$OLLAMA_PULL_MISSING"; }; ollama_endpoint_container_reach() { :; }; hm_check_ollama 2>/dev/null' "$root")"

if [[ "$failures" -gt 0 ]]; then echo "FAILED: $failures"; exit 1; fi
echo "ALL PASSED"
