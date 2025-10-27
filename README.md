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
 data/      # Host-mounted media/static dirs for the backend
```

## Getting started

1. **Configure environment variables**
   ```bash
   cp env.example .env
   # Fill in API keys and secrets
   ```

2. **Launch the stack**
   ```bash
   docker compose up --build
   ```
   - Django API: http://localhost:8000/api/summary/
   - React UI: http://localhost:8080
   - Ollama API: http://localhost:11434

3. **Access the dashboard** – Open http://localhost:8080, pick an Ollama model if multiple are available, and review the AI generated actions.

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
