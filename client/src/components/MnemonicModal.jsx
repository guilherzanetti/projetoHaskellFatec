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
    const handler = e => { if (e.key === 'Escape' && confirmed) handleClose() }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [confirmed, handleClose])

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-content glass-panel" style={{ maxWidth: '520px' }}>
        <div className="modal-header">
          <div>
            <h2>Seed Phrase</h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>{walletLabel}</p>
          </div>
          {confirmed && canClose && <button className="btn-close" onClick={handleClose}>X</button>}
        </div>

        <div className="modal-warning modal-warning--error">
          <strong>Atencao:</strong> Esta e sua unica chance de ver estas palavras. Quem tiver acesso a elas controla seus fundos.
        </div>

        <div className="mnemonic-grid">
          {words.map((word, i) => (
            <div key={i} className="mnemonic-word">
              <span>{i + 1}</span> {word}
            </div>
          ))}
        </div>

        <button className="btn-outline" onClick={handleCopy} style={{ width: '100%', borderColor: copied ? 'var(--success)' : undefined, color: copied ? 'var(--success)' : undefined }}>
          {copied ? 'Copiado' : 'Copiar palavras'}
        </button>

        <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'flex-start', cursor: 'pointer', fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
          <input type="checkbox" checked={confirmed} onChange={e => setConfirmed(e.target.checked)} style={{ marginTop: '0.2rem' }} />
          <span>Anotei as palavras em local seguro e entendo que nao ha como recupera-las.</span>
        </label>

        <button className="btn-primary" onClick={handleClose} disabled={!confirmed || !canClose} style={{ width: '100%' }}>
          {!canClose ? 'Aguarde...' : !confirmed ? 'Confirme acima' : 'Fechar'}
        </button>
      </div>
    </div>
  )
}
