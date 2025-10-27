from __future__ import annotations

from rest_framework import serializers

from .models import Recommendation, SensorDevice, SensorReading


class SensorReadingSerializer(serializers.ModelSerializer):
    class Meta:
        model = SensorReading
        fields = ["id", "device", "metric", "value", "unit", "timestamp", "raw_payload", "created_at"]


class SensorDeviceSerializer(serializers.ModelSerializer):
    readings = SensorReadingSerializer(many=True, read_only=True)

    class Meta:
        model = SensorDevice
        fields = [
            "id",
            "name",
            "slug",
            "manufacturer",
            "sensor_type",
            "connection_type",
            "metadata",
            "created_at",
            "updated_at",
            "readings",
        ]


class RecommendationSerializer(serializers.ModelSerializer):
    device = SensorDeviceSerializer(read_only=True)

    class Meta:
        model = Recommendation
        fields = ["id", "device", "category", "message", "confidence", "context", "created_at"]


class InsightSerializer(serializers.Serializer):
    """Aggregated payload that combines sensor data, weather, and insights."""

    radon = serializers.DictField(child=serializers.FloatField(), required=False)
    weather = serializers.DictField(child=serializers.CharField(), required=False)
    environment = serializers.DictField(child=serializers.CharField(), required=False)
    recommendations = RecommendationSerializer(many=True)
    metadata = serializers.DictField(child=serializers.CharField(), required=False)
