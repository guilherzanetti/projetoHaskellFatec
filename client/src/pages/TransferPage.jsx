import { useState, useEffect } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { sendTransfer, listTransfers } from '../services/walletApi'

export default function TransferPage() {
  const { user } = useAuth()
  const [email, setEmail] = useState('')
  const [amountSats, setAmountSats] = useState('')
  const [password, setPassword] = useState('')
  const [otpCode, setOtpCode] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const [transfers, setTransfers] = useState([])
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    listTransfers()
      .then(data => { setTransfers(data); setLoaded(true) })
      .catch(() => setLoaded(true))
  }, [])

  const satsToBtc = (sats) => (sats / 1e8).toFixed(8)

  async function handleSubmit(e) {
    e.preventDefault()
    if (!email.trim() || !amountSats || !password) return
    setLoading(true)
    setError(null)
    setSuccess(null)
    try {
      const res = await sendTransfer(email.trim(), parseInt(amountSats), password, otpCode || undefined)
      setSuccess(`Transferencia de ${satsToBtc(res.amountSats)} BTC para ${res.toUser} realizada com sucesso!`)
      setEmail('')
      setAmountSats('')
      setPassword('')
      setOtpCode('')
      const updated = await listTransfers()
      setTransfers(updated)
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      <h2 style={{ fontSize: '2rem', letterSpacing: '-0.03em' }}>Transferencia P2P</h2>
      <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
        Envie Bitcoin instantaneamente e sem taxas para outros usuarios da plataforma.
      </p>

      <form onSubmit={handleSubmit} className="glass-panel" style={{ padding: '1.5rem', borderRadius: 'var(--radius-lg)', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
          <label className="auth-label">Email do destinatario</label>
          <input className="input-text" type="email" placeholder="destinatario@email.com" value={email} onChange={e => setEmail(e.target.value)} required autoFocus />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
          <label className="auth-label">Valor (satoshis)</label>
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <input className="input-text" type="number" min="1" step="1" placeholder="100000" value={amountSats} onChange={e => setAmountSats(e.target.value)} required style={{ flex: 1 }} />
            <span style={{ color: 'var(--text-tertiary)', fontSize: '0.85rem', whiteSpace: 'nowrap' }}>
              {amountSats ? `= ${satsToBtc(parseInt(amountSats) || 0)} BTC` : 'sats'}
            </span>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
          <label className="auth-label">Sua senha</label>
          <input className="input-text" type="password" placeholder="Senha da conta" value={password} onChange={e => setPassword(e.target.value)} required />
        </div>

        {user?.totpEnabled && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            <label className="auth-label">Codigo 2FA</label>
            <input className="input-text" type="text" placeholder="000000" value={otpCode} onChange={e => setOtpCode(e.target.value)} maxLength={6} />
          </div>
        )}

        {error && <p className="color-error" style={{ fontSize: '0.85rem' }}>{error}</p>}
        {success && <p className="color-success" style={{ fontSize: '0.85rem' }}>{success}</p>}

        <button type="submit" className="btn-primary" disabled={loading} style={{ width: '100%' }}>
          {loading ? 'Enviando...' : 'Enviar Transferencia'}
        </button>
      </form>

      <div>
        <h3 style={{ marginBottom: '1rem' }}>Historico de Transferencias</h3>
        {!loaded ? (
          <p style={{ color: 'var(--text-tertiary)' }}>Carregando...</p>
        ) : transfers.length === 0 ? (
          <p style={{ color: 'var(--text-tertiary)' }}>Nenhuma transferencia realizada</p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {transfers.map(t => {
              const isSender = t.fromUser === user?.email
              return (
                <div key={t.id} className="glass-panel" style={{
                  padding: '1rem 1.5rem',
                  borderRadius: 'var(--radius-md)',
                  borderLeft: `3px solid ${isSender ? 'var(--error)' : 'var(--success)'}`,
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center'
                }}>
                  <div>
                    <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)' }}>
                      {isSender ? 'Enviado para' : 'Recebido de'}
                    </div>
                    <div style={{ fontWeight: 600 }}>
                      {isSender ? t.toUser : t.fromUser}
                    </div>
                    {t.createdAt && (
                      <div style={{ fontSize: '0.7rem', color: 'var(--text-tertiary)', marginTop: '0.25rem' }}>
                        {new Date(t.createdAt).toLocaleString('pt-BR')}
                      </div>
                    )}
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: '1.1rem', fontWeight: 600, color: isSender ? 'var(--error)' : 'var(--success)' }}>
                      {isSender ? '-' : '+'}{satsToBtc(t.amountSats)} BTC
                    </div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)' }}>
                      {t.amountSats.toLocaleString()} sats
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
