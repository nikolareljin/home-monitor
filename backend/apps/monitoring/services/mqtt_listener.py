from __future__ import annotations

import json
import logging
from datetime import datetime
from typing import Any, Callable, Dict, Iterable, Optional, Tuple

import paho.mqtt.client as mqtt
from django.utils import timezone

from apps.monitoring.models import SensorDevice, SensorReading

logger = logging.getLogger(__name__)


def _infer_sensor_type(metric: str) -> str:
    metric_lower = metric.lower()
    if "radon" in metric_lower:
        return "radon"
    if "temp" in metric_lower:
        return "temperature"
    if "humid" in metric_lower:
        return "humidity"
    return "custom"


def _ensure_device(slug: str, source: str = "mqtt") -> SensorDevice:
    defaults = {
        "name": slug.replace("_", " ").title(),
        "sensor_type": "custom",
        "manufacturer": source,
        "metadata": {"source": source},
    }
    device, _ = SensorDevice.objects.get_or_create(slug=slug, defaults=defaults)
    return device


def _parse_payload(payload: bytes) -> Optional[Dict[str, Any]]:
    try:
        return json.loads(payload.decode("utf-8"))
    except Exception as exc:  # pragma: no cover - guard against malformed payloads
        logger.warning("Failed to parse MQTT payload: %s", exc)
        return None


def _persist_reading(device_slug: str, metric: str, value: Any, unit: str = "", timestamp: Optional[str] = None, source: str = "mqtt") -> None:
    device = _ensure_device(device_slug, source=source)
    sensor_type = _infer_sensor_type(metric)
    device.sensor_type = sensor_type
    device.save(update_fields=["sensor_type"])

    # Parse timestamp if provided; otherwise use now
    ts = timezone.now()
    if timestamp:
        try:
            ts = datetime.fromisoformat(timestamp)
            if ts.tzinfo is None:
                ts = timezone.make_aware(ts)
        except Exception:
            ts = timezone.now()

    SensorReading.objects.create(
        device=device,
        metric=metric,
        value=float(value),
        unit=unit or "",
        timestamp=ts,
        raw_payload={"source": source},
    )


class MqttListener:
    """Subscribe to MQTT topics and persist sensor readings."""

    def __init__(
        self,
        broker_url: str,
        port: int,
        topics: Iterable[str],
        username: str = "",
        password: str = "",
        client_id: str = "home-monitor-mqtt",
        on_message: Optional[Callable[[str, Dict[str, Any]], None]] = None,
    ) -> None:
        if not broker_url:
            raise ValueError("MQTT broker URL is required")
        self.broker_url = broker_url
        self.port = port
        self.topics = list(topics)
        self.username = username
        self.password = password
        self.client = mqtt.Client(client_id=client_id)
        self.on_message = on_message or self.default_handler

    def connect(self) -> None:
        if self.username:
            self.client.username_pw_set(self.username, self.password)
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message
        self.client.connect(self.broker_url, self.port, keepalive=60)

    def loop_forever(self) -> None:
        self.connect()
        self.client.loop_forever()

    def _on_connect(self, client: mqtt.Client, userdata: Any, flags: Dict[str, Any], rc: int) -> None:
        if rc == 0:
            logger.info("Connected to MQTT broker at %s:%s", self.broker_url, self.port)
            for topic in self.topics:
                client.subscribe(topic)
                logger.info("Subscribed to topic: %s", topic)
        else:  # pragma: no cover - connection errors
            logger.error("MQTT connection failed with code %s", rc)

    def _on_message(self, client: mqtt.Client, userdata: Any, msg: mqtt.MQTTMessage) -> None:
        payload = _parse_payload(msg.payload)
        if payload is None:
            return
        self.on_message(msg.topic, payload)

    def default_handler(self, topic: str, payload: Dict[str, Any]) -> None:
        """
        Default ingestion strategy:
        - Topic pattern: <root>/<device_slug>/<metric>
        - Payload: JSON containing at least a value; optional unit, timestamp, device_slug, metric.
        - Zigbee2MQTT: topic 'zigbee2mqtt/<device>', payload with multiple numeric keys.
        """
        parts = topic.split("/")
        device_slug = payload.get("device_slug") or (parts[1] if len(parts) > 1 else "unknown-device")
        source = "mqtt"

        # Zigbee2MQTT style: topic zigbee2mqtt/<device>, payload has many numeric keys
        if parts and parts[0].startswith("zigbee2mqtt"):
            source = "zigbee"
            for key, value in payload.items():
                if isinstance(value, (int, float)):
                    _persist_reading(device_slug, key, value, payload.get("unit", ""), payload.get("timestamp"), source=source)
            return

        # Matter bridge style: topic matter/<device>/<metric>
        if parts and parts[0].startswith("matter") and len(parts) >= 3:
            source = "matter"
            device_slug = device_slug or parts[1]
            metric = payload.get("metric") or parts[2]
            value = payload.get("value")
            if value is not None:
                _persist_reading(device_slug, metric, value, payload.get("unit", ""), payload.get("timestamp"), source=source)
            return

        # Generic: topic <root>/<device>/<metric>
        metric = payload.get("metric") or (parts[2] if len(parts) > 2 else "value")
        value = payload.get("value")
        if value is None:
            # If no explicit value, try flatten numeric keys
            for key, maybe_val in payload.items():
                if isinstance(maybe_val, (int, float)):
                    _persist_reading(device_slug, key, maybe_val, payload.get("unit", ""), payload.get("timestamp"), source=source)
            return
        _persist_reading(device_slug, metric, value, payload.get("unit", ""), payload.get("timestamp"), source=source)
