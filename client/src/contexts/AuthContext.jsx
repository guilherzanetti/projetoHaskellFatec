import { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { login as apiLogin, register as apiRegister } from '../services/walletApi'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [token, setToken] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const saved = localStorage.getItem('auth')
    if (saved) {
      try {
        const { token: t, user: u } = JSON.parse(saved)
        setToken(t)
        setUser(u)
      } catch {}
    }
    setLoading(false)
  }, [])

  const login = useCallback(async (email, password, otpCode) => {
    const data = await apiLogin(email, password, otpCode)
    setToken(data.token)
    setUser(data.user)
    localStorage.setItem('auth', JSON.stringify({ token: data.token, user: data.user }))
    return data
  }, [])

  const register = useCallback(async (email, username, password) => {
    const data = await apiRegister(email, username, password)
    setToken(data.token)
    setUser(data.user)
    localStorage.setItem('auth', JSON.stringify({ token: data.token, user: data.user }))
    return data
  }, [])

  const logout = useCallback(() => {
    setToken(null)
    setUser(null)
    localStorage.removeItem('auth')
  }, [])

  const updateUser = useCallback((updatedUser) => {
    setUser(updatedUser)
    const saved = localStorage.getItem('auth')
    if (saved) {
      try {
        const { token } = JSON.parse(saved)
        localStorage.setItem('auth', JSON.stringify({ token, user: updatedUser }))
      } catch {}
    }
  }, [])

  return (
    <AuthContext.Provider value={{ user, token, login, register, logout, loading, updateUser }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be inside AuthProvider')
  return ctx
}
