import { useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { changePassword, changeUsername, setupTotp, enableTotp } from '../services/walletApi'

export default function SettingsPage() {
  const { user, logout, updateUser } = useAuth()
  const [section, setSection] = useState(null)

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      <h2 style={{ fontSize: '2rem', letterSpacing: '-0.03em' }}>Configuracoes</h2>

      <div className="glass-panel" style={{ padding: '1.5rem', borderRadius: 'var(--radius-lg)' }}>
        <h3 style={{ marginBottom: '1rem', fontSize: '1.1rem' }}>Conta</h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Email</div>
              <div style={{ fontWeight: 500 }}>{user?.email}</div>
            </div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Username</div>
              <div style={{ fontWeight: 500 }}>{user?.username || 'Nao definido'}</div>
            </div>
            <button className="btn-outline" style={{ padding: '0.4rem 1rem', fontSize: '0.8rem' }} onClick={() => setSection('username')}>
              {user?.username ? 'Alterar' : 'Definir'}
            </button>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Senha</div>
              <div style={{ fontWeight: 500 }}>••••••••</div>
            </div>
            <button className="btn-outline" style={{ padding: '0.4rem 1rem', fontSize: '0.8rem' }} onClick={() => setSection('password')}>Alterar</button>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Autenticacao 2FA</div>
              <div style={{ fontWeight: 500, color: user?.totpEnabled ? 'var(--success)' : 'var(--text-tertiary)' }}>
                {user?.totpEnabled ? 'Ativado' : 'Desativado'}
              </div>
            </div>
            <button className="btn-outline" style={{ padding: '0.4rem 1rem', fontSize: '0.8rem' }} onClick={() => setSection('2fa')}>
              {user?.totpEnabled ? 'Gerenciar' : 'Ativar'}
            </button>
          </div>
        </div>
        <button className="btn-outline" style={{ marginTop: '1.5rem', width: '100%', color: 'var(--error)', borderColor: 'rgba(255,59,48,0.3)' }} onClick={logout}>
          Sair da conta
        </button>
      </div>

      {section === 'username' && <UsernameModal onClose={() => setSection(null)} onUpdate={updateUser} />}
      {section === 'password' && <PasswordModal onClose={() => setSection(null)} />}
      {section === '2fa' && <TotpModal onClose={() => setSection(null)} onUpdate={updateUser} />}
    </div>
  )
}

function UsernameModal({ onClose, onUpdate }) {
  const { user } = useAuth()
  const [username, setUsername] = useState(user?.username || '')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  async function handleSubmit(e) {
    e.preventDefault()
    if (username.length < 3) return
    setLoading(true)
    setError(null)
    try {
      const updated = await changeUsername(username)
      onUpdate(updated)
      onClose()
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content glass-panel" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Username</h2>
          <button className="btn-close" onClick={onClose}>X</button>
        </div>
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <input
            className="input-text"
            type="text"
            placeholder="Seu username"
            value={username}
            onChange={e => setUsername(e.target.value)}
            minLength={3}
            maxLength={30}
            autoFocus
            required
          />
          {error && <p className="auth-error">{error}</p>}
          <button type="submit" className="btn-primary" disabled={loading || username.length < 3}>
            {loading ? 'Salvando...' : 'Salvar'}
          </button>
        </form>
      </div>
    </div>
  )
}

function PasswordModal({ onClose }) {
  const [current, setCurrent] = useState('')
  const [newPass, setNewPass] = useState('')
  const [confirmPass, setConfirmPass] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(false)

  async function handleSubmit(e) {
    e.preventDefault()
    if (newPass !== confirmPass) { setError('Senhas nao conferem'); return }
    if (newPass.length < 6) { setError('Nova senha deve ter minimo 6 caracteres'); return }
    setLoading(true)
    setError(null)
    try {
      await changePassword(current, newPass)
      setSuccess(true)
      setTimeout(onClose, 1500)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content glass-panel" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Alterar Senha</h2>
          <button className="btn-close" onClick={onClose}>X</button>
        </div>
        {success ? (
          <p className="color-success" style={{ textAlign: 'center', padding: '1rem 0' }}>Senha alterada com sucesso!</p>
        ) : (
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <input className="input-text" type="password" placeholder="Senha atual" value={current} onChange={e => setCurrent(e.target.value)} autoFocus required />
            <input className="input-text" type="password" placeholder="Nova senha (min. 6 caracteres)" value={newPass} onChange={e => setNewPass(e.target.value)} minLength={6} required />
            <input className="input-text" type="password" placeholder="Confirmar nova senha" value={confirmPass} onChange={e => setConfirmPass(e.target.value)} required />
            {confirmPass && newPass !== confirmPass && <p className="auth-error">Senhas nao conferem</p>}
            {error && <p className="auth-error">{error}</p>}
            <button type="submit" className="btn-primary" disabled={loading || !current || newPass.length < 6 || newPass !== confirmPass}>
              {loading ? 'Alterando...' : 'Alterar Senha'}
            </button>
          </form>
        )}
      </div>
    </div>
  )
}

function TotpModal({ onClose, onUpdate }) {
  const { user } = useAuth()
  const [totpSecret, setTotpSecret] = useState(null)
  const [code, setCode] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)

  async function handleSetup() {
    setLoading(true)
    setError(null)
    try {
      const data = await setupTotp()
      setTotpSecret(data.secret)
    } catch (e) { setError(e.message) }
    finally { setLoading(false) }
  }

  async function handleEnable(e) {
    e.preventDefault()
    if (code.length !== 6) return
    setLoading(true)
    setError(null)
    try {
      const updated = await enableTotp(code)
      onUpdate(updated)
      setSuccess('2FA ativado com sucesso!')
      setTimeout(onClose, 1500)
    } catch (e) { setError(e.message) }
    finally { setLoading(false) }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content glass-panel" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Autenticacao 2FA</h2>
          <button className="btn-close" onClick={onClose}>X</button>
        </div>

        {user?.totpEnabled ? (
          <p className="color-success" style={{ textAlign: 'center', padding: '1rem 0' }}>2FA esta ativado na sua conta.</p>
        ) : !totpSecret ? (
          <button className="btn-primary" style={{ width: '100%' }} onClick={handleSetup} disabled={loading}>
            {loading ? 'Gerando...' : 'Configurar 2FA'}
          </button>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
              Escaneie o QR code no seu app autenticador ou insira a chave manualmente:
            </p>
            <div className="text-mono" style={{ background: 'rgba(0,0,0,0.5)', padding: '0.75rem', borderRadius: 'var(--radius-sm)', wordBreak: 'break-all', userSelect: 'all', fontSize: '0.8rem' }}>
              {totpSecret}
            </div>
            <form onSubmit={handleEnable} style={{ display: 'flex', gap: '0.5rem' }}>
              <input className="input-text" type="text" placeholder="Codigo de 6 digitos" value={code} onChange={e => setCode(e.target.value)} maxLength={6} autoFocus required style={{ flex: 1 }} />
              <button type="submit" className="btn-primary" disabled={loading || code.length !== 6}>
                {loading ? '...' : 'Ativar'}
              </button>
            </form>
          </div>
        )}
        {error && <p className="auth-error" style={{ marginTop: '0.5rem' }}>{error}</p>}
        {success && <p className="color-success" style={{ marginTop: '0.5rem' }}>{success}</p>}
      </div>
    </div>
  )
}
