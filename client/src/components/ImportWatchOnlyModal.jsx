import { useState } from 'react'
import { importWatchOnly } from '../services/walletApi'

export default function ImportWatchOnlyModal({ onImported, onClose }) {
  const [label, setLabel] = useState('')
  const [address, setAddress] = useState('')
  const [tags, setTags] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const canSubmit = label.trim() && address.trim().length > 25 && !loading

  async function handleSubmit(e) {
    e.preventDefault()
    if (!canSubmit) return
    setLoading(true); setError(null)
    try {
      const tagList = tags.split(',').map(t => t.trim()).filter(Boolean)
      const data = await importWatchOnly(label.trim(), address.trim(), tagList)
      onImported(data)
    } catch (err) { setError(err.message) }
    finally { setLoading(false) }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content glass-panel" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Importar Watch-Only</h2>
          <button className="btn-close" onClick={onClose}>X</button>
        </div>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>Monitore um endereco sem a chave privada</p>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <input className="input-text" type="text" placeholder="Nome da carteira" value={label} onChange={e => setLabel(e.target.value)} maxLength={60} autoFocus required />
          <input className="input-text" type="text" placeholder="Endereco Bitcoin (1... ou bc1...)" value={address} onChange={e => setAddress(e.target.value)} spellCheck={false} style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: '0.85em' }} required />
          <input className="input-text" type="text" placeholder="Tags (opcional)" value={tags} onChange={e => setTags(e.target.value)} style={{ fontSize: '0.85rem' }} />
          {error && <p className="auth-error">{error}</p>}
          <button type="submit" className="btn-primary" disabled={!canSubmit}>{loading ? 'Importando...' : 'Importar'}</button>
        </form>
      </div>
    </div>
  )
}
