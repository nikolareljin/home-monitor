from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.monitoring.models import SensorDevice


class DeviceListTests(APITestCase):
    def test_returns_devices(self):
        SensorDevice.objects.create(
            name='Basement Radon',
            slug='basement-radon',
            manufacturer='Allthings Wave',
            sensor_type='radon',
        )
        response = self.client.get(reverse('device-list'))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        payload = response.json()
        self.assertEqual(len(payload), 1)
        self.assertEqual(payload[0]['name'], 'Basement Radon')
        self.assertEqual(payload[0]['sensor_type'], 'radon')
