from __future__ import annotations

import datetime as dt
import os
from typing import Any, Dict, List, Optional

from django.conf import settings
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Recommendation, SensorDevice, SensorReading
from .serializers import InsightSerializer, RecommendationSerializer, SensorDeviceSerializer
from .services import AllthingsWaveClient, HomeAssistantClient, OllamaClient, RecommendationEngine, WeatherClient


def _parse_timestamp(raw: Any) -> dt.datetime:
    if raw is None:
        return timezone.now()
    if isinstance(raw, dt.datetime):
        return raw if timezone.is_aware(raw) else timezone.make_aware(raw)
    if isinstance(raw, str):
        parsed = parse_datetime(raw.replace("Z", "+00:00"))
        if parsed is None:
            return timezone.now()
        return parsed if timezone.is_aware(parsed) else timezone.make_aware(parsed)
    return timezone.now()


def _ensure_device_record(device_payload: Dict[str, Any]) -> SensorDevice:
    identifier = device_payload.get("id") or device_payload.get("slug") or device_payload.get("serial")
    if not identifier:
        raise ValueError("Device payload missing id/slug")

    defaults = {
        "name": device_payload.get("name", identifier),
        "manufacturer": device_payload.get("manufacturer", "Allthings Wave"),
        "sensor_type": device_payload.get("sensor_type", "radon"),
        "connection_type": "api",
        "metadata": device_payload,
    }
    device, _ = SensorDevice.objects.update_or_create(slug=identifier, defaults=defaults)
    return device


def _record_reading(
    *,
    device: SensorDevice,
    metric: str,
    value: float,
    unit: str,
    timestamp: Any,
    payload: Dict[str, Any],
) -> SensorReading:
    ts = _parse_timestamp(timestamp)
    reading, _ = SensorReading.objects.update_or_create(
        device=device,
        metric=metric,
        timestamp=ts,
        defaults={"value": value, "unit": unit, "raw_payload": payload},
    )
    return reading


class HealthView(APIView):
    """Lightweight readiness probe."""

    authentication_classes: list = []
    permission_classes: list = []

    def get(self, request):  # noqa: D401 - APIView signature
        return Response({"status": "ok"}, status=status.HTTP_200_OK)


class DeviceListView(APIView):
    """List configured sensors."""

    def get(self, request):  # noqa: D401 - APIView signature
        devices = SensorDevice.objects.all()
        serializer = SensorDeviceSerializer(devices, many=True)
        return Response(serializer.data)


