# Project Overview

Home Monitor unifies indoor sensor telemetry, outdoor weather data, and AI-generated recommendations to help homeowners maintain safe, healthy air quality. The platform combines a Django backend, React dashboard, and a locally hosted Ollama model runtime. Initial support targets Allthings Wave radon monitors, but the architecture anticipates temperature, humidity, and air quality sensors from other vendors.

## Objectives

- Track radon levels and environmental metrics across rooms.
- Correlate outdoor weather with indoor air quality spikes.
- Recommend actions (open windows, run HVAC, schedule maintenance) using heuristics plus an LLM.
- Integrate with Home Assistant for automation and dashboards.
- Offer a self-contained Docker deployment for local or cloud hosting.

## Architecture

```
        ┌─────────────────────┐
        │      Frontend       │   React + Vite + Nginx
        │   (Dashboard UI)    │
        └─────────┬───────────┘
                  │ HTTP
        ┌─────────▼───────────┐
        │      Backend         │   Django REST Framework
        │  (API & Orchestration) │
        ├─────────┬───────────┤
        │         │           │
Weather API   Allthings Wave   Home Assistant
(OpenWeather)    Sensors        (optional)
        │         │           │
        └─────────▼───────────┘
          PostgreSQL Storage

        ┌─────────────────────┐
        │       Ollama        │   On-device LLM runtime
        └─────────────────────┘
```

### Data Flow
1. **Sensor Sync** – Backend polls Allthings Wave for radon/ambient readings and stores them in PostgreSQL.
2. **Weather Fetch** – Backend queries a configured weather provider (OpenWeatherMap by default).
3. **AI Analysis** – Recommendation engine fuses heuristics with an Ollama model prompt to suggest actions.
4. **Home Assistant (optional)** – Updated readings are pushed to Home Assistant sensor entities.
5. **Dashboard** – React UI displays latest metrics, environment summaries, and AI recommendations.

## Key Components

- **Django project (`home_monitor`)** – Configuration, models, REST API endpoints.
- **Monitoring app (`apps.monitoring`)** – Sensor models, services, views, and recommendations logic.
- **React dashboard (`frontend/`)** – Device selector, radon/weather cards, AI recommendations panel.
- **Docker Compose** – Services for PostgreSQL, Django backend, Ollama runtime, and Nginx-hosted frontend.

## Initial Integrations

| Domain                  | Integration            | Notes |
|-------------------------|------------------------|-------|
| Radon Monitoring        | Allthings Wave         | API-based polling with latest radon + environment snapshot.
| Outdoor Weather         | OpenWeatherMap         | Configurable by lat/lon or city. Requires API key.
| AI Recommendations      | Ollama (local models)  | Default model `llama2`, configurable via env.
| Home Automation (optional) | Home Assistant      | REST token used to publish sensor states.

## Future Goals

- Historical analytics (time-series charts, alert thresholds).
- Additional sensor vendors (Govee, EcoQube) via `SensorConnector` subclasses.
- Scheduled background tasks and notification channels.
- Automated Home Assistant scenes triggered by AI suggestions.
