const BASE = '/api'

function authHeaders() {
  const saved = localStorage.getItem('auth')
  if (!saved) return {}
  try {
    const { token } = JSON.parse(saved)
    return { 'Authorization': `Bearer ${token}` }
  } catch { return {} }
}

function userId() {
  const saved = localStorage.getItem('auth')
  if (!saved) return ''
  try {
    const { user } = JSON.parse(saved)
    return user.id
  } catch { return '' }
}

export async function register(email, username, password) {
  return apiPost(`${BASE}/auth/register`, { email, username, password })
}

export async function login(email, password, otpCode) {
  return apiPost(`${BASE}/auth/login`, { email, password, otpCode })
}

export async function createWallet(label, tags = []) {
  return apiPost(`${BASE}/wallets`, { label, tags })
}

export async function importWallet(label, mnemonic, password, tags = []) {
  return apiPost(`${BASE}/wallets/import`, { label, mnemonic, password, tags })
}

export async function importWatchOnly(label, address, tags = []) {
  return apiPost(`${BASE}/wallets/import-watch`, { label, address, tags })
}

export async function listWallets() {
  return apiGet(`${BASE}/wallets`)
}

export async function deleteWallet(id) {
  const res = await fetch(`${BASE}/wallets/${id}`, {
    method: 'DELETE',
    headers: { ...authHeaders() },
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }))
    throw new Error(err.error || `HTTP ${res.status}`)
  }
}

export async function getBalance(id) {
  return apiGet(`${BASE}/wallets/${id}/balance`)
}

export async function getFeeEstimate() {
  return apiGet(`${BASE}/wallets/fee-estimate`)
}

export async function getTransactions(id) {
  return apiGet(`${BASE}/wallets/${id}/transactions`)
}

export async function sendBitcoin(id, { recipient, amountBtc, feeRateSatVbyte, password, otpCode }) {
  return apiPost(`${BASE}/wallets/${id}/send`, { recipient, amountBtc, feeRateSatVbyte, password, otpCode })
}

export async function updateWalletTags(id, tags) {
  const res = await fetch(`${BASE}/wallets/${id}/tags`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify({ tags }),
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }))
    throw new Error(err.error || `HTTP ${res.status}`)
  }
  return res.json()
}

export async function getConsolidated() {
  return apiGet(`${BASE}/wallets/consolidated`)
}

export async function getPrice() {
  return apiGet(`${BASE}/wallets/price`)
}

export async function listContacts() {
  return apiGet(`${BASE}/users/${userId()}/contacts`)
}

export async function createContact(name, address) {
  return apiPost(`${BASE}/users/${userId()}/contacts`, { name, address })
}

export async function deleteContact(id) {
  const res = await fetch(`${BASE}/users/${userId()}/contacts/${id}`, {
    method: 'DELETE',
    headers: { ...authHeaders() },
  })
  if (!res.ok) throw new Error('Erro ao excluir contato')
}

export async function createNote(txId, content) {
  return apiPost(`${BASE}/users/${userId()}/notes`, { txId, content })
}

export async function deleteNote(id) {
  const res = await fetch(`${BASE}/users/${userId()}/notes/${id}`, {
    method: 'DELETE',
    headers: { ...authHeaders() },
  })
  if (!res.ok) throw new Error('Erro ao excluir nota')
}

export async function setupTotp() {
  const res = await fetch(`${BASE}/users/${userId()}/totp/setup`, {
    method: 'POST',
    headers: { ...authHeaders() },
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }))
    throw new Error(err.error || `HTTP ${res.status}`)
  }
  return res.json()
}

export async function enableTotp(code) {
  return apiPost(`${BASE}/users/${userId()}/totp/enable`, { code })
}

export async function changePassword(currentPassword, newPassword) {
  return apiPost(`${BASE}/users/${userId()}/password`, { currentPassword, newPassword })
}

export async function changeUsername(username) {
  return apiPost(`${BASE}/users/${userId()}/username`, { username })
}

export async function sendTransfer(recipientEmail, amountSats, password, otpCode) {
  return apiPost(`${BASE}/transfers`, { recipientEmail, amountSats, password, otpCode })
}

export async function listTransfers() {
  return apiGet(`${BASE}/transfers`)
}

async function apiGet(url) {
  const res = await fetch(url, { headers: { ...authHeaders() } })
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }))
    throw new Error(err.error || `HTTP ${res.status}`)
  }
  return res.json()
}

async function apiPost(url, body) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(body),
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }))
    throw new Error(err.error || `HTTP ${res.status}`)
  }
  return res.json()
}
