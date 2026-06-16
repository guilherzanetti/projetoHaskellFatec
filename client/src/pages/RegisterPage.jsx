import { useState } from 'react'
import { useAuth } from '../contexts/AuthContext'

export default function RegisterPage({ onSwitch }) {
  const { register } = useAuth()
  const [email, setEmail] = useState('')
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const canSubmit = email && username.length >= 3 && password.length >= 6 && password === confirm && !loading

  async function handleSubmit(e) {
    e.preventDefault()
    if (password !== confirm) {
      setError('Senhas nao conferem')
      return
    }
    setLoading(true)
    setError(null)
    try {
      await register(email, username, password)
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
          <h1 className="text-hero" style={{ fontSize: '2rem' }}>Criar Conta</h1>
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
            type="text"
            placeholder="Username (minimo 3 caracteres)"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            minLength={3}
            maxLength={30}
            required
          />
          <input
            className="input-text"
            type="password"
            placeholder="Senha (minimo 6 caracteres)"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            minLength={6}
            required
          />
          <input
            className="input-text"
            type="password"
            placeholder="Confirmar senha"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            required
          />
          {confirm && password !== confirm && (
            <p className="auth-error">Senhas nao conferem</p>
          )}
          {error && <p className="auth-error">{error}</p>}
          <button type="submit" className="btn-primary" style={{ width: '100%' }} disabled={!canSubmit}>
            {loading ? 'Criando...' : 'Criar Conta'}
          </button>
        </form>

        <p className="auth-switch">
          Ja tem conta? <button className="auth-link" onClick={onSwitch}>Entrar</button>
        </p>
      </div>
    </div>
  )
}
