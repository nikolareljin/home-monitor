# Changelog

## Unreleased

- The machine's one Ollama, not a container of our own: `docker-compose.yml` drops the `ollama` service and the `ollama_data` volume declaration, and the backend calls the host's Ollama at `OLLAMA_BASE_URL_DOCKER` (default `http://host.docker.internal:11434`). An existing `ollama_data` volume is not removed: it may hold models.
- The model comes from `ai-models.env`, generated from the fleet model registry (`OLLAMA_MODEL=qwen3.5:4b`); `OLLAMA_MODEL` in `.env` still wins. The `llama2` defaults (backend, `env.example`, frontend build) are gone, and so is `VITE_DEFAULT_OLLAMA_MODEL`: `/api/ai/models/` returns the project's model as `default`, and the picker starts on it ("Project default" when the Ollama lacks it) instead of the first model a shared Ollama lists.
- `./dev start` checks the Ollama first (script-helpers 0.47.0): a missing model is listed with its size and pulled after a yes, with no terminal the start stops and names the pull, and a backend container that cannot reach the host's Ollama stops it too. `HOME_MONITOR_SKIP_OLLAMA=1` skips the check. An old `.env` pointing at the removed container (`http://ollama:11434`) is named.
- script-helpers submodule: 0.11.0 to 0.47.0.
- `./dev` is the script-helpers template now (`scripts/cli.sh`), with Home Monitor's verbs in `scripts/project.sh`: `start` (`-b` rebuilds), `run`, `stop`, `restart`, `status`, `logs`, `build`, `test`, `shell`, `preflight`; `deploy` exits 3. `scripts/dev.sh` is gone: `./scripts/dev.sh up` is `./dev start`, `down` is `./dev stop`, `test-backend` is `./dev test`. `./start` and `./stop` stay, as shims; `./restart`, `./status` and `./logs` are new.
- Host ports `API_PORT` (8000) and `FRONTEND_PORT` (8080) are settings, checked by `./dev start` before compose runs: a taken one is offered a replacement on a terminal (saved to `.env`) and stops the start without one. A port this stack already holds is not "taken".
- The frontend's nginx proxies `/api/` to the backend, and the default `VITE_API_BASE_URL` is `/api`, so the dashboard works whatever `API_PORT` is. The image's old default, `http://backend:8000/api`, never resolved in a browser.
- `gunicorn` added to `backend/requirements.txt`: the image's `CMD` runs it, it was never installed, and the backend container restarted forever.
- `./dev start` checks the ports before Ollama (a taken port must not cost a model download), and warns when an old `.env` sets `VITE_API_BASE_URL` to a host-port URL, which bypasses the `/api` proxy.
- `./dev start` opens the browser only from a terminal; scripts and tests never do. `HOME_MONITOR_NO_BROWSER=1` turns it off.
- CI: `.github/workflows/ci.yml` runs ci-helpers `django.yml` (backend, sqlite), `react.yml` (frontend lint and build) and `shell.yml` (shellcheck, `tests/check_ollama_test.sh`, `tests/dev_verbs_test.sh`), all `@production`.
- `backend/apps/monitoring/migrations/0002_...`: the index rename the models already declared; `makemigrations --check` failed without it.
- `frontend/package-lock.json`, so `npm ci` (CI, and the frontend image) installs what was tested.
- Frontend: `@vitejs/plugin-react` ^6.1.2 for vite 8. With ^4 (vite up to 7) and no lockfile, `npm install` failed and the frontend image did not build.
- Added script-helpers git submodule to standardize bash helpers.
- Added convenience wrappers `./start` (with optional rebuild via `-b`) and `./stop`.
- Improved dev helper UX: service URLs printed on `up` and auto-open frontend when ready; friendlier Docker daemon diagnostics.
