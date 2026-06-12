import { useState } from 'react'
import { importWallet } from '../services/walletApi'

export default function ImportWalletModal({ onImported, onClose }) {
  const [label, setLabel]       = useState('')
  const [mnemonic, setMnemonic] = useState('')
  const [loading, setLoading]   = useState(false)
  const [error, setError]       = useState(null)

  const words = mnemonic.trim().split(/\s+/).filter(Boolean)
  const wordCount = words.length
  const isValidWordCount = wordCount === 12 || wordCount === 24
  const canSubmit = label.trim() && isValidWordCount && !loading

  async function handleSubmit(e) {
    e.preventDefault()
    if (!canSubmit) return
    setLoading(true)
    setError(null)
    try {
      const data = await importWallet(label.trim(), mnemonic.trim())
      onImported(data)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-content glass-panel" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem', position: 'relative' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <h2 style={{ fontSize: '1.5rem' }}>Importar Carteira</h2>
            <p style={{ color: 'var(--text-secondary)' }}>Restaure uma carteira existente</p>
          </div>
          <button type="button" className="btn-close" onClick={onClose} aria-label="Fechar" style={{ position: 'absolute', top: '1.5rem', right: '1.5rem' }}>✕</button>
        </div>

        <div style={{ background: 'rgba(255, 204, 0, 0.1)', padding: '1rem', borderRadius: 'var(--radius-sm)', border: '1px solid rgba(255, 204, 0, 0.2)' }}>
          <p style={{ color: 'var(--warning)', fontSize: '0.9rem' }}>
            ⚠️ Digite sua seed phrase apenas em dispositivos <strong>confiáveis e seguros</strong>.
          </p>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            <label htmlFor="import-label" style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
              Nome da carteira
            </label>
            <input
              id="import-label"
              className="input-text"
              type="text"
              placeholder="Ex: Carteira Principal"
              value={label}
              onChange={(e) => setLabel(e.target.value)}
              maxLength={60}
              autoFocus
              required
            />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            <label htmlFor="import-mnemonic" style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
              <span>Seed Phrase</span>
              <span style={{ color: isValidWordCount ? 'var(--success)' : wordCount > 0 ? 'var(--error)' : 'inherit' }}>
                {wordCount > 0 ? `${wordCount} palavras${isValidWordCount ? ' ✓' : ' — precisa ser 12 ou 24'}` : '12 ou 24 palavras'}
              </span>
            </label>
            <textarea
              id="import-mnemonic"
              className="input-text"
              placeholder="Digite ou cole suas 12 ou 24 palavras..."
              value={mnemonic}
              onChange={(e) => setMnemonic(e.target.value)}
              rows={4}
              spellCheck={false}
              autoComplete="off"
              required
              style={{ resize: 'none', lineHeight: '1.5' }}
            />
          </div>

          {error && <p className="color-error" style={{ fontSize: '0.85rem' }}>⚠ {error}</p>}

          <div style={{ display: 'flex', gap: '1rem', marginTop: '0.5rem' }}>
            <button
              id="import-submit-btn"
              type="submit"
              className="btn-primary"
              disabled={!canSubmit}
              style={{ flex: 1, padding: '0.75rem' }}
            >
              {loading ? '⟳ Importando...' : 'Importar Carteira'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
