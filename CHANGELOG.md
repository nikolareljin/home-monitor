# Changelog

## Unreleased

- Added script-helpers git submodule to standardize bash helpers.
- Introduced `./scripts/dev.sh` host helper (plus `./dev` symlink) to run, build, inspect, and shell into services.
- Added convenience wrappers `./start` (with optional rebuild via `-b`) and `./stop`.
- Made Ollama host port configurable via `OLLAMA_HOST_PORT` to avoid conflicts with a host Ollama instance.
- Improved dev helper UX: service URLs printed on `up` and auto-open frontend when ready; friendlier Docker daemon diagnostics.
