import React from 'react';

export default function Layout({ header, children, sidebar }) {
  return (
    <div className="layout">
      <aside className="sidebar">{sidebar}</aside>
      <main className="content">
        <header className="header">{header}</header>
        <section className="body">{children}</section>
      </main>
    </div>
  );
}
