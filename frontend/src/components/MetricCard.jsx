import React from 'react';

export default function MetricCard({ title, value, unit, description, children }) {
  return (
    <div className="card">
      <h3>{title}</h3>
      <div style={{ fontSize: '2.5rem', fontWeight: 700, margin: '0.5rem 0' }}>
        {value ?? '—'}
        {unit && <span style={{ fontSize: '1rem', marginLeft: '0.35rem' }}>{unit}</span>}
      </div>
      {description && <p style={{ margin: '0.25rem 0 0', color: '#475569' }}>{description}</p>}
      {children}
    </div>
  );
}
