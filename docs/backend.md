# Backend Guide

The backend is a Django 5 project located under `backend/` with a core project module `home_monitor` and a primary app `apps.monitoring`. It exposes REST endpoints via Django REST Framework and integrates with external services to ingest data, generate AI recommendations, and publish readings to Home Assistant.

## Configuration

Environment variables are consumed via `.env` (see `env.example`). Key settings:

- `ALLTHINGS_WAVE_*` – API base URL and token for radon devices.
- `WEATHER_API_*` – Weather provider configuration (defaults to OpenWeatherMap).
- `OLLAMA_BASE_URL`, `OLLAMA_MODEL` – Local Ollama runtime and default model.
- `HOME_ASSISTANT_*` – Optional Home Assistant REST endpoint.
- `POSTGRES_*` – Database credentials (PostgreSQL in production, SQLite fallback).
- `DJANGO_*` – Core settings (secret key, debug, allowed hosts).

Settings load order (`home_monitor/settings.py`):

1. `.env` alongside the backend directory for containerized deployment.
2. Project root `.env` for local development.

Static files use WhiteNoise (`whitenoise.middleware.WhiteNoiseMiddleware`) with `CompressedManifestStaticFilesStorage`.

## Models

Defined in `apps.monitoring.models`:

- `SensorDevice` – Metadata per physical/virtual sensor.
- `SensorReading` – Timestamped metric values (radon, temperature, humidity).
- `Recommendation` – Persisted AI/heuristic suggestions.

Migrations live in `apps/monitoring/migrations/`; `0001_initial.py` captures the baseline schema.

## Services

Located in `apps/monitoring/services/`:

- `AllthingsWaveClient` – API client for radon + environment readings (implements `SensorConnector` interface).
- `WeatherClient` – Fetch current conditions by coordinates or city.
- `OllamaClient` – Interact with local Ollama models (`generate`, `list_models`).
- `RecommendationEngine` – Combine heuristics and LLM prompts to produce actionable guidance.
- `HomeAssistantClient` – Publish sensor state and trigger events inside Home Assistant.
- `SensorConnector` – Abstract base class for future sensors (Govee, EcoQube, etc.).

## Views & API Endpoints

Routes defined in `apps/monitoring/urls.py`:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health/` | GET | Readiness probe, returns `{"status": "ok"}`. |
| `/api/devices/` | GET | List known `SensorDevice` records. |
| `/api/summary/` | GET | Aggregate radon, weather, environment, and AI recommendations. Query params: `device_id`, `lat`, `lon`, `city`, `model`. |
| `/api/recommendations/` | GET | Latest `Recommendation` entries (default 50). |
| `/api/ai/models/` | GET | Return Ollama model catalog for UI model picker. |

### Summary Workflow

1. Pull Allthings Wave devices and readings (if API key provided).
2. Store readings in DB via `_record_reading` helper.
3. Fetch weather data using coordinates or city if configured.
4. Generate recommendations via `RecommendationEngine` (heuristics + Ollama).
5. Store recommendations and push updates to Home Assistant sensors (if configured).
6. Serialize combined payload for the frontend.

### Error Handling

- Metadata payload includes warnings/errors when integrations fail (e.g., missing API key, unreachable Ollama).
- Exceptions during Home Assistant sync are collected under `metadata.home_assistant_errors`.

## Testing

Tests live in `apps/monitoring/tests/`:

- `test_health.py` – Health endpoint smoke test.
- `test_devices.py` – Device list response.
- `test_summary.py` – Summary endpoint default response when integrations disabled.

Run tests via `python manage.py test` or through Docker Compose (`docker compose run --rm backend python manage.py test`).

## Administration

- Use `python manage.py createsuperuser` to access Django admin (`/admin/`).
- Register additional sensors through admin or custom management commands as needed.

## Extending the Backend

1. **New Sensor** – Subclass `SensorConnector`, create service, and integrate into `SummaryView` or background jobs.
2. **New AI Model** – Update env var `OLLAMA_MODEL`, ensure the model is available in Ollama (`ollama pull <model>`).
3. **Home Assistant Entities** – Adjust entity IDs or add event triggers in `HomeAssistantClient` calls.
4. **Background Tasks** – Introduce Celery/Redis or Django-Q for scheduled polling instead of request-driven flow.
