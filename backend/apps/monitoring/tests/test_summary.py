from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase


class SummaryViewTests(APITestCase):
    def test_summary_returns_warning_when_no_integrations(self):
        response = self.client.get(reverse('summary'))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('metadata', response.data)
        self.assertIn('warning', response.data['metadata'])
        self.assertIsNone(response.data['radon'])
