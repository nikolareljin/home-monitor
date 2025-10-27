import React from 'react';

export default function EnvironmentCard({ environment }) {
  if (!environment) {
    return null;
  }

  return (
    <div className="card">
      <h3>Indoor Environment</h3>
      <p style={{ margin: '0.25rem 0' }}>Temperature: {environment.temperature ?? '—'}°C</p>
      <p style={{ margin: '0.25rem 0' }}>Humidity: {environment.humidity ?? '—'}%</p>
      {environment.timestamp && (
        <p style={{ margin: '0.25rem 0', color: '#94a3b8' }}>
          Updated: {new Date(environment.timestamp).toLocaleString()}
        </p>
      )}
    </div>
  );
}
