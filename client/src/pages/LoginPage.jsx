import { useState } from 'react'
import { useAuth } from '../contexts/AuthContext'

export default function LoginPage({ onSwitch }) {
  const { login } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [otpCode, setOtpCode] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  async function handleSubmit(e) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      await login(email, password, otpCode || undefined)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-card glass-panel">
        <div className="auth-card__header">
          <span className="nav__logo" style={{ fontSize: '2rem' }}>₿</span>
          <h1 className="text-hero" style={{ fontSize: '2rem' }}>Entrar</h1>
        </div>

        <form onSubmit={handleSubmit} className="auth-form">
          <input
            className="input-text"
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoFocus
            required
          />
          <input
            className="input-text"
            type="password"
            placeholder="Senha"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          <input
            className="input-text"
            type="text"
            placeholder="Codigo 2FA (opcional)"
            value={otpCode}
            onChange={(e) => setOtpCode(e.target.value)}
            maxLength={6}
          />
          {error && <p className="auth-error">{error}</p>}
          <button type="submit" className="btn-primary" style={{ width: '100%' }} disabled={loading}>
            {loading ? 'Entrando...' : 'Entrar'}
          </button>
        </form>

        <p className="auth-switch">
          Nao tem conta? <button className="auth-link" onClick={onSwitch}>Criar conta</button>
        </p>
      </div>
    </div>
  )
}
