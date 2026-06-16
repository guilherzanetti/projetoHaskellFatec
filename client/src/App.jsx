import { useState, useEffect } from 'react'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import LoginPage from './pages/LoginPage'
import RegisterPage from './pages/RegisterPage'
import WalletPage from './pages/WalletPage'
import ContactsPage from './pages/ContactsPage'
import SettingsPage from './pages/SettingsPage'
import TransferPage from './pages/TransferPage'
import './App.css'

const NAV_ITEMS = [
  { id: 'wallets',   label: 'Carteiras' },
  { id: 'transfer',  label: 'P2P' },
  { id: 'contacts',  label: 'Contatos' },
  { id: 'settings',  label: 'Config' },
]

function AppContent() {
  const { user, logout, loading } = useAuth()
  const [activeTab, setActiveTab] = useState('wallets')
  const [authMode, setAuthMode] = useState('login')

  if (loading) return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '100vh' }}>
      <p style={{ color: 'var(--text-secondary)' }}>Carregando...</p>
    </div>
  )

  if (!user) {
    return authMode === 'login'
      ? <LoginPage onSwitch={() => setAuthMode('register')} />
      : <RegisterPage onSwitch={() => setAuthMode('login')} />
  }

  return (
    <div className="app">
      <nav className="nav" aria-label="Navegacao principal">
        <div className="nav__brand">
          <span className="nav__logo">₿</span>
          <span className="nav__name">HaskellWallet</span>
        </div>
        <div className="nav__tabs" role="tablist">
          {NAV_ITEMS.map(item => (
            <button
              key={item.id}
              role="tab"
              aria-selected={activeTab === item.id}
              className={`nav__tab ${activeTab === item.id ? 'nav__tab--active' : ''}`}
              onClick={() => setActiveTab(item.id)}
            >
              {item.label}
            </button>
          ))}
        </div>
        <div className="nav__user">
          <span className="nav__username">{user.username || user.email.split('@')[0]}</span>
          <button className="nav__logout" onClick={logout} title="Sair">Sair</button>
        </div>
      </nav>

      <main className="main" role="main">
        {activeTab === 'wallets'   && <WalletPage />}
        {activeTab === 'transfer'  && <TransferPage />}
        {activeTab === 'contacts'  && <ContactsPage />}
        {activeTab === 'settings'  && <SettingsPage />}
      </main>
    </div>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  )
}
