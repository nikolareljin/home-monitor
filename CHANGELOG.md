# Changelog

## 2025-12-17

- Added script-helpers git submodule to standardize bash helpers.
- Introduced `./scripts/dev.sh` host helper (plus `./dev` symlink) to run, build, inspect, and shell into services.
- Added convenience wrappers `./start` (with optional rebuild via `-b`) and `./stop`.
- Made Ollama host port configurable via `OLLAMA_HOST_PORT` to avoid conflicts with a host Ollama instance.
- Improved dev helper UX: service URLs printed on `up` and auto-open frontend when ready; friendlier Docker daemon diagnostics.
- Expanded Home Assistant integration: recommendation sensor (`sensor.home_monitor_recommendation_<slug>`), event (`home_monitor_recommendation`), and persistent notification with the latest Ollama-driven guidance.
- Added MQTT ingestion (generic + Zigbee2MQTT + Matter topic styles) with `python manage.py mqtt_ingest`; new env vars for broker config.
