# Changelog

## Unreleased

- The machine's one Ollama, not a container of our own: `docker-compose.yml` drops the `ollama` service and the `ollama_data` volume declaration, and the backend calls the host's Ollama at `OLLAMA_BASE_URL_DOCKER` (default `http://host.docker.internal:11434`). An existing `ollama_data` volume is not removed: it may hold models.
- The model comes from `ai-models.env`, generated from the fleet model registry (`OLLAMA_MODEL=qwen3.5:4b`); `OLLAMA_MODEL` in `.env` still wins. The `llama2` defaults (backend, `env.example`, frontend build) are gone, and so is `VITE_DEFAULT_OLLAMA_MODEL`: `/api/ai/models/` returns the project's model as `default`, and the picker starts on it ("Project default" when the Ollama lacks it) instead of the first model a shared Ollama lists.
- `./scripts/dev.sh up` checks the Ollama first (script-helpers 0.47.0): a missing model is listed with its size and pulled after a yes, with no terminal the start stops and names the pull, and a backend container that cannot reach the host's Ollama stops it too. `HOME_MONITOR_SKIP_OLLAMA=1` skips the check. An old `.env` pointing at the removed container (`http://ollama:11434`) is named.
- script-helpers submodule: 0.11.0 to 0.47.0.
- Frontend: `@vitejs/plugin-react` ^6.1.2 for vite 8. With ^4 (vite up to 7) and no lockfile, `npm install` failed and the frontend image did not build.
- Added script-helpers git submodule to standardize bash helpers.
- Introduced `./scripts/dev.sh` host helper (plus `./dev` symlink) to run, build, inspect, and shell into services.
- Added convenience wrappers `./start` (with optional rebuild via `-b`) and `./stop`.
- Improved dev helper UX: service URLs printed on `up` and auto-open frontend when ready; friendlier Docker daemon diagnostics.
