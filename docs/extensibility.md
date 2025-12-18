# Extensibility & Roadmap

Home Monitor was designed to grow beyond Allthings Wave radon monitors. This guide outlines extension points and future enhancements for maintainers.

## Sensor Integrations

### SensorConnector Abstraction

- Base class in `apps.monitoring.services.base.SensorConnector`.
- Implement `fetch_devices` and `fetch_latest` methods for new vendors.
- Keep payload normalization inside connector to minimize changes in views.

### Potential Targets

| Vendor | Data | Notes |
|--------|------|-------|
| Govee | Temperature, humidity | BLE/Wi-Fi sensors; requires API key or local LAN access.
| EcoQube | Radon | Similar to Allthings Wave; monitor API structure.
| Airthings | CO₂, VOC, radon | Potential cross-compatibility depending on API licensing.

### Integration Steps

1. Implement connector in `apps/monitoring/services/`.
2. Update `SummaryView` (or background jobs) to ingest new readings.
3. Extend serializers to expose metrics to the frontend.
4. Optionally publish new metrics to Home Assistant.

## Automation & Home Assistant

- Current implementation publishes radon and temperature sensors and a recommendation sensor + event/notification for the latest AI guidance.
- Use MQTT ingestion for Zigbee (via Zigbee2MQTT) and Matter bridges; map payload keys to metrics and let Home Monitor persist readings automatically.
- Future enhancements: trigger custom events, create scripts/automations directly via HA API, map recommendations to `input_boolean` or `script` entities.
- Consider bi-directional updates (e.g., Home Assistant triggers data pulls).

## Analytics & History

- Add historical tables or time-series DB (TimescaleDB, Influx) to store raw sampling data.
- Provide trend charts and anomaly detection in frontend.
- Implement scheduled tasks (Celery beat) for consistent sampling.

## AI Enhancements

- Multi-model ensembles: combine heuristics with multiple LLM outputs.
- Confidence calibration: incorporate sensor reliability scores.
- Natural language queries: allow user prompts to query historical data.
- Safety guardrails: implement policy checks on AI output before displaying or acting.

## Frontend Roadmap

- Multi-device overview page.
- Mobile-first responsive design.
- Notification settings (e-mail, push) tied to recommendations.
- Integration with Home Assistant dashboards (iframe or plugin).

## Testing & Observability

- Expand test suite (integration tests, contract tests against vendor APIs).
- Add logging configuration and metrics exporters (Prometheus).
- Implement alerting for sustained high radon levels.

## Contribution Practices

- Update docs when adding new connectors or deployment options.
- Provide env variable documentation and migration scripts for DB changes.
- Review AI prompts for clarity and bias.
