from __future__ import annotations

from django.db import models


class SensorDevice(models.Model):
    """Represents a physical or virtual sensor providing telemetry."""

    SENSOR_TYPES = [
        ("radon", "Radon"),
        ("temperature", "Temperature"),
        ("humidity", "Humidity"),
        ("air_quality", "Air Quality"),
        ("custom", "Custom"),
    ]

    name = models.CharField(max_length=255)
    slug = models.SlugField(unique=True)
    manufacturer = models.CharField(max_length=255, blank=True)
    sensor_type = models.CharField(max_length=50, choices=SENSOR_TYPES)
    connection_type = models.CharField(max_length=50, default="api")
    metadata = models.JSONField(blank=True, default=dict)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self) -> str:  # pragma: no cover - convenience for admin shell
        return self.name


class SensorReading(models.Model):
    """Stores individual sensor measurements."""

    device = models.ForeignKey(SensorDevice, related_name="readings", on_delete=models.CASCADE)
    metric = models.CharField(max_length=100)
    value = models.FloatField()
    unit = models.CharField(max_length=32)
    timestamp = models.DateTimeField()
    raw_payload = models.JSONField(blank=True, default=dict)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-timestamp"]
        indexes = [
            models.Index(fields=["device", "metric", "timestamp"]),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.device.name} {self.metric} @ {self.timestamp:%Y-%m-%d %H:%M}"


class Recommendation(models.Model):
    """Persists AI-generated recommendations for home actions."""

    device = models.ForeignKey(SensorDevice, related_name="recommendations", on_delete=models.SET_NULL, null=True, blank=True)
    category = models.CharField(max_length=100)
    message = models.TextField()
    confidence = models.FloatField(null=True, blank=True)
    context = models.JSONField(blank=True, default=dict)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.category}: {self.message[:50]}"
