const BASE = '/api/wallets'

// ── Wallet CRUD ──────────────────────────────────────────────────────────────

export async function createWallet(label) {
  return apiPost(BASE, { label })
}

export async function importWallet(label, mnemonic) {
  return apiPost(`${BASE}/import`, { label, mnemonic })
}

export async function listWallets() {
  return apiGet(BASE)
}

export async function deleteWallet(id) {
  const res = await fetch(`${BASE}/${id}`, { method: 'DELETE' })
  if (!res.ok) throw new Error('Erro ao excluir carteira')
}

// ── Balance & Fees ───────────────────────────────────────────────────────────

export async function getBalance(id) {
  return apiGet(`${BASE}/${id}/balance`)
}

export async function getFeeEstimate() {
  return apiGet(`${BASE}/fee-estimate`)
}

// ── Transactions ─────────────────────────────────────────────────────────────

export async function getTransactions(id) {
  return apiGet(`${BASE}/${id}/transactions`)
}

// ── Send ─────────────────────────────────────────────────────────────────────

export async function sendBitcoin(id, { recipient, amountBtc, feeRateSatVbyte }) {
  return apiPost(`${BASE}/${id}/send`, { recipient, amountBtc, feeRateSatVbyte })
}

// ── Internal helpers ─────────────────────────────────────────────────────────

async function apiGet(url) {
  const res = await fetch(url)
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }))
    throw new Error(err.error || `HTTP ${res.status}`)
  }
  return res.json()
}

async function apiPost(url, body) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }))
    throw new Error(err.error || `HTTP ${res.status}`)
  }
  return res.json()
}
