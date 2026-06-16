import { useState, useEffect } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { listContacts, createContact, deleteContact } from '../services/walletApi'

export default function ContactsPage() {
  const { user } = useAuth()
  const [contacts, setContacts] = useState([])
  const [loaded, setLoaded] = useState(false)
  const [name, setName] = useState('')
  const [address, setAddress] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [copiedId, setCopiedId] = useState(null)

  useEffect(() => {
    listContacts()
      .then(data => { setContacts(data); setLoaded(true) })
      .catch(e => { setError(e.message); setLoaded(true) })
  }, [])

  async function handleAdd(e) {
    e.preventDefault()
    if (!name.trim() || !address.trim()) return
    setLoading(true)
    setError(null)
    try {
      const c = await createContact(name.trim(), address.trim())
      setContacts(prev => [c, ...prev])
      setName('')
      setAddress('')
    } catch (e) { setError(e.message) }
    finally { setLoading(false) }
  }

  async function handleDelete(id) {
    try {
      await deleteContact(id)
      setContacts(prev => prev.filter(c => c.id !== id))
    } catch (e) { setError(e.message) }
  }

  function handleCopy(id, addr) {
    navigator.clipboard.writeText(addr)
    setCopiedId(id)
    setTimeout(() => setCopiedId(null), 2000)
  }

  function truncAddr(a) {
    if (!a || a.length < 20) return a
    return `${a.slice(0, 12)}...${a.slice(-8)}`
  }

  if (!loaded) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
        <h2 style={{ fontSize: '2rem', letterSpacing: '-0.03em' }}>Contatos</h2>
        <div className="glass-panel" style={{ padding: '2rem', borderRadius: 'var(--radius-lg)', textAlign: 'center', color: 'var(--text-tertiary)' }}>
          Carregando contatos…
        </div>
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      <h2 style={{ fontSize: '2rem', letterSpacing: '-0.03em' }}>Contatos</h2>

      <form onSubmit={handleAdd} className="glass-panel" style={{ padding: '1.5rem', borderRadius: 'var(--radius-lg)', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <input className="input-text" placeholder="Nome" value={name} onChange={e => setName(e.target.value)} required />
        <input className="input-text" placeholder="Endereço Bitcoin" value={address} onChange={e => setAddress(e.target.value)} required style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: '0.85em' }} />
        <button type="submit" className="btn-primary" disabled={loading}>{loading ? '…' : '+ Adicionar Contato'}</button>
      </form>

      {error && <p className="color-error">{error}</p>}

      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
        {contacts.length === 0 ? (
          <p style={{ color: 'var(--text-tertiary)', textAlign: 'center' }}>Nenhum contato salvo</p>
        ) : contacts.map(c => (
          <div key={c.id} className="glass-panel" style={{ padding: '1rem 1.5rem', borderRadius: 'var(--radius-md)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ fontWeight: 600 }}>{c.name}</div>
              <div className="text-mono" style={{ color: 'var(--text-secondary)' }}>{truncAddr(c.address)}</div>
            </div>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <button className="btn-outline" style={{ padding: '0.3rem 0.6rem', fontSize: '0.75rem', color: copiedId === c.id ? 'var(--success)' : undefined }} onClick={() => handleCopy(c.id, c.address)}>
                {copiedId === c.id ? '✓' : 'Copiar'}
              </button>
              <button className="btn-outline" style={{ padding: '0.3rem 0.6rem', fontSize: '0.75rem', color: 'var(--error)', borderColor: 'rgba(255,59,48,0.3)' }} onClick={() => handleDelete(c.id)}>✕</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
