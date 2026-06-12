import { useState, useEffect } from 'react'
import WalletPage from './pages/WalletPage'
import './App.css'

const NAV_ITEMS = [
  { id: 'wallets', label: '₿ Carteiras' },
  { id: 'api',     label: '⚡ API Status' },
]

function ApiStatus() {
  const [ping, setPing] = useState(null)
  const [info, setInfo] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    Promise.all([
      fetch('/api/ping').then((r) => r.json()),
      fetch('/api/info').then((r) => r.json()),
    ])
      .then(([p, i]) => { setPing(p); setInfo(i) })
      .catch((e) => setError(e.message))
  }, [])

  if (error) return <p className="api-error">⚠ Erro: {error}</p>

  return (
    <div className="api-status" style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      <h2 className="api-status__title" style={{ fontSize: '2rem', letterSpacing: '-0.03em' }}>API Status</h2>
      <div className="api-grid" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <section className="card glass-panel" style={{ padding: '1.5rem', borderRadius: 'var(--radius-lg)' }}>
          <h3 style={{ marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}><span className="method get color-success" style={{ padding: '0.2rem 0.5rem', background: 'rgba(52, 199, 89, 0.1)', borderRadius: '4px', fontSize: '0.8rem' }}>GET</span> /api/ping</h3>
          {ping
            ? <pre className="json text-mono" style={{ color: 'var(--text-tertiary)' }}>{JSON.stringify(ping, null, 2)}</pre>
            : <p className="loading color-warning">Carregando…</p>}
        </section>
        <section className="card glass-panel" style={{ padding: '1.5rem', borderRadius: 'var(--radius-lg)' }}>
          <h3 style={{ marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}><span className="method get color-success" style={{ padding: '0.2rem 0.5rem', background: 'rgba(52, 199, 89, 0.1)', borderRadius: '4px', fontSize: '0.8rem' }}>GET</span> /api/info</h3>
          {info
            ? <pre className="json text-mono" style={{ color: 'var(--text-tertiary)' }}>{JSON.stringify(info, null, 2)}</pre>
            : <p className="loading color-warning">Carregando…</p>}
        </section>
      </div>
      <footer className="api-status__footer text-mono" style={{ textAlign: 'center', color: 'var(--text-tertiary)', marginTop: '2rem' }}>
        Backend: Haskell + Servant · Frontend: Vite + React
      </footer>
    </div>
  )
}

export default function App() {
  const [activeTab, setActiveTab] = useState('wallets')

  return (
    <div className="app">
      <nav className="nav" aria-label="Navegação principal">
        <div className="nav__brand">
          <span className="nav__logo">₿</span>
          <span className="nav__name">HaskellWallet</span>
        </div>
        <div className="nav__tabs" role="tablist">
          {NAV_ITEMS.map((item) => (
            <button
              key={item.id}
              id={`tab-${item.id}`}
              role="tab"
              aria-selected={activeTab === item.id}
              className={`nav__tab ${activeTab === item.id ? 'nav__tab--active' : ''}`}
              onClick={() => setActiveTab(item.id)}
            >
              {item.label}
            </button>
          ))}
        </div>
      </nav>

      <main className="main" role="main">
        {activeTab === 'wallets' && <WalletPage />}
        {activeTab === 'api'     && <ApiStatus />}
      </main>
    </div>
  )
}
