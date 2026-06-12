import { useState, useEffect, useCallback, useRef } from 'react'
import QRCode from 'qrcode'
import { getBalance, getTransactions, getFeeEstimate, sendBitcoin } from '../services/walletApi'

// ── Helpers ──────────────────────────────────────────────────────────────────

function fmt8(n) { return n.toFixed(8) }
function fmtDate(ts) {
  if (!ts) return '—'
  return new Date(ts * 1000).toLocaleDateString('pt-BR', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}
function truncAddr(a, n = 10) {
  if (!a || a.length < 20) return a
  return `${a.slice(0, n)}...${a.slice(-8)}`
}

// Compute the net amount of a transaction relative to our address
function txNetAmount(tx, address) {
  const inSum = tx.vin.reduce((s, v) => {
    return s + (v.prevout?.scriptpubkey_address === address ? v.prevout.value : 0)
  }, 0)
  const outSum = tx.vout.reduce((s, v) => {
    return s + (v.scriptpubkey_address === address ? v.value : 0)
  }, 0)
  return outSum - inSum // positive = received, negative = sent
}

// ── Overview Tab ─────────────────────────────────────────────────────────────

function OverviewTab({ wallet }) {
  const [qrSrc, setQrSrc]     = useState('')
  const [balance, setBalance] = useState(null)
  const [loading, setLoading] = useState(false)
  const [copied, setCopied]   = useState(false)
  const [error, setError]     = useState(null)

  useEffect(() => {
    QRCode.toDataURL(wallet.address, {
      width: 200, margin: 2,
      color: { dark: '#f7931a', light: '#141419' },
    }).then(setQrSrc).catch(() => {})
  }, [wallet.address])

  const refresh = useCallback(async () => {
    setLoading(true)
    setError(null)
    try { setBalance(await getBalance(wallet.id)) }
    catch (e) { setError(e.message) }
    finally { setLoading(false) }
  }, [wallet.id])

  useEffect(() => { refresh() }, [refresh])

  const copy = useCallback(() => {
    navigator.clipboard.writeText(wallet.address)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }, [wallet.address])

  return (
    <div className="tab-content overview">
      {/* QR Code */}
      <div className="overview__qr-wrap">
        {qrSrc
          ? <img src={qrSrc} alt="Endereço QR Code" width={200} height={200} className="overview__qr" />
          : <div className="overview__qr-placeholder">QR</div>
        }
        <p className="overview__qr-hint">Mostre para receber Bitcoin</p>
      </div>

      {/* Address */}
      <div className="overview__address-card">
        <span className="overview__address-label">Endereço</span>
        <div className="overview__address-row">
          <span className="mono overview__address">{wallet.address}</span>
          <button
            className={`btn-icon ${copied ? 'btn-icon--ok' : ''}`}
            onClick={copy}
            aria-label="Copiar endereço"
          >
            {copied ? '✓' : '📋'}
          </button>
        </div>
      </div>

      {/* Balance */}
      <div className="overview__balance-card">
        <span className="overview__balance-label">Saldo</span>
        {balance ? (
          <>
            <div className="overview__btc">{fmt8(balance.confirmedBtc)} <span className="overview__unit">BTC</span></div>
            {balance.unconfirmedBtc !== 0 && (
              <div className="overview__pending">
                + {fmt8(Math.abs(balance.unconfirmedBtc))} BTC não confirmado
              </div>
            )}
          </>
        ) : loading ? (
          <div className="overview__loading">Consultando blockchain…</div>
        ) : (
          <div className="overview__loading">—</div>
        )}
        {error && <p className="wallet-card__error">{error}</p>}
        <button
          className={`wallet-card__refresh ${loading ? 'wallet-card__refresh--loading' : ''}`}
          onClick={refresh}
          disabled={loading}
        >
          <span className="wallet-card__refresh-icon">↻</span>
          {loading ? 'Consultando...' : 'Atualizar Saldo'}
        </button>
      </div>
    </div>
  )
}

// ── Send Tab ──────────────────────────────────────────────────────────────────

const FEE_LABELS = {
  fast:   { label: 'Rápida',  sub: '~10 min',   key: 'fast'   },
  normal: { label: 'Normal',  sub: '~1 hora',    key: 'normal' },
  slow:   { label: 'Lenta',   sub: '~24 horas',  key: 'slow'   },
}
const EST_TX_BYTES = 226  // typical P2PKH 1-in 2-out

function SendTab({ wallet }) {
  const [recipient, setRecipient] = useState('')
  const [amountBtc, setAmountBtc] = useState('')
  const [feeSpeed, setFeeSpeed]   = useState('normal')
  const [fees, setFees]           = useState(null)
  const [feeErr, setFeeErr]       = useState(null)
  const [sending, setSending]     = useState(false)
  const [sendErr, setSendErr]     = useState(null)
  const [txHash, setTxHash]       = useState(null)
  const [confirm, setConfirm]     = useState(false)

  useEffect(() => {
    getFeeEstimate()
      .then(setFees)
      .catch((e) => setFeeErr(e.message))
  }, [])

  const feeRateSatVbyte = fees ? Math.ceil(fees[feeSpeed]) : 10
  const feeBtc = feeRateSatVbyte * EST_TX_BYTES / 1e8
  const amount = parseFloat(amountBtc) || 0
  const totalBtc = amount + feeBtc

  const canConfirm = recipient.trim().length > 25 && amount > 0 && !sending

  async function handleSend() {
    setSending(true)
    setSendErr(null)
    try {
      const res = await sendBitcoin(wallet.id, {
        recipient: recipient.trim(),
        amountBtc: amount,
        feeRateSatVbyte,
      })
      setTxHash(res.txHash)
      setConfirm(false)
    } catch (e) {
      setSendErr(e.message)
      setConfirm(false)
    } finally {
      setSending(false)
    }
  }

  if (txHash) return (
    <div className="tab-content send send--success">
      <div className="send__success-icon">✅</div>
      <h3 className="send__success-title">Transação Enviada!</h3>
      <p className="send__success-sub">Aguardando confirmação na rede Bitcoin</p>
      <div className="send__txhash-box">
        <span className="send__txhash-label">Hash da transação</span>
        <span className="mono send__txhash">{txHash}</span>
        <a
          href={`https://blockstream.info/tx/${txHash}`}
          target="_blank"
          rel="noopener noreferrer"
          className="send__explorer-link"
        >
          Ver na Blockchain ↗
        </a>
      </div>
      <button className="btn-primary" onClick={() => { setTxHash(null); setAmountBtc(''); setRecipient('') }}>
        Nova Transação
      </button>
    </div>
  )

  return (
    <div className="tab-content send">
      {/* Confirmation overlay */}
      {confirm && (
        <div className="send__confirm-overlay">
          <div className="send__confirm-box">
            <h3 className="send__confirm-title">⚠️ Confirmar Envio</h3>
            <p className="send__confirm-warn">Esta ação é irreversível.</p>
            <table className="send__confirm-table">
              <tbody>
                <tr><td>Para</td><td className="mono">{truncAddr(recipient, 16)}</td></tr>
                <tr><td>Valor</td><td>{fmt8(amount)} BTC</td></tr>
                <tr><td>Taxa</td><td>~{fmt8(feeBtc)} BTC</td></tr>
                <tr className="send__confirm-total"><td>Total</td><td>{fmt8(totalBtc)} BTC</td></tr>
              </tbody>
            </table>
            {sendErr && <p className="wallet-form__error">⚠ {sendErr}</p>}
            <div className="send__confirm-btns">
              <button className="btn-ghost" onClick={() => setConfirm(false)} disabled={sending}>Cancelar</button>
              <button className="btn-danger" onClick={handleSend} disabled={sending}>
                {sending ? '⟳ Enviando...' : 'Confirmar Envio'}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="send__field">
        <label className="send__label">Endereço de destino</label>
        <input
          id="send-recipient"
          className="wallet-form__input"
          type="text"
          placeholder="1... ou bc1..."
          value={recipient}
          onChange={(e) => setRecipient(e.target.value)}
          spellCheck={false}
        />
      </div>

      <div className="send__field">
        <label className="send__label">Quantidade</label>
        <div className="send__amount-row">
          <input
            id="send-amount"
            className="wallet-form__input"
            type="number"
            min="0.00000001"
            step="0.0001"
            placeholder="0.00000000"
            value={amountBtc}
            onChange={(e) => setAmountBtc(e.target.value)}
          />
          <span className="send__currency">BTC</span>
        </div>
      </div>

      <div className="send__field">
        <label className="send__label">Velocidade da transação</label>
        {feeErr && <p className="wallet-form__error">⚠ {feeErr} (usando 10 sat/vbyte)</p>}
        <div className="send__fee-options">
          {Object.values(FEE_LABELS).map(({ label, sub, key }) => (
            <label
              key={key}
              className={`fee-option ${feeSpeed === key ? 'fee-option--active' : ''}`}
            >
              <input
                type="radio"
                name="fee-speed"
                value={key}
                checked={feeSpeed === key}
                onChange={() => setFeeSpeed(key)}
                className="fee-option__radio"
              />
              <span className="fee-option__label">{label}</span>
              <span className="fee-option__sub">{sub}</span>
              {fees && (
                <span className="fee-option__rate">{Math.ceil(fees[key])} sat/vb</span>
              )}
            </label>
          ))}
        </div>
      </div>

      {/* Summary */}
      {amount > 0 && (
        <div className="send__summary">
          <div className="send__summary-row"><span>Valor</span><span className="mono">{fmt8(amount)} BTC</span></div>
          <div className="send__summary-row"><span>Taxa estimada</span><span className="mono">~{fmt8(feeBtc)} BTC</span></div>
          <div className="send__summary-row send__summary-row--total"><span>Total</span><span className="mono">{fmt8(totalBtc)} BTC</span></div>
        </div>
      )}

      {sendErr && !confirm && <p className="wallet-form__error">⚠ {sendErr}</p>}

      <button
        id="send-submit-btn"
        className="btn-primary"
        style={{ width: '100%' }}
        disabled={!canConfirm}
        onClick={() => { setSendErr(null); setConfirm(true) }}
      >
        Revisar Envio →
      </button>
    </div>
  )
}

// ── History Tab ───────────────────────────────────────────────────────────────

function HistoryTab({ wallet }) {
  const [txs, setTxs]       = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError]   = useState(null)

  useEffect(() => {
    getTransactions(wallet.id)
      .then(setTxs)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [wallet.id])

  if (loading) return <div className="tab-content history"><div className="history__loading">Carregando histórico…</div></div>
  if (error)   return <div className="tab-content history"><p className="wallet-card__error">⚠ {error}</p></div>
  if (!txs || txs.length === 0) return (
    <div className="tab-content history">
      <div className="history__empty">
        <span>📭</span>
        <p>Nenhuma transação encontrada</p>
      </div>
    </div>
  )

  return (
    <div className="tab-content history">
      <p className="history__count">{txs.length} transação{txs.length !== 1 ? 'ões' : ''}</p>
      <div className="history__list">
        {txs.map((tx) => {
          const net  = txNetAmount(tx, wallet.address)
          const recv = net >= 0
          const sats = Math.abs(net)
          const btc  = sats / 1e8
          return (
            <div key={tx.txid} className={`tx-item ${recv ? 'tx-item--recv' : 'tx-item--sent'}`}>
              <div className="tx-item__arrow">{recv ? '↓' : '↑'}</div>
              <div className="tx-item__info">
                <div className="tx-item__amount">
                  {recv ? '+' : '-'}{fmt8(btc)} BTC
                </div>
                <div className="tx-item__meta">
                  <span className="mono tx-item__txid">{tx.txid.slice(0, 16)}…</span>
                  <span className="tx-item__date">{fmtDate(tx.status?.block_time)}</span>
                </div>
                {!tx.status?.confirmed && (
                  <span className="tx-item__unconfirmed">⏳ Não confirmado</span>
                )}
              </div>
              <a
                href={`https://blockstream.info/tx/${tx.txid}`}
                target="_blank"
                rel="noopener noreferrer"
                className="tx-item__link"
                title="Ver na blockchain"
              >↗</a>
            </div>
          )
        })}
      </div>
    </div>
  )
}

// ── Wallet Drawer (main export) ───────────────────────────────────────────────

const TABS = [
  { id: 'overview', label: '📊 Visão Geral', Component: OverviewTab },
  { id: 'send',     label: '↑ Enviar',       Component: SendTab      },
  { id: 'history',  label: '📋 Histórico',   Component: HistoryTab   },
]

export default function WalletDrawer({ wallet, onClose, onDelete }) {
  const [tab, setTab]       = useState('overview')
  const [deleting, setDel]  = useState(false)
  const backdropRef         = useRef(null)

  // Close on Escape
  useEffect(() => {
    const h = (e) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])

  const Active = TABS.find((t) => t.id === tab)?.Component

  return (
    <div
      className="drawer-overlay"
      ref={backdropRef}
      onClick={(e) => { if (e.target === backdropRef.current) onClose() }}
    >
      <aside className="drawer-panel glass-panel" role="complementary" aria-label={`Carteira ${wallet.label}`}>
        {/* Header */}
        <div className="drawer__header">
          <div className="drawer__header-left">
            <div className="drawer__icon">₿</div>
            <div>
              <h2 className="drawer__title">{wallet.label}</h2>
              <span className="drawer__address mono">{truncAddr(wallet.address)}</span>
            </div>
          </div>
          <div className="drawer__header-right" style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <button
              className="btn-outline"
              style={{ color: 'var(--error)', borderColor: 'rgba(255,59,48,0.3)' }}
              onClick={async () => {
                if (!confirm(`Excluir "${wallet.label}"? Isso é permanente.`)) return
                setDel(true)
                try { await onDelete(wallet.id) } catch { setDel(false) }
              }}
              disabled={deleting}
              aria-label="Excluir carteira"
            >
              🗑 Excluir
            </button>
            <button className="btn-close" onClick={onClose} aria-label="Fechar">✕</button>
          </div>
        </div>

        {/* Tabs */}
        <div className="drawer__tabs nav__tabs" role="tablist" style={{ margin: '1rem 2rem', display: 'flex', justifyContent: 'space-around' }}>
          {TABS.map((t) => (
            <button
              key={t.id}
              id={`drawer-tab-${t.id}`}
              role="tab"
              aria-selected={tab === t.id}
              className={`nav__tab ${tab === t.id ? 'nav__tab--active' : ''}`}
              onClick={() => setTab(t.id)}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="drawer__body" style={{ padding: '0 2rem 2rem', flex: 1, display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {Active && <Active wallet={wallet} />}
        </div>
      </aside>
    </div>
  )
}