class OllamaModelListView(APIView):
    """Expose available Ollama models so the UI can choose which to run."""

    def get(self, request):  # noqa: D401 - APIView signature
        if not (settings.OLLAMA_BASE_URL and settings.DEFAULT_OLLAMA_MODEL):
            return Response({"models": []})
        try:
            client = OllamaClient(settings.OLLAMA_BASE_URL, settings.DEFAULT_OLLAMA_MODEL)
            models = client.list_models()
            simplified = [
                {"name": item.get("name"), "modified_at": item.get("modified_at")}
                for item in models
            ]
            return Response({"models": simplified})
        except Exception as exc:  # pragma: no cover
            return Response({"error": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)


class SummaryView(APIView):
    """Aggregate radon, weather, and AI insights."""

    def get(self, request):  # noqa: D401 - APIView signature
        metadata: Dict[str, Any] = {}

        radon_payload: Optional[Dict[str, Any]] = None
        environment_payload: Optional[Dict[str, Any]] = None
        weather_payload: Optional[Dict[str, Any]] = None
        recommendations_payload: List[Dict[str, Any]] = []

        device_slug = request.query_params.get("device_id")
        device_obj: Optional[SensorDevice] = None

        if settings.ALLTHINGS_WAVE_API_KEY:
            try:
                wave_client = AllthingsWaveClient(
                    settings.ALLTHINGS_WAVE_BASE_URL,
                    settings.ALLTHINGS_WAVE_API_KEY,
                )
                devices = wave_client.list_devices()
                metadata["devices"] = devices
                if not device_slug and devices:
                    device_slug = devices[0].get("id")

                if device_slug:
                    device_payload = next((d for d in devices if d.get("id") == device_slug), None)
                    if device_payload:
                        device_obj = _ensure_device_record(device_payload)
                        radon_payload = wave_client.latest_radon_readings(device_slug)
                        radon_value = radon_payload.get("value") or radon_payload.get("pCiL")
                        if radon_value is not None:
                            _record_reading(
                                device=device_obj,
                                metric="radon",
                                value=float(radon_value),
                                unit=radon_payload.get("unit", "pCi/L"),
                                timestamp=radon_payload.get("timestamp"),
                                payload=radon_payload,
                            )
                        environment_payload = wave_client.latest_environmental_snapshot(device_slug)
                        if environment_payload:
                            temp = environment_payload.get("temperature")
                            humidity = environment_payload.get("humidity")
                            ts = environment_payload.get("timestamp")
                            if temp is not None:
                                _record_reading(
                                    device=device_obj,
                                    metric="temperature",
                                    value=float(temp),
                                    unit=environment_payload.get("temperature_unit", "°C"),
                                    timestamp=ts,
                                    payload=environment_payload,
                                )
                            if humidity is not None:
                                _record_reading(
                                    device=device_obj,
                                    metric="humidity",
                                    value=float(humidity),
                                    unit=environment_payload.get("humidity_unit", "%"),
                                    timestamp=ts,
                                    payload=environment_payload,
                                )
                    else:
                        metadata["warning"] = f"Device {device_slug} not found in Allthings Wave account"
            except Exception as exc:  # pragma: no cover - defensive log
                metadata["error"] = f"Allthings Wave sync failed: {exc}"
        else:
            metadata["warning"] = "Allthings Wave integration is not configured"

        weather_api_key = settings.WEATHER_API_KEY
        if weather_api_key:
            latitude = request.query_params.get("lat") or os.environ.get("WEATHER_LAT")
            longitude = request.query_params.get("lon") or os.environ.get("WEATHER_LON")
            city = request.query_params.get("city") or os.environ.get("WEATHER_CITY")
            try:
                weather_client = WeatherClient(settings.WEATHER_API_BASE_URL, weather_api_key)
                if latitude and longitude:
                    weather_payload = weather_client.current_by_coordinates(float(latitude), float(longitude))
                elif city:
                    weather_payload = weather_client.current_by_city(city)
            except Exception as exc:  # pragma: no cover
                metadata["weather_error"] = str(exc)

        radon_data = (
            {
                "value": radon_payload.get("value") or radon_payload.get("pCiL"),
                "unit": radon_payload.get("unit", "pCi/L"),
                "timestamp": str(radon_payload.get("timestamp")),
            }
            if radon_payload
            else None
        )
        environment_data = (
            {
                "temperature": environment_payload.get("temperature"),
                "humidity": environment_payload.get("humidity"),
                "timestamp": str(environment_payload.get("timestamp")),
            }
            if environment_payload
            else None
        )

        if settings.OLLAMA_BASE_URL and settings.DEFAULT_OLLAMA_MODEL and (radon_data or environment_data):
            try:
                ollama_client = OllamaClient(settings.OLLAMA_BASE_URL, settings.DEFAULT_OLLAMA_MODEL)
                recommender = RecommendationEngine(ollama_client)
                generated = recommender.generate(
                    radon=radon_data,
                    environment=environment_data,
                    weather=weather_payload,
                    model=request.query_params.get("model"),
                )
                saved: List[Recommendation] = []
                for item in generated:
                    saved.append(
                        Recommendation.objects.create(
                            device=device_obj,
                            category=item.get("category", "general"),
                            message=item.get("message", ""),
                            confidence=item.get("confidence"),
                            context=item.get("context", {}),
                        )
                    )
                recommendations_payload = RecommendationSerializer(saved, many=True).data
            except Exception as exc:  # pragma: no cover
                metadata["ollama_error"] = str(exc)


        if settings.HOME_ASSISTANT_TOKEN and device_obj:
            try:
                ha_client = HomeAssistantClient(settings.HOME_ASSISTANT_BASE_URL, settings.HOME_ASSISTANT_TOKEN)
                if radon_data and radon_data.get('value') is not None:
                    ha_client.publish_sensor_state(
                        f"sensor.radon_{device_obj.slug}",
                        radon_data['value'],
                        {
                            "unit_of_measurement": radon_data.get('unit', 'pCi/L'),
                            "friendly_name": f"{device_obj.name} Radon",
                        },
                    )
                if environment_data and environment_data.get('temperature') is not None:
                    ha_client.publish_sensor_state(
                        f"sensor.temperature_{device_obj.slug}",
                        environment_data['temperature'],
                        {
                            "unit_of_measurement": '°C',
                            "humidity": environment_data.get('humidity'),
                            "friendly_name": f"{device_obj.name} Temperature",
                        },
                    )
                if recommendations_payload:
                    top_rec = recommendations_payload[0]
                    recommendation_entity = f"sensor.home_monitor_recommendation_{device_obj.slug}"
                    rec_attrs = {
                        "category": top_rec.get("category"),
                        "confidence": top_rec.get("confidence"),
                        "device": device_obj.name,
                        "context": top_rec.get("context") or {},
                    }
                    if weather_payload:
                        rec_attrs["weather"] = weather_payload
                    if environment_data:
                        rec_attrs["environment"] = environment_data
                    ha_client.publish_sensor_state(
                        recommendation_entity,
                        top_rec.get("message", ""),
                        rec_attrs,
                    )
                    ha_client.trigger_event(
                        "home_monitor_recommendation",
                        {
                            "device_slug": device_obj.slug,
                            "device_name": device_obj.name,
                            "category": top_rec.get("category"),
                            "message": top_rec.get("message"),
                            "confidence": top_rec.get("confidence"),
                            "context": top_rec.get("context") or {},
                            "weather": weather_payload,
                            "environment": environment_data,
                            "radon": radon_data,
                        },
                    )
                    ha_client.create_notification(
                        title=f"Home Monitor: {device_obj.name}",
                        message=top_rec.get("message", "New recommendation available"),
                        notification_id=f"home_monitor_{device_obj.slug}",
                    )
            except Exception as exc:  # pragma: no cover
                metadata.setdefault('home_assistant_errors', []).append(str(exc))

        payload = {
            "radon": radon_data,
            "environment": environment_data,
            "weather": weather_payload,
            "recommendations": recommendations_payload,
            "metadata": metadata,
        }
        serializer = InsightSerializer(payload)
        return Response(serializer.data, status=status.HTTP_200_OK)


class RecommendationHistoryView(APIView):
    """Return historical AI suggestions."""

    def get(self, request):
        qs = Recommendation.objects.all().order_by("-created_at")[:50]
        serializer = RecommendationSerializer(qs, many=True)
        return Response(serializer.data)
