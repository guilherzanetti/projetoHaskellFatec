import { useState, useEffect, useCallback } from 'react'
import { getBalance } from '../services/walletApi'

function truncate(addr) {
  if (!addr || addr.length < 20) return addr
  return `${addr.slice(0, 10)}...${addr.slice(-8)}`
}

export default function WalletCard({ wallet, btcPrice, onOpen }) {
  const [balance, setBalance] = useState(null)
  const [error, setError] = useState(null)
  const [copied, setCopied] = useState(false)

  const refresh = useCallback(async () => {
    try {
      const data = await getBalance(wallet.id)
      setBalance(data)
      setError(null)
    } catch (e) {
      setError(e.message)
    }
  }, [wallet.id])

  useEffect(() => {
    refresh()
    const interval = setInterval(refresh, 5000)
    return () => clearInterval(interval)
  }, [refresh])

  const handleCopy = useCallback((e) => {
    e.stopPropagation()
    navigator.clipboard.writeText(wallet.address)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }, [wallet.address])

  const brlValue = balance && btcPrice ? balance.totalBtc * btcPrice : null

  return (
    <div className="wallet-card glass-panel" onClick={onOpen}>
      <div className="wallet-card__header">
        <h3 className="wallet-card__title">{wallet.label}</h3>
        <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
          {wallet.watchOnly && (
            <span className="wallet-card__badge" style={{ background: 'rgba(255, 204, 0, 0.15)', color: 'var(--warning)' }}>WATCH</span>
          )}
          <span className="wallet-card__badge">BTC</span>
        </div>
      </div>

      {wallet.tags && wallet.tags.length > 0 && (
        <div style={{ display: 'flex', gap: '0.35rem', flexWrap: 'wrap' }}>
          {wallet.tags.map(tag => (
            <span key={tag} style={{ fontSize: '0.7rem', padding: '0.15rem 0.5rem', background: 'var(--accent-dim)', color: 'var(--accent)', borderRadius: 'var(--radius-sm)', fontWeight: 500 }}>{tag}</span>
          ))}
        </div>
      )}

      <div className="wallet-card__balance">
        {balance ? (
          <>
            {balance.totalBtc.toFixed(8)}
            <span className="wallet-card__currency">BTC</span>
          </>
        ) : (
          <span style={{ fontSize: '1rem', color: 'var(--text-tertiary)' }}>Sincronizando...</span>
        )}
      </div>

      {balance && brlValue !== null && brlValue > 0 && (
        <div style={{ fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
          R$ {brlValue.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </div>
      )}

      {balance && balance.offChainBtc > 0 && (
        <div style={{ color: 'var(--accent)', fontSize: '0.8rem' }}>
          + {balance.offChainBtc.toFixed(8)} P2P
        </div>
      )}

      {error && <p className="color-error" style={{ fontSize: '0.8rem' }}>{error}</p>}

      <div className="wallet-card__footer">
        <div className="text-mono" style={{ cursor: 'pointer' }} onClick={handleCopy}>
          {copied ? <span className="color-success">Copiado</span> : truncate(wallet.address)}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--success)', display: 'inline-block', animation: 'pulse 2s infinite' }} />
          <span style={{ fontSize: '0.7rem', color: 'var(--text-tertiary)' }}>Live</span>
        </div>
      </div>
    </div>
  )
}
