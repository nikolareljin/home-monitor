from __future__ import annotations

import datetime as dt
from typing import Any, Dict, List, Optional

from django.conf import settings

from .ollama import OllamaClient


class RecommendationEngine:
    """Combines heuristics and LLM reasoning to surface home actions."""

    # EPA safety level for radon in pCi/L (~148 Bq/m^3)
    RADON_CAUTION_THRESHOLD = 4.0
    RADON_ELEVATED_THRESHOLD = 8.0

    def __init__(
        self,
        ollama_client: OllamaClient,
        time_window_hours: Optional[int] = None,
    ) -> None:
        self.ollama = ollama_client
        self.window_hours = time_window_hours or getattr(settings, "RECOMMENDATION_WINDOW_HOURS", 6)

    def _baseline_recommendations(
        self,
        radon: Optional[Dict[str, Any]],
        environment: Optional[Dict[str, Any]],
        weather: Optional[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        actions: List[Dict[str, Any]] = []

        if radon and (level := float(radon.get("value", 0.0))) >= self.RADON_CAUTION_THRESHOLD:
            severity = "elevated" if level >= self.RADON_ELEVATED_THRESHOLD else "moderate"
            actions.append(
                {
                    "category": "air_quality",
                    "message": (
                        "Radon levels are {severity} at {level} {unit}. Increase ventilation in the basement now."
                    ).format(
                        severity=severity,
                        level=round(level, 2),
                        unit=radon.get("unit", "pCi/L"),
                    ),
                    "confidence": 0.7 if severity == "moderate" else 0.9,
                    "context": {"radon": radon},
                }
            )

        if environment:
            temp = environment.get("temperature")
            humidity = environment.get("humidity")
            suggestions: List[str] = []
            if temp is not None:
                if temp > 27:
                    suggestions.append("Consider running the AC or dehumidifier to cool the basement.")
                elif temp < 18:
                    suggestions.append("Temperature is low; consider running heating or improving insulation.")
            if humidity is not None:
                if humidity > 60:
                    suggestions.append("Humidity is high; run a dehumidifier and increase air circulation.")
                elif humidity < 30:
                    suggestions.append("Humidity is low; a humidifier or leaving water near vents can help.")

            if suggestions:
                actions.append(
                    {
                        "category": "comfort",
                        "message": " ".join(suggestions),
                        "confidence": 0.6,
                        "context": {"environment": environment},
                    }
                )

        if weather and radon:
            outside_temp = weather.get("main", {}).get("temp")
            outside_humidity = weather.get("main", {}).get("humidity")
            radon_level = radon.get("value")
            if outside_temp is not None and radon_level:
                # Simple heuristic: open windows only if outside conditions are reasonable
                if outside_temp < 5:
                    actions.append(
                        {
                            "category": "ventilation",
                            "message": "It is cold outside; prefer running the HRV/ERV system instead of opening windows to vent radon.",
                            "confidence": 0.5,
                            "context": {"weather": weather, "radon": radon},
                        }
                    )
                elif outside_temp > 32:
                    actions.append(
                        {
                            "category": "ventilation",
                            "message": "Outdoor temperature is high; ventilate briefly during cooler hours to manage radon spikes.",
                            "confidence": 0.5,
                            "context": {"weather": weather, "radon": radon},
                        }
                    )

        return actions

    def _build_prompt(self, data: Dict[str, Any]) -> str:
        radon = data.get("radon")
        weather = data.get("weather")
        environment = data.get("environment")
        window = self.window_hours
        now = dt.datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")

        return (
            "You are an indoor air quality assistant helping a homeowner optimise ventilation, heating, and cooling.\n"
            f"Current timestamp: {now}.\n"
            f"Review the last {window} hours of data (if present) and provide concise recommended actions.\n"
            "Prioritise safety when radon is high. Mention specific actions like opening basement windows, running fans,"
            " activating HVAC, or scheduling follow-up checks. When weather or humidity suggests otherwise, explain briefly.\n"
            "Conclude with at most three bullet points."
            "\n\nRadon data:\n"
            f"{radon}\n\nIndoor environment:\n{environment}\n\nWeather data:\n{weather}\n"
        )

    def generate(
        self,
        *,
        radon: Optional[Dict[str, Any]] = None,
        environment: Optional[Dict[str, Any]] = None,
        weather: Optional[Dict[str, Any]] = None,
        model: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        compiled: Dict[str, Any] = {
            "radon": radon,
            "environment": environment,
            "weather": weather,
        }
        baseline = self._baseline_recommendations(radon, environment, weather)

        prompt = self._build_prompt(compiled)
        response = self.ollama.generate(prompt, model=model, system_prompt="Provide practical home monitoring advice.")

        message = response.get("response") or ""
        if message:
            baseline.append(
                {
                    "category": "ai_insight",
                    "message": message.strip(),
                    "confidence": response.get("done_reason") == "stop" and 0.75 or 0.5,
                    "context": response,
                }
            )
        return baseline
