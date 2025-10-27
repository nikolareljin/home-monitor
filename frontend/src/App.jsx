import React from 'react';
import Layout from './components/Layout.jsx';
import MetricCard from './components/MetricCard.jsx';
import RecommendationList from './components/RecommendationList.jsx';
import WeatherCard from './components/WeatherCard.jsx';
import EnvironmentCard from './components/EnvironmentCard.jsx';
import DeviceSidebar from './components/DeviceSidebar.jsx';
import { useSummary } from './hooks/useSummary.js';
import './styles/dashboard.css';

export default function App() {
  const {
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
  } = useSummary();

  const header = (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '1rem' }}>
        <div>
          <h2 style={{ margin: 0 }}>Home Environment Dashboard</h2>
          <p style={{ margin: '0.25rem 0', color: '#475569' }}>
            Current device:{' '}
            <strong>{selectedDevice ? selectedDevice.name : 'None selected'}</strong>
          </p>
        </div>
        {models.length ? (
          <label style={{ fontSize: '0.9rem', color: '#475569', display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
            AI Model
            <select
              value={selectedModel?.name || ''}
              onChange={(event) => {
                const chosen = models.find((model) => model.name === event.target.value);
                setSelectedModel(chosen || null);
              }}
              style={{
                padding: '0.5rem 0.75rem',
                borderRadius: '0.5rem',
                border: '1px solid rgba(100,116,139,0.4)',
                minWidth: '220px',
              }}
            >
              {models.map((model) => (
                <option key={model.name} value={model.name}>
                  {model.name}
                </option>
              ))}
            </select>
          </label>
        ) : null}
      </div>
      {summary?.metadata?.warning && (
        <p style={{ color: '#f59e0b', margin: 0 }}>{summary.metadata.warning}</p>
      )}
      {summary?.metadata?.error && (
        <p style={{ color: '#ef4444', margin: 0 }}>{summary.metadata.error}</p>
      )}
      {summary?.metadata?.home_assistant_errors && (
        <p style={{ color: '#ef4444', margin: 0 }}>
          Home Assistant sync issues: {summary.metadata.home_assistant_errors.join(', ')}
        </p>
      )}
    </div>
  );

  const sidebar = (
    <DeviceSidebar devices={devices} selectedDevice={selectedDevice} onSelect={setSelectedDevice} />
  );

  let content = null;

  if (loading && !summary) {
    content = <p>Loading data...</p>;
  } else if (error) {
    content = <p style={{ color: '#ef4444' }}>Failed to load data: {error.message}</p>;
  } else if (summary) {
    content = (
      <>
        <div className="cards">
          <MetricCard
            title="Radon Level"
            value={radonValue !== null && radonValue !== undefined ? Number(radonValue).toFixed(2) : '—'}
            unit={radonUnit}
            description="Based on latest Allthings Wave readings"
          />
          <EnvironmentCard environment={summary.environment} />
          <WeatherCard weather={summary.weather} />
        </div>
        <section>
          {summary?.metadata?.ollama_error && (
            <p style={{ color: '#ef4444' }}>AI engine issue: {summary.metadata.ollama_error}</p>
          )}
          <h3 style={{ marginBottom: '1rem' }}>AI Recommendations</h3>
          <RecommendationList recommendations={summary.recommendations || []} />
        </section>
      </>
    );
  }

  return <Layout header={header} sidebar={sidebar}>{content}</Layout>;
}
