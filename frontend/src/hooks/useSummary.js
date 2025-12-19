import { useEffect, useMemo, useState } from 'react';
import { fetchDevices, fetchSummary, fetchModels } from '../api/client';

export function useSummary() {
  const [loading, setLoading] = useState(true);
  const defaultModelName = import.meta.env.VITE_DEFAULT_OLLAMA_MODEL || null;
  const [error, setError] = useState(null);
  const [summary, setSummary] = useState(null);
  const [devices, setDevices] = useState([]);
  const [models, setModels] = useState([]);
  const [selectedDevice, setSelectedDevice] = useState(null);
  const [selectedModel, setSelectedModel] = useState(null);

  useEffect(() => {
    async function initialise() {
      setLoading(true);
      try {
        const [deviceList, modelList] = await Promise.all([
          fetchDevices(),
          fetchModels().catch(() => ({ models: [] })),
        ]);
        setDevices(deviceList);
        const availableModels = modelList.models || [];
        setModels(availableModels);
        if (availableModels.length) {
          const preferred = defaultModelName
            ? availableModels.find((model) => model.name === defaultModelName)
            : null;
          setSelectedModel(preferred || availableModels[0]);
        }
        if (deviceList.length) {
          setSelectedDevice(deviceList[0]);
        } else {
          setError(new Error('No devices available yet. Add a device to begin monitoring.'));
        }
      } catch (err) {
        setError(err);
      } finally {
        setLoading(false);
      }
    }
    initialise();
  }, []);

  useEffect(() => {
    async function loadSummary() {
      if (!selectedDevice) return;
      setLoading(true);
      setError(null);
      try {
        const params = { device_id: selectedDevice.slug || selectedDevice.id };
        if (selectedModel && selectedModel.name) {
          params.model = selectedModel.name;
        }
        const result = await fetchSummary(params);
        setSummary(result);
      } catch (err) {
        setError(err);
      } finally {
        setLoading(false);
      }
    }
    loadSummary();
  }, [selectedDevice, selectedModel]);

  const radonValue = summary?.radon?.value ?? null;
  const radonUnit = summary?.radon?.unit ?? 'pCi/L';

  return useMemo(
    () => ({
      loading,
      error,
      summary,
      devices,
      models,
      selectedDevice,
      setSelectedDevice,
      selectedModel,
      setSelectedModel,
      radonValue,
      radonUnit,
    }),
    [
      loading,
      error,
      summary,
      devices,
      models,
      selectedDevice,
      selectedModel,
      radonValue,
      radonUnit,
    ],
  );
}
