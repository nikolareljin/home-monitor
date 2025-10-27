from django.contrib import admin

from .models import Recommendation, SensorDevice, SensorReading


@admin.register(SensorDevice)
class SensorDeviceAdmin(admin.ModelAdmin):
    list_display = ("name", "manufacturer", "sensor_type", "connection_type", "created_at")
    search_fields = ("name", "manufacturer", "sensor_type")
    prepopulated_fields = {"slug": ("name",)}


@admin.register(SensorReading)
class SensorReadingAdmin(admin.ModelAdmin):
    list_display = ("device", "metric", "value", "unit", "timestamp")
    list_filter = ("metric", "unit", "device__sensor_type")
    search_fields = ("device__name", "metric")


@admin.register(Recommendation)
class RecommendationAdmin(admin.ModelAdmin):
    list_display = ("category", "device", "confidence", "created_at")
    search_fields = ("category", "message")
    list_filter = ("category",)
