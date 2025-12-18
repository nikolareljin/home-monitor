# Home Monitor

Home Monitor is a Django + React platform for aggregating and analysing air quality and comfort telemetry at home. It starts with Allthings Wave radon monitors, cross-references outdoor weather data, and uses a locally hosted Ollama large language model to craft actionable recommendations (ventilation, window control, HVAC, etc.). The stack is Docker-first and designed to plug into Home Assistant while still operating as a standalone dashboard.

## Features

- **Allthings Wave integration** – Retrieve devices and latest radon/ambient readings through the vendor API.
- **Weather-aware insights** – Pull current outdoor conditions (OpenWeatherMap by default) and study correlations with indoor spikes.
- **Actionable AI** – Prompt an Ollama-hosted model for tailored guidance; heuristics ensure safe defaults when the LLM is unavailable.
- **Comfort suggestions** – Evaluate temperature/humidity trends and propose AC/heating or window adjustments.
- **Home Assistant bridge** – Optionally publish readings to HA sensor entities and fire automations.
- **Extensible connectors** – Shared `SensorConnector` abstraction for future devices (Govee, EcoQube, etc.).
- **Modern UI** – React/Vite dashboard with device switching, model picker, and live recommendations.
- **Docker orchestration** – Compose file spins up Postgres, Django API, React frontend, and Ollama runtime.

## Directory layout

```
backend/    # Django project (`home_monitor`) and monitoring app
frontend/   # React/Vite dashboard
scripts/    # Host helper scripts + script-helpers submodule
 data/      # Host-mounted media/static dirs for the backend
```

## Getting started

0. **Fetch helper dependencies** – initialize/update `scripts/script-helpers` (and any future helper modules):
   ```bash
   ./update
   ```

1. **Configure environment variables**
   ```bash
   cp env.example .env
   # Fill in API keys and secrets
   ```

2. **Launch the stack (host helper)**
   ```bash
   ./scripts/dev.sh up
   ```
   - Django API: http://localhost:8000/api/summary/
   - React UI: http://localhost:8080
   - Ollama API: http://localhost:11434

3. **Access the dashboard** – Open http://localhost:8080, pick an Ollama model if multiple are available, and review the AI generated actions.

## Helper scripts (host)

- `./start [-b] [service...]` – start the stack via `dev.sh`; `-b` forces rebuild, otherwise starts without rebuilding.
- `./stop` – stop containers (passes through to `dev.sh down`).
- `./dev` (symlink to `./scripts/dev.sh`) or `./scripts/dev.sh up [--no-build] [--attach] [service...]` – build images if needed and start the stack (detached by default).
- `./scripts/dev.sh down` – stop containers (extra args are passed through to `docker compose down`).
- `./scripts/dev.sh status` – show Docker engine and compose service status with glyphs.
- `./scripts/dev.sh logs [service]` – tail logs for all services or a single one.
- `./scripts/dev.sh test-backend [args...]` – run Django tests inside the backend container.
- `./scripts/dev.sh shell [service] [shell]` – open an interactive shell in a service (defaults to `backend` with `bash`).
- `./update` – sync and update git submodules (currently `scripts/script-helpers`; safe to re-run after pulling).

The helpers rely on the `scripts/script-helpers` git submodule for logging and Docker utilities. Ensure the submodule is initialized before running the scripts.

> If port `11434` is already used by a host Ollama instance, set `OLLAMA_HOST_PORT` in `.env` (e.g., `OLLAMA_HOST_PORT=11435`) before running `./scripts/dev.sh up`.

## Django API overview

- `GET /api/devices/` – All tracked sensors.
- `GET /api/summary/` – Aggregated snapshot (radon, weather, environment, AI advice). Query params: `device_id`, `lat`, `lon`, `city`, `model`.
- `GET /api/health/` – Lightweight readiness probe for container orchestration.
- `GET /api/recommendations/` – Latest stored recommendations.
- `GET /api/ai/models/` – Available Ollama models (proxy to `/api/tags`).

## Adding new sensors

1. Implement a connector by subclassing `apps.monitoring.services.SensorConnector`.
2. Register/fetch data in `SummaryView` (or create a scheduled task) and persist using the existing `SensorDevice` / `SensorReading` models.
3. Surface the data to the React dashboard via serializers or dedicated endpoints.

## Home Assistant integration

Provide `HOME_ASSISTANT_BASE_URL` and `HOME_ASSISTANT_TOKEN`. When enabled, the API:

- Publishes sensor states: `sensor.radon_<slug>`, `sensor.temperature_<slug>`, and `sensor.home_monitor_recommendation_<slug>` (latest Ollama-driven suggestion with context).
- Fires an event: `home_monitor_recommendation` with device, message, confidence, weather/environment context.
- Creates a persistent notification (title `Home Monitor: <device>`) for the top recommendation.

Use these entities/events in HA automations, dashboards, and notifications (e.g., “Radon went up in bedroom; forecast may spike—open window”, “Humidity low—add water to humidifier”).

## MQTT / Zigbee / Matter ingestion

- Configure broker access in `.env`: `MQTT_BROKER_URL`, `MQTT_BROKER_PORT`, and optional `MQTT_USERNAME` / `MQTT_PASSWORD`.
- Default subscriptions: `home-monitor/#`, `zigbee2mqtt/#`, `matter/#` (override via `MQTT_TOPICS`).
- Run the ingestor to persist readings from MQTT into Home Monitor:
  ```bash
  docker compose run --rm backend python manage.py mqtt_ingest
  ```
- Topic formats:
  - Generic: `home-monitor/<device_slug>/<metric>` with payload `{"value": 42, "unit": "pCi/L"}`.
  - Zigbee2MQTT: `zigbee2mqtt/<device_slug>` with payload containing numeric keys (temperature, humidity, etc.).
  - Matter bridge: `matter/<device_slug>/<metric>` with payload `{"value": 21.5, "unit": "C"}`.

Readings are stored as `SensorDevice` / `SensorReading` records and flow through the existing Ollama-driven recommendation engine and Home Assistant publishing.

## Development notes

- Backend dependencies: `backend/requirements.txt`
- Frontend dependencies: `frontend/package.json`
- Compose is mounted in dev mode (live code reload). For production, swap the frontend command to `npm run build && npm run preview` or serve the static bundle via Django/Nginx.

## Roadmap ideas

- Persist historical radon/weather series for deeper trend analysis.
- Add connectors for Govee temperature/humidity and EcoQube radon meters.
- Schedule background polling jobs (Celery/Redis) instead of request-driven syncing.
- Extend AI prompting with occupancy schedules and actionable automations (Home Assistant scenes).

## Testing

Run Django unit tests (including API smoke checks):

```bash
docker compose run --rm backend python manage.py test
```
