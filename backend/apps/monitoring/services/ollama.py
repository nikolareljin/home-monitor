from __future__ import annotations

from typing import Any, Dict, List, Optional

import requests


class OllamaClient:
    """HTTP client for interacting with a local Ollama server."""

    def __init__(
        self,
        base_url: str,
        default_model: str,
        timeout: int = 120,
        session: Optional[requests.Session] = None,
    ) -> None:
        if not default_model:
            raise ValueError("An Ollama model must be configured")
        self.base_url = base_url.rstrip("/")
        self.default_model = default_model
        self.timeout = timeout
        self.session = session or requests.Session()

    def generate(
        self,
        prompt: str,
        *,
        model: Optional[str] = None,
        system_prompt: Optional[str] = None,
        stream: bool = False,
    ) -> Dict[str, Any]:
        payload: Dict[str, Any] = {
            "model": model or self.default_model,
            "prompt": prompt,
            "stream": stream,
        }
        if system_prompt:
            payload["system"] = system_prompt

        response = self.session.post(
            f"{self.base_url}/api/generate",
            json=payload,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()

    def list_models(self) -> List[Dict[str, Any]]:
        response = self.session.get(f"{self.base_url}/api/tags", timeout=self.timeout)
        response.raise_for_status()
        payload = response.json()
        return payload.get("models", payload)
