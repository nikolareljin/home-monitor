from __future__ import annotations

from typing import Any, Dict, Optional

import requests


class HomeAssistantClient:
    """Push updates to Home Assistant entities and events."""

    def __init__(
        self,
        base_url: str,
        token: str,
        timeout: int = 10,
        session: Optional[requests.Session] = None,
    ) -> None:
        if not token:
            raise ValueError("Home Assistant token is required")
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.session = session or requests.Session()
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    def publish_sensor_state(self, entity_id: str, state: Any, attributes: Optional[Dict[str, Any]] = None) -> None:
        payload = {"state": state, "attributes": attributes or {}}
        response = self.session.post(
            f"{self.base_url}/api/states/{entity_id}",
            json=payload,
            timeout=self.timeout,
            headers=self.headers,
        )
        response.raise_for_status()

    def trigger_event(self, event_type: str, data: Optional[Dict[str, Any]] = None) -> None:
        response = self.session.post(
            f"{self.base_url}/api/events/{event_type}",
            json=data or {},
            timeout=self.timeout,
            headers=self.headers,
        )
        response.raise_for_status()

    def create_notification(self, title: str, message: str, notification_id: Optional[str] = None) -> None:
        payload: Dict[str, Any] = {"title": title, "message": message}
        if notification_id:
            payload["notification_id"] = notification_id
        response = self.session.post(
            f"{self.base_url}/api/services/persistent_notification/create",
            json=payload,
            timeout=self.timeout,
            headers=self.headers,
        )
        response.raise_for_status()
