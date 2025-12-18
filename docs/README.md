# Home Monitor Documentation

This directory captures architecture, configuration, and operational guidance for the Home Monitor project. Each document focuses on a specific aspect of the stack so the repository can scale to additional sensors, AI models, and home automation endpoints over time.

## Contents

- [Project Overview](overview.md) – Concept, architecture, and data flow.
- [Backend Guide](backend.md) – Django services, integrations, storage, and API references.
- [AI & Analytics](ai.md) – How heuristics and Ollama collaborate, prompt design, and tuning guidance.
- [Frontend Guide](frontend.md) – React/Vite dashboard, component structure, and UX considerations.
- [Deployment Guide](deployment.md) – Docker Compose, host helper scripts (`./start`, `./stop`, `./dev`), production hardening, and operations.
- [Extensibility & Roadmap](extensibility.md) – Adding sensors, Home Assistant automations, and future ideas.

Run `./update` after pulling to sync the `scripts/script-helpers` submodule (and any future helper dependencies) so the host scripts stay in lockstep.

> Keep the docs current when adding new integrations or changing the deployment topology.
