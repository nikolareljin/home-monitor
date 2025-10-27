from __future__ import annotations

import datetime as dt
from typing import Any, Dict, List, Optional

import requests

from .base import SensorConnector


class AllthingsWaveClient(SensorConnector):
    """Lightweight client for Allthings Wave radon monitors."""

    slug = "allthings_wave"

    def __init__(
        self,
        base_url: str,
        api_key: str,
        timeout: int = 15,
        session: Optional[requests.Session] = None,
    ) -> None:
        if not api_key:
            raise ValueError("Allthings Wave API key is required")
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout
        self.session = session or requests.Session()

    def _headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Accept": "application/json",
        }

    def _request(self, method: str, path: str, **kwargs: Any) -> Any:
        url = f"{self.base_url}{path}"
        response = self.session.request(
            method=method,
            url=url,
            timeout=self.timeout,
            headers={**self._headers(), **kwargs.pop("headers", {})},
            **kwargs,
        )
        response.raise_for_status()
        return response.json()

    def list_devices(self) -> List[Dict[str, Any]]:
        """Return devices that belong to the authenticated account."""

        payload = self._request("GET", "/v1/devices")
        return payload.get("devices", payload)

    def latest_radon_readings(self, device_id: str) -> Dict[str, Any]:
        """Return the latest radon readings for a device."""

        payload = self._request("GET", f"/v1/devices/{device_id}/radon/latest")
        reading = payload.get("reading", payload)

        timestamp = reading.get("timestamp")
        if timestamp and isinstance(timestamp, str):
            reading["timestamp"] = dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        return reading

    def fetch_devices(self):
        return self.list_devices()

    def fetch_latest(self, device_id: str):
        return self.latest_radon_readings(device_id)

    def latest_environmental_snapshot(self, device_id: str) -> Dict[str, Any]:
        """Return the latest temperature/humidity snapshot if the device supports it."""

        payload = self._request("GET", f"/v1/devices/{device_id}/environment/latest")
        snapshot = payload.get("snapshot", payload)
        timestamp = snapshot.get("timestamp")
        if timestamp and isinstance(timestamp, str):
            snapshot["timestamp"] = dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        return snapshot
