import React from 'react';

export default function RecommendationList({ recommendations = [] }) {
  if (!recommendations.length) {
    return <p style={{ color: '#64748b' }}>No recommendations yet. Trigger a sync to fetch fresh insights.</p>;
  }

  return (
    <div className="recommendations">
      {recommendations.map((rec) => (
        <article key={rec.id} className="recommendation">
          <header style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.75rem' }}>
            <span style={{ fontWeight: 600, textTransform: 'capitalize' }}>{rec.category.replace('_', ' ')}</span>
            {rec.confidence && (
              <span style={{ fontSize: '0.85rem', color: '#94a3b8' }}>Confidence: {(rec.confidence * 100).toFixed(0)}%</span>
            )}
          </header>
          <p style={{ margin: 0, whiteSpace: 'pre-line' }}>{rec.message}</p>
          <footer style={{ fontSize: '0.75rem', marginTop: '0.75rem', color: '#94a3b8' }}>
            {new Date(rec.created_at).toLocaleString()}
          </footer>
        </article>
      ))}
    </div>
  );
}
