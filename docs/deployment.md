# Deployment Guide

Home Monitor is packaged as a Docker Compose stack that includes PostgreSQL, the Django backend, the frontend served by Nginx, and a local Ollama runtime. This document explains how to configure, launch, and maintain the deployment.

## Prerequisites

- Docker 24+
- Docker Compose v2
- Access to a machine capable of running the chosen Ollama model (CPU or GPU depending on model size).

## Environment Setup

1. Copy the sample env file and edit secrets:
   ```bash
   cp env.example .env
   ```
2. Populate `.env` with:
   - Strong `DJANGO_SECRET_KEY`
   - `POSTGRES_*` credentials
   - API keys (`ALLTHINGS_WAVE_API_KEY`, `WEATHER_API_KEY`)
   - `OLLAMA_MODEL` (ensure it is pulled locally, e.g., `ollama pull llama2`)
   - Home Assistant token if integration is desired
3. Sync helper dependencies (git submodules for host scripts):
   ```bash
   ./update
   ```

## Build & Run

```bash
docker compose build --pull
docker compose up -d
```
> For local development you can also use `./start` (uses `./dev`/`./scripts/dev.sh` under the hood; requires the `scripts/script-helpers` submodule).
> If port `11434` is occupied on the host, set `OLLAMA_HOST_PORT` in `.env` (e.g., `OLLAMA_HOST_PORT=11435`) before starting.

Services exposed:

- Backend API: http://localhost:${API_PORT:-8000} (health: `/api/health/`)
- Frontend UI: http://localhost:${FRONTEND_PORT:-8080}
- Ollama API: http://localhost:${OLLAMA_HOST_PORT:-11434} (local only by default)
- PostgreSQL: on internal Docker network (`db:5432`)

Logs:

```bash
docker compose logs -f backend
```

## Data Persistence

- Postgres data stored in volume `postgres_data`
- Ollama models stored in volume `ollama_data`
- Django media/static in volumes `media_data`, `static_data`

## Health Checks

- Database: Compose health check ensures backend waits until PostgreSQL is ready.
- Backend: `/api/health/` returns status; configure liveness/readiness probes in orchestration environments (Kubernetes, Docker Swarm).

## Maintenance Tasks

- **Migrations:**
  ```bash
  docker compose run --rm backend python manage.py migrate
  ```
- **Superuser:**
  ```bash
  docker compose run --rm backend python manage.py createsuperuser
  ```
- **Tests:**
  ```bash
  docker compose run --rm backend python manage.py test
  ```
- **Static assets:** Collected automatically in entrypoint for future static serving.

## Home Assistant integration

When `HOME_ASSISTANT_BASE_URL` and `HOME_ASSISTANT_TOKEN` are set, the backend publishes:

- Sensor states: `sensor.radon_<slug>`, `sensor.temperature_<slug>`, `sensor.home_monitor_recommendation_<slug>` (latest Ollama suggestion + context).
- Event: `home_monitor_recommendation` with device, message, confidence, weather/environment context.
- Persistent notification: titled `Home Monitor: <device>` for the top recommendation.

Use these in HA automations (e.g., notify when radon is forecast to spike, humidity drops, or upcoming weather + Nest heat might dry a room).

## MQTT / Zigbee / Matter ingestion

- Configure `.env`: `MQTT_BROKER_URL`, `MQTT_BROKER_PORT` (default 1883), optional `MQTT_USERNAME` / `MQTT_PASSWORD`, `MQTT_TOPICS` (default `home-monitor/#,zigbee2mqtt/#,matter/#`).
- Run the ingestor:
  ```bash
  docker compose run --rm backend python manage.py mqtt_ingest
  ```
- Supported topics:
  - Generic: `home-monitor/<device_slug>/<metric>` payload `{"value": 42, "unit": "pCi/L"}`.
  - Zigbee2MQTT: `zigbee2mqtt/<device_slug>` with numeric keys (temperature, humidity, etc.).
  - Matter bridge: `matter/<device_slug>/<metric>` payload `{"value": 21.5, "unit": "C"}`.
- Ingested readings populate sensors, feed recommendations, and continue into Home Assistant publishing.

## Scaling Considerations

- **Backend:** Gunicorn default worker count is 1; override via compose (`command`) or env (`WEB_CONCURRENCY`).
- **Frontend:** Nginx is stateless; scale horizontally without changes.
- **Database:** For high availability, replace with managed Postgres service and configure TLS.
- **Ollama:** Some models require GPU; consider hosting on dedicated hardware and exposing via secure network.

## Security Hardening

- Disable `DJANGO_DEBUG` in production.
- Restrict `DJANGO_ALLOWED_HOSTS` to public domains.
- Enforce HTTPS via reverse proxy (e.g., Traefik, Caddy, Nginx Ingress).
- Store secrets securely (Docker secrets, Vault, SSM) instead of plain environment variables.
- Limit Ollama API exposure to trusted networks.

## Continuous Deployment

- Build images via CI pipeline (`docker build backend`, `docker build frontend`).
- Push to image registry and deploy to container orchestrator.
- Run migrations automatically on release but guard with rollbacks.

## Troubleshooting

- Backend fails to start: check `.env` values, DB connectivity, and migrations.
- Ollama errors in summary response: ensure model is pulled and service is healthy (`docker compose logs ollama`).
- Frontend blank: confirm Nginx container is serving built assets (`docker compose logs frontend`).
- Home Assistant sync errors: verify base URL is reachable from backend container and token has correct scope.
