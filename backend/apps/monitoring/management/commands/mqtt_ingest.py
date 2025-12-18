from __future__ import annotations

import logging

from django.conf import settings
from django.core.management.base import BaseCommand

from apps.monitoring.services.mqtt_listener import MqttListener

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Subscribe to MQTT topics and ingest sensor readings (supports Zigbee2MQTT and Matter topic styles)."

    def handle(self, *args, **options):
        broker_url = settings.MQTT_BROKER_URL
        if not broker_url:
            self.stderr.write(self.style.ERROR("MQTT_BROKER_URL is not set; cannot start MQTT ingestion."))
            return

        topics = settings.MQTT_TOPICS or []
        listener = MqttListener(
            broker_url=broker_url,
            port=settings.MQTT_BROKER_PORT,
            topics=topics,
            username=settings.MQTT_USERNAME,
            password=settings.MQTT_PASSWORD,
        )

        self.stdout.write(self.style.SUCCESS(f"Starting MQTT ingestion on {broker_url}:{settings.MQTT_BROKER_PORT}"))
        self.stdout.write(self.style.SUCCESS(f"Subscribing to topics: {', '.join(topics)}"))
        try:
            listener.loop_forever()
        except KeyboardInterrupt:  # pragma: no cover - manual stop
            self.stdout.write(self.style.WARNING("MQTT ingestion stopped by user"))
        except Exception as exc:  # pragma: no cover - runtime guard
            logger.exception("MQTT ingestion failed: %s", exc)
            self.stderr.write(self.style.ERROR(f"MQTT ingestion failed: {exc}"))
