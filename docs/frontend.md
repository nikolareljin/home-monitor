# Frontend Guide

The frontend is a React 18 application built with Vite and bundled into a static site served by Nginx. It visualises sensor telemetry, weather data, and AI recommendations while offering controls for device selection and LLM choice.

## Stack

- React 18 with functional components and hooks.
- Axios for API communication (`src/api/client.js`).
- Vite dev server for local development, Nginx for production.
- Recharts (planned) for future visualisation add-ons.
- CSS modules under `src/styles/` for layout and theming.

## Structure

```
frontend/
├── src/
│   ├── App.jsx
│   ├── main.jsx
│   ├── api/client.js
│   ├── components/
│   │   ├── DeviceSidebar.jsx
│   │   ├── EnvironmentCard.jsx
│   │   ├── Layout.jsx
│   │   ├── MetricCard.jsx
│   │   ├── RecommendationList.jsx
│   │   └── WeatherCard.jsx
│   ├── hooks/useSummary.js
│   └── styles/
│       ├── dashboard.css
│       └── global.css
└── Dockerfile (multi-stage: build + nginx)
```

## Key Concepts

- **Device Picker** – `DeviceSidebar` lists all sensors from `/api/devices/`; selection triggers summary reload.
- **Model Picker** – Header dropdown built from `/api/ai/models/`; defaults to `VITE_DEFAULT_OLLAMA_MODEL` if available.
- **Summary Hook (`useSummary`)** – Coordinates API calls, stores loading/error states, and memoizes derived values.
- **Cards** – Present radon, indoor environment, and weather metrics in responsive grid layout.
- **Recommendations Panel** – Displays heuristics + AI insights, highlighting backend error messages when present.

## Environment Variables

Handled via Vite at build time:

- `VITE_API_BASE_URL` – Base URL for backend API (defaults to `/api`).
- `VITE_DEFAULT_OLLAMA_MODEL` – Preferred LLM name to pre-select.

In production Docker build, these are passed as build args (`frontend/Dockerfile`). For local development, set them in `.env` or run `npm run dev` with CLI overrides.

## Local Development

```bash
cd frontend
npm install
npm run dev -- --host 0.0.0.0 --port 5173
```

This mode proxies `/api` to the backend as defined in `vite.config.js`.

## Production Build

1. `npm run build` creates static assets in `dist/`.
2. Nginx serves the assets with `index.html` fallback for client-side routing (`nginx.conf`).
3. Docker image exposes port 80; Compose maps to host port 8080.

## Error Handling

- Loading and error states displayed when summary fetch fails.
- Metadata warnings/errors surfaced in header (API-level notifications).
- Ollama errors highlighted above the recommendations list.

## Future Enhancements

- Historical charts (radon trend, humidity trend) with Recharts.
- Manual refresh controls or auto-refresh intervals.
- Multi-room overview with summary cards per device.
- Responsive mobile layout improvements (current styles target desktop first).
- Component tests (React Testing Library or Cypress) for UI validation.
