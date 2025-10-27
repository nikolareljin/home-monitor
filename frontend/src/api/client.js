import axios from 'axios';

const client = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
});

export async function fetchSummary(params = {}) {
  const response = await client.get('/summary/', { params });
  return response.data;
}

export async function fetchDevices() {
  const response = await client.get('/devices/');
  return response.data;
}

export async function fetchRecommendations() {
  const response = await client.get('/recommendations/');
  return response.data;
}

export async function fetchModels() {
  const response = await client.get('/ai/models/');
  return response.data;
}

export default client;
