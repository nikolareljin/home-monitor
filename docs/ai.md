# AI & Analytics

Home Monitor couples deterministic heuristics with a locally hosted large language model (LLM) to produce actionable recommendations. This document explains the flow so future contributors can refine prompts, plug in alternative models, or adjust thresholds for safety-critical scenarios like radon management.

## Components

- **RecommendationEngine** (`apps.monitoring.services.recommendations`) – Orchestrates heuristics + LLM call.
- **OllamaClient** (`apps.monitoring.services.ollama`) – HTTP client targeting the local Ollama daemon.
- **Sensor Data** – Radon, temperature, humidity, and weather snapshots passed into the engine.

## Heuristic Layer

Radon and environment heuristics ensure the system gives conservative advice even if the LLM is unavailable:

- Radon thresholds: caution at ≥4.0 pCi/L, elevated at ≥8.0 pCi/L.
- Temperature prompts: cooling advice above 27 °C, heating below 18 °C.
- Humidity prompts: dehumidify above 60 %, humidify below 30 %.
- Weather context: avoid opening windows when outdoor temperature is extreme (< 5 °C or > 32 °C).

Each heuristic returns a structured recommendation (`category`, `message`, `confidence`, `context`).

## LLM Layer

When `OLLAMA_BASE_URL` and `OLLAMA_MODEL` are configured, `RecommendationEngine.generate` builds an enriched prompt:

- Summaries of recent radon, indoor environment, and weather data.
- Instructions prioritising safety, enumerating specific actions, and limiting the response to three bullet points.
- Timestamp and observation window for context.

The default system prompt: “Provide practical home monitoring advice.”

### Prompt Structure

```
You are an indoor air quality assistant helping a homeowner optimise ventilation, heating, and cooling.
Current timestamp: <UTC>.
Review the last <window> hours of data ...
Radon data:
<dict>
Indoor environment:
<dict>
Weather data:
<dict>
```

### Model Selection

- Default model drawn from `OLLAMA_MODEL` (e.g., `llama2`).
- Frontend model picker hits `/api/ai/models/` to list models from `ollama /api/tags`.
- Clients can override by passing `?model=name` to `/api/summary/`.

### Response Handling

- Expected JSON: `{"response": "...", "done_reason": "stop"}`.
- Confidence defaults to 0.75 when `done_reason == "stop"`, otherwise 0.5.
- Result is stored as a `Recommendation` with `category="ai_insight"`.

## Failover Behaviour

If the Ollama service is down or misconfigured:

- The API returns `metadata.ollama_error` with the exception message.
- Heuristic recommendations still populate the response.
- Frontend displays the error banner and partially degraded data.

## Tuning & Extensions

1. **Adjust thresholds** – Update constants in `RecommendationEngine` to match local standards.
2. **Prompt tweaks** – Modify `_build_prompt` to include occupancy schedules, HVAC capabilities, or sensor history.
3. **Streaming / long responses** – Extend `OllamaClient.generate` to support streaming if desired.
4. **Analytics storage** – Persist more detailed context in the `Recommendation` model for auditing.
5. **Alternate models** – Users can `ollama pull` domain-specific models (e.g., `mistral`, `phi`) and set as default.
6. **Multi-modal** – Future connectors could augment prompts with CO₂, VOC, or particulate matter data.

## Privacy & Safety Considerations

- Keep LLM prompts anonymised; avoid personal data in context payloads.
- Validate radon levels using regulatory guidance (EPA, WHO) and highlight emergency actions where necessary.
- Consider adding guardrails (e.g., allowlist responses, severity scoring) before triggering automations.
