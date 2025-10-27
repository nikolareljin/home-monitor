from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Dict, Iterable


class SensorConnector(ABC):
    """Base class for hardware integrations."""

    slug: str

    @abstractmethod
    def fetch_devices(self) -> Iterable[Dict[str, Any]]:
        """Return metadata for sensors managed by this connector."""

    @abstractmethod
    def fetch_latest(self, device_id: str) -> Dict[str, Any]:
        """Return the most recent readings for the given device."""

    def prepare_payload(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Normalize payload prior to persistence or downstream use."""
        return payload
