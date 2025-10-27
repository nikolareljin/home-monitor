from django.urls import path

from .views import DeviceListView, RecommendationHistoryView, SummaryView, OllamaModelListView, HealthView

urlpatterns = [
    path("health/", HealthView.as_view(), name="health-check"),
    path("devices/", DeviceListView.as_view(), name="device-list"),
    path("summary/", SummaryView.as_view(), name="summary"),
    path("recommendations/", RecommendationHistoryView.as_view(), name="recommendation-history"),
    path("ai/models/", OllamaModelListView.as_view(), name="ollama-models"),
]
