import { useState } from 'react'
import { importWallet } from '../services/walletApi'

export default function ImportWalletModal({ onImported, onClose }) {
  const [label, setLabel] = useState('')
  const [mnemonic, setMnemonic] = useState('')
  const [password, setPassword] = useState('')
  const [tags, setTags] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const words = mnemonic.trim().split(/\s+/).filter(Boolean)
  const wordCount = words.length
  const isValidWordCount = wordCount === 12 || wordCount === 24
  const canSubmit = label.trim() && isValidWordCount && password.length >= 6 && !loading

  async function handleSubmit(e) {
    e.preventDefault()
    if (!canSubmit) return
    setLoading(true); setError(null)
    try {
      const tagList = tags.split(',').map(t => t.trim()).filter(Boolean)
      const data = await importWallet(label.trim(), mnemonic.trim(), password, tagList)
      onImported(data)
    } catch (err) { setError(err.message) }
    finally { setLoading(false) }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content glass-panel" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Importar Carteira</h2>
          <button className="btn-close" onClick={onClose}>X</button>
        </div>

        <div className="modal-warning">
          Digite sua seed phrase apenas em dispositivos confiaveis.
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <input className="input-text" type="text" placeholder="Nome da carteira" value={label} onChange={e => setLabel(e.target.value)} maxLength={60} autoFocus required />
          
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
              <label className="auth-label">Seed Phrase</label>
              <span style={{ fontSize: '0.75rem', color: isValidWordCount ? 'var(--success)' : wordCount > 0 ? 'var(--error)' : 'var(--text-tertiary)' }}>
                {wordCount > 0 ? `${wordCount} palavras${isValidWordCount ? ' (ok)' : ''}` : '12 ou 24'}
              </span>
            </div>
            <textarea className="input-text" placeholder="Cole suas 12 ou 24 palavras..." value={mnemonic} onChange={e => setMnemonic(e.target.value)} rows={3} spellCheck={false} autoComplete="off" required style={{ resize: 'none', lineHeight: '1.5' }} />
          </div>

          <input className="input-text" type="password" placeholder="Senha de criptografia (min. 6 caracteres)" value={password} onChange={e => setPassword(e.target.value)} minLength={6} required />
          <span style={{ fontSize: '0.7rem', color: 'var(--text-tertiary)' }}>Necessaria para enviar Bitcoin</span>

          <input className="input-text" type="text" placeholder="Tags (opcional, separadas por virgula)" value={tags} onChange={e => setTags(e.target.value)} style={{ fontSize: '0.85rem' }} />

          {error && <p className="auth-error">{error}</p>}
          <button type="submit" className="btn-primary" disabled={!canSubmit}>{loading ? 'Importando...' : 'Importar'}</button>
        </form>
      </div>
    </div>
  )
}
