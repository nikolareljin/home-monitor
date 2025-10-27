import React from 'react';

export default function DeviceSidebar({ devices, selectedDevice, onSelect }) {
  return (
    <div>
      <h1>Home Monitor</h1>
      <p style={{ fontSize: '0.85rem', color: '#cbd5f5', marginBottom: '1.5rem' }}>
        Track radon, comfort, and AI-driven recommendations in one place.
      </p>
      {devices.map((device) => {
        const identifier = device.slug || device.id;
        const isActive = selectedDevice && (selectedDevice.slug === identifier || selectedDevice.id === identifier);
        return (
          <button
            key={identifier}
            type="button"
            className={isActive ? 'active' : ''}
            onClick={() => onSelect(device)}
          >
            <span style={{ display: 'block', fontWeight: 600 }}>{device.name}</span>
            <span style={{ fontSize: '0.75rem', opacity: 0.8 }}>{device.manufacturer}</span>
          </button>
        );
      })}
    </div>
  );
}
