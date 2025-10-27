from __future__ import annotations

from typing import Any, Dict, Optional

import requests


class WeatherClient:
    """Fetch current weather conditions from a supported provider."""

    def __init__(
        self,
        base_url: str,
        api_key: str,
        timeout: int = 10,
        session: Optional[requests.Session] = None,
    ) -> None:
        if not api_key:
            raise ValueError("Weather API key is required")
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout
        self.session = session or requests.Session()

    def current_by_coordinates(self, latitude: float, longitude: float, units: str = "metric") -> Dict[str, Any]:
        params = {
            "lat": latitude,
            "lon": longitude,
            "appid": self.api_key,
            "units": units,
        }
        response = self.session.get(
            f"{self.base_url}/weather",
            params=params,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()

    def current_by_city(self, city: str, country_code: Optional[str] = None, units: str = "metric") -> Dict[str, Any]:
        query = f"{city},{country_code}" if country_code else city
        params = {
            "q": query,
            "appid": self.api_key,
            "units": units,
        }
        response = self.session.get(
            f"{self.base_url}/weather",
            params=params,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()
