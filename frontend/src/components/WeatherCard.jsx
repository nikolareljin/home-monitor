import React from 'react';

export default function WeatherCard({ weather }) {
  if (!weather) {
    return null;
  }
  const main = weather.main || {};
  const wind = weather.wind || {};
  const location = `${weather.name || 'Outdoor'}${weather.sys?.country ? `, ${weather.sys.country}` : ''}`;

  return (
    <div className="card">
      <h3>Outdoor Weather</h3>
      <p style={{ margin: '0.5rem 0', fontWeight: 600 }}>{location}</p>
      <p style={{ margin: '0.25rem 0' }}>Temperature: {main.temp ?? '—'}°C</p>
      <p style={{ margin: '0.25rem 0' }}>Humidity: {main.humidity ?? '—'}%</p>
      <p style={{ margin: '0.25rem 0' }}>Feels Like: {main.feels_like ?? '—'}°C</p>
      <p style={{ margin: '0.25rem 0' }}>Wind: {wind.speed ?? '—'} m/s</p>
      {weather.weather && weather.weather.length ? (
        <p style={{ margin: '0.25rem 0', textTransform: 'capitalize' }}>Conditions: {weather.weather[0].description}</p>
      ) : null}
    </div>
  );
}
