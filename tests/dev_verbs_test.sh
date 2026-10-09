#!/usr/bin/env bash
# Tests for the verbs in scripts/project.sh: what ./dev hands docker compose.
# docker is a stub that records its arguments, so nothing starts.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
check() { # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "  ok  $1"; else echo "FAIL  $1: expected [$2], got [$3]"; failures=$((failures + 1)); fi
}

mkdir -p "$tmp/bin"
cat >"$tmp/bin/docker" <<STUB
#!/usr/bin/env sh
echo "docker \$*" >> "$tmp/log"
echo "COMPOSE_PROFILES=\${COMPOSE_PROFILES:-}" >> "$tmp/env"
case "\$1" in info) echo "Server Version: 27" ;; compose) [ "\$2" = version ] && echo "Docker Compose version v2.30.0" ;; esac
exit 0
STUB
chmod +x "$tmp/bin/docker"

# Two free host ports: the defaults (8000, 8080) may be taken on the machine
# running this, and start refuses a taken port with no terminal.
read -r API_PORT FRONTEND_PORT < <(python3 -c 'import socket
s=[socket.socket() for _ in range(2)]
[x.bind(("127.0.0.1",0)) for x in s]
print(*[x.getsockname()[1] for x in s])')
export API_PORT FRONTEND_PORT

# compose <verb args...>: the last compose up/down/logs/build/run line ./dev ran.
compose() {
  : >"$tmp/log"
  HOME_MONITOR_SKIP_OLLAMA=1 HOME_MONITOR_NO_BROWSER=1 PATH="$tmp/bin:$PATH" "$root/dev" "$@" >/dev/null 2>&1
  grep -E '^docker compose .*(up|down|logs|build|run)( |$)' "$tmp/log" | tail -1 | sed 's/^docker compose //; s/ -f [^ ]*\.ya\?ml//g'
}

check "start: detached, no rebuild" "up -d" "$(compose start)"
check "start -b rebuilds" "up --build -d" "$(compose start -b)"
check "a service named like a target (backend) is kept" "up --build -d backend" "$(compose start -b backend)"
check "any other service is kept" "up -d db" "$(compose start db)"
check "run is the foreground start" "up frontend" "$(compose run frontend)"
check "stop passes its arguments to down" "down -v" "$(compose stop -v)"
check "logs follows a service" "logs -f backend" "$(compose logs backend)"
check "build a service" "build frontend" "$(compose build frontend)"
check "test runs Django's tests in the backend container" "run --rm backend python manage.py test" "$(HOME_MONITOR_SKIP_OLLAMA=1 HOME_MONITOR_NO_BROWSER=1 PATH="$tmp/bin:$PATH" bash -c ': >"$0/log"; "$1/dev" test >/dev/null 2>&1; grep -E "compose .*run" "$0/log" | tail -1 | sed "s/^docker compose //"' "$tmp" "$root")"
# A taken port with no terminal: the start stops and names the setting.
python3 -c 'import socket,time,sys
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(); time.sleep(30)' "$API_PORT" &
holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do (exec 3<>"/dev/tcp/127.0.0.1/$API_PORT") 2>/dev/null && break; sleep 0.2; done
: >"$tmp/log"
taken_rc=0
HOME_MONITOR_SKIP_OLLAMA=1 HOME_MONITOR_NO_BROWSER=1 PATH="$tmp/bin:$PATH" "$root/dev" start </dev/null >"$tmp/out" 2>&1 || taken_rc=$?
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
check "a taken port stops the start, naming the setting, and nothing starts" "1:1:0" "$taken_rc:$(grep -c "API_PORT=N in .env" "$tmp/out"):$(grep -c 'compose .*up' "$tmp/log")"

# An old .env value that bypasses the /api proxy is named.
check "an API URL by host port is warned about" "1" "$(VITE_API_BASE_URL=http://localhost:8000/api HOME_MONITOR_SKIP_OLLAMA=1 HOME_MONITOR_NO_BROWSER=1 PATH="$tmp/bin:$PATH" "$root/dev" start 2>&1 </dev/null | grep -c 'bypasses the frontend')"
check "and /api is not" "0" "$(VITE_API_BASE_URL=/api HOME_MONITOR_SKIP_OLLAMA=1 HOME_MONITOR_NO_BROWSER=1 PATH="$tmp/bin:$PATH" "$root/dev" start 2>&1 </dev/null | grep -c 'bypasses the frontend')"

# Ports are checked before Ollama: a taken port must not cost a model download.
python3 -c 'import socket,time,sys
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(); time.sleep(30)' "$FRONTEND_PORT" &
holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do (exec 3<>"/dev/tcp/127.0.0.1/$FRONTEND_PORT") 2>/dev/null && break; sleep 0.2; done
order="$(OLLAMA_BASE_URL_DOCKER=http://ollama:11434 HOME_MONITOR_NO_BROWSER=1 PATH="$tmp/bin:$PATH" "$root/dev" start </dev/null 2>&1 | grep -oE 'FRONTEND_PORT=N|runs only with' | head -1)"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
check "a taken port stops the start before the Ollama check" "FRONTEND_PORT=N" "$order"

# stop takes every profile along, so a fallback container stops too.
: >"$tmp/log"; : >"$tmp/env"
HOME_MONITOR_NO_BROWSER=1 PATH="$tmp/bin:$PATH" "$root/dev" stop >/dev/null 2>&1 </dev/null
check "stop runs with the ollama profile" "yes" "$(grep -q 'COMPOSE_PROFILES=ollama' "$tmp/env" && echo yes)"
: >"$tmp/env"
HOME_MONITOR_SKIP_OLLAMA=1 HOME_MONITOR_NO_BROWSER=1 PATH="$tmp/bin:$PATH" "$root/dev" start >/dev/null 2>&1 </dev/null
check "start on the host leaves the profile off" "no" "$(grep -q 'COMPOSE_PROFILES=ollama' "$tmp/env" && echo yes || echo no)"

# The fallback's models survive `./dev stop -v` (compose down -v removes every
# volume the file declares, unless it is external).
check "the ollama models volume is external, with a fixed name" "external: true|name: home-monitor_ollama_data" "$(awk '/^volumes:/{v=1} v&&/^  ollama_data:/{o=1;next} o&&/^  [a-z]/{o=0} o' "$root/docker-compose.yml" | grep -E 'external|name' | sed 's/^ *//' | sort | paste -sd'|')"

deploy_rc=0; "$root/dev" deploy >/dev/null 2>&1 || deploy_rc=$?
check "deploy is not applicable (exit 3)" "3" "$deploy_rc"

if [[ "$failures" -gt 0 ]]; then echo "FAILED: $failures"; exit 1; fi
echo "ALL PASSED"
