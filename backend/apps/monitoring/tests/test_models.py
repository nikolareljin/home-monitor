from unittest import mock

from django.test import override_settings
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

# "model-a:1b" and "other:7b" are placeholders, not models: the test needs
# names it controls, and a real one would be a second copy of ai-models.env.


@override_settings(OLLAMA_BASE_URL="http://ollama.invalid:11434", DEFAULT_OLLAMA_MODEL="model-a:1b")
class ModelListTests(APITestCase):
    @mock.patch("apps.monitoring.views.OllamaClient")
    def test_names_the_project_model_among_all_the_ollama_has(self, client_cls):
        """A shared Ollama lists every model on the machine; the UI must not
        take the first of them for this project's."""
        client_cls.return_value.list_models.return_value = [
            {"name": "other:7b", "modified_at": "x"},
            {"name": "model-a:1b", "modified_at": "y"},
        ]
        response = self.client.get(reverse("ollama-models"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        payload = response.json()
        self.assertEqual(payload["default"], "model-a:1b")
        self.assertEqual([m["name"] for m in payload["models"]], ["other:7b", "model-a:1b"])
