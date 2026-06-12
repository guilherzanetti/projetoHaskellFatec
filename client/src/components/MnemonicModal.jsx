import { useState, useEffect, useCallback } from 'react'

export default function MnemonicModal({ mnemonic, walletLabel, onClose }) {
  const [confirmed, setConfirmed] = useState(false)
  const [copied, setCopied] = useState(false)
  const [canClose, setCanClose] = useState(false)

  const words = mnemonic ? mnemonic.trim().split(' ') : []

  useEffect(() => {
    const t = setTimeout(() => setCanClose(true), 5000)
    return () => clearTimeout(t)
  }, [])

  const handleCopy = useCallback(() => {
    navigator.clipboard.writeText(mnemonic)
    setCopied(true)
    setTimeout(() => setCopied(false), 2500)
  }, [mnemonic])

  const handleClose = useCallback(() => {
    if (!confirmed) return
    onClose()
  }, [confirmed, onClose])

  useEffect(() => {
    const handler = (e) => {
      if (e.key === 'Escape' && confirmed) handleClose()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [confirmed, handleClose])

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-content glass-panel" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem', position: 'relative' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <h2 style={{ fontSize: '1.5rem' }}>Guarde sua Seed Phrase</h2>
            <p style={{ color: 'var(--text-secondary)' }}>Carteira: <strong>{walletLabel}</strong></p>
          </div>
          {confirmed && canClose && (
            <button className="btn-close" onClick={handleClose} aria-label="Fechar" style={{ position: 'absolute', top: '1.5rem', right: '1.5rem' }}>✕</button>
          )}
        </div>

        <div style={{ background: 'rgba(255, 59, 48, 0.1)', padding: '1rem', borderRadius: 'var(--radius-sm)', border: '1px solid rgba(255, 59, 48, 0.2)' }}>
          <p style={{ color: 'var(--error)', fontSize: '0.9rem' }}>
            ⚠️ Esta é sua <strong>única chance</strong> de ver estas palavras.
            Quem tiver acesso a elas controla seus fundos. Guarde offline.
          </p>
        </div>

        <div className="mnemonic-grid">
          {words.map((word, i) => (
            <div key={i} className="mnemonic-word">
              <span>{i + 1}</span> {word}
            </div>
          ))}
        </div>

        <button
          className="btn-outline"
          onClick={handleCopy}
          style={{ width: '100%', borderColor: copied ? 'var(--success)' : undefined, color: copied ? 'var(--success)' : undefined }}
        >
          {copied ? '✓ Copiado' : '📋 Copiar palavras'}
        </button>

        <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'flex-start', cursor: 'pointer', fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
          <input
            type="checkbox"
            checked={confirmed}
            onChange={(e) => setConfirmed(e.target.checked)}
            style={{ marginTop: '0.2rem' }}
          />
          <span>
            Confirmo que anotei as palavras em local seguro e entendo que
            não há como recuperá-las caso as perca.
          </span>
        </label>

        <button
          className="btn-primary"
          onClick={handleClose}
          disabled={!confirmed || !canClose}
          style={{ width: '100%', marginTop: '1rem' }}
        >
          {!canClose
            ? 'Leia com atenção...'
            : !confirmed
            ? 'Confirme acima'
            : '✓ Fechar'}
        </button>
      </div>
    </div>
  )
}
