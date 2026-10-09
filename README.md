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
- **Docker orchestration** – Compose file spins up Postgres, Django API and React frontend; the backend uses the machine's own Ollama, shared with other projects, or the `ollama` container as a fallback (`OLLAMA_RUNTIME=container`).

## Directory layout

```
backend/    # Django project (`home_monitor`) and monitoring app
frontend/   # React/Vite dashboard
scripts/    # Host helper scripts + script-helpers submodule
 data/      # Host-mounted media/static dirs for the backend
```

## Getting started

0. **Pull helper submodule**
   ```bash
   git submodule update --init --recursive
   ```

1. **Configure environment variables**
   ```bash
   cp env.example .env
   # Fill in API keys and secrets
   ```

2. **Launch the stack (host helper)**
   ```bash
   ./dev start
   ```
   - Django API: http://localhost:8000/api/summary/
   - React UI: http://localhost:8080

   The start first checks the machine's own Ollama: it must have the model `ai-models.env` names, and a container must be able to reach it. A missing model is offered for download. No Ollama on the machine? Set `OLLAMA_RUNTIME=container` in `.env`: the start runs the `ollama` container (port `OLLAMA_CONTAINER_PORT`, default 11435) and checks the model there.

3. **Access the dashboard** – Open http://localhost:8080, review the AI generated actions, and pick another installed model if you want.

## Helper scripts (host)

One entry point, `./dev <verb>` (the script-helpers `./dev` template; this repository's part is `scripts/project.sh`). `./dev --help` lists every verb.

- `./dev start [-b] [service...]` – check the machine's Ollama and the host ports, then start the stack in the background; `-b` rebuilds the images. `./start` does the same. A taken port (`API_PORT`, default 8000; `FRONTEND_PORT`, default 8080) is not swapped silently: on a terminal you pick another and it is saved to `.env`; without one the start stops and names the setting. The browser opens on the dashboard only from a terminal (`HOME_MONITOR_NO_BROWSER=1` turns that off).
- `./dev run [service...]` – the same, in the foreground.
- `./dev stop [args...]` – stop containers (extra args go to `docker compose down`). `./stop` does the same.
- `./dev restart`, `./dev status`, `./dev logs [service]`, `./dev build [service...]` – the usual; `./restart`, `./status` and `./logs` exist too.
- `./dev test [args...]` – Django tests inside the backend container, then `tests/*_test.sh`.
- `./dev shell [service] [shell]` – a shell in a service (default `backend`, `bash`).
- `./dev preflight` – what CI runs, locally.

The helpers rely on the `scripts/script-helpers` git submodule. Ensure the submodule is initialized before running them.

> The model is the one `ai-models.env` names (generated from the fleet model registry; do not edit it). To try another on this machine, set `OLLAMA_MODEL` in `.env`. `HOME_MONITOR_SKIP_OLLAMA=1 ./dev start` starts without the Ollama check.

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

Provide `HOME_ASSISTANT_BASE_URL` and `HOME_ASSISTANT_TOKEN`. When enabled, the API publishes radon and temperature readings to matching HA sensor IDs (`sensor.radon_<slug>` etc.), so you can display or automate inside Home Assistant.

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

---

## Clone traffic

![Clone traffic](https://raw.githubusercontent.com/nikolareljin/stats/main/charts/home-monitor.svg)

_Updated daily. Total and unique cloners over the last 14 days._
