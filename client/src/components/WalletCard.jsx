import { useState, useCallback } from 'react'
import { getBalance, deleteWallet } from '../services/walletApi'

function truncate(addr) {
  if (!addr || addr.length < 20) return addr
  return `${addr.slice(0, 10)}...${addr.slice(-8)}`
}

export default function WalletCard({ wallet, onOpen, onDelete }) {
  const [balance, setBalance] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [copied, setCopied] = useState(false)

  const handleRefresh = useCallback(async (e) => {
    e.stopPropagation()
    setLoading(true)
    setError(null)
    try {
      const data = await getBalance(wallet.id)
      setBalance(data)
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [wallet.id])

  const handleCopy = useCallback((e) => {
    e.stopPropagation()
    navigator.clipboard.writeText(wallet.address)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }, [wallet.address])

  return (
    <div className="wallet-card glass-panel" onClick={onOpen}>
      <div className="wallet-card__header">
        <h3 className="wallet-card__title">{wallet.label}</h3>
        <span className="wallet-card__badge">BTC</span>
      </div>

      <div className="wallet-card__balance">
        {balance ? (
          <>
            {balance.confirmedBtc.toFixed(8)}
            <span className="wallet-card__currency">BTC</span>
          </>
        ) : (
          <span style={{ fontSize: '1rem', color: 'var(--text-tertiary)' }}>
            {loading ? 'Sincronizando...' : 'Clique em atualizar'}
          </span>
        )}
      </div>
      {balance?.unconfirmedBtc > 0 && (
        <div style={{ color: 'var(--warning)', fontSize: '0.85rem' }}>
          + {balance.unconfirmedBtc.toFixed(8)} pendente
        </div>
      )}

      {error && <p className="color-error" style={{ fontSize: '0.85rem' }}>{error}</p>}

      <div className="wallet-card__footer">
        <div 
          className="text-mono" 
          style={{ cursor: 'pointer', transition: 'color 0.2s' }}
          onClick={handleCopy}
          title="Copiar endereço"
        >
          {copied ? <span className="color-success">✓ Copiado</span> : truncate(wallet.address)}
        </div>
        
        <button 
          className="btn-outline"
          style={{ padding: '0.4rem 0.8rem', fontSize: '0.75rem', borderRadius: 'var(--radius-sm)' }}
          onClick={handleRefresh}
          disabled={loading}
        >
          {loading ? '⟳' : 'Atualizar'}
        </button>
      </div>
    </div>
  )
}
