import { useState, useEffect, useCallback, useRef } from 'react'
import QRCode from 'qrcode'
import { getBalance, getTransactions, getFeeEstimate, sendBitcoin, updateWalletTags, createNote } from '../services/walletApi'
import { useAuth } from '../contexts/AuthContext'

function fmt8(n) { return n.toFixed(8) }
function fmtDate(ts) {
  if (!ts) return '—'
  return new Date(ts * 1000).toLocaleDateString('pt-BR', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
function truncAddr(a, n = 10) {
  if (!a || a.length < 20) return a
  return `${a.slice(0, n)}...${a.slice(-8)}`
}

function txNetAmount(tx, address) {
  const inSum = tx.vin.reduce((s, v) => s + (v.prevout?.scriptpubkey_address === address ? v.prevout.value : 0), 0)
  const outSum = tx.vout.reduce((s, v) => s + (v.scriptpubkey_address === address ? v.value : 0), 0)
  return outSum - inSum
}

function OverviewTab({ wallet, btcPrice }) {
  const [qrSrc, setQrSrc] = useState('')
  const [balance, setBalance] = useState(null)
  const [error, setError] = useState(null)
  const [copied, setCopied] = useState(false)
  const [receiveAmount, setReceiveAmount] = useState('')

  const bip21Uri = receiveAmount ? `bitcoin:${wallet.address}?amount=${receiveAmount}` : wallet.address

  useEffect(() => {
    QRCode.toDataURL(bip21Uri, { width: 200, margin: 2, color: { dark: '#f7931a', light: '#141419' } })
      .then(setQrSrc).catch(() => {})
  }, [bip21Uri])

  const refresh = useCallback(async () => {
    try { setBalance(await getBalance(wallet.id)); setError(null) }
    catch (e) { setError(e.message) }
  }, [wallet.id])

  useEffect(() => {
    refresh()
    const interval = setInterval(refresh, 5000)
    return () => clearInterval(interval)
  }, [refresh])

  const copy = useCallback(() => {
    navigator.clipboard.writeText(wallet.address)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }, [wallet.address])

  const brlValue = balance && btcPrice ? balance.totalBtc * btcPrice : null

  return (
    <div className="tab-content overview">
      <div className="overview__qr-wrap">
        {qrSrc ? <img src={qrSrc} alt="QR Code" width={200} height={200} /> : <div className="overview__qr-placeholder">QR</div>}
        <p className="overview__qr-hint">Mostre para receber Bitcoin</p>
      </div>

      <input className="input-text" type="number" step="0.0001" min="0" placeholder="Valor solicitado (BTC)" value={receiveAmount} onChange={e => setReceiveAmount(e.target.value)} style={{ fontSize: '0.85rem' }} />

      <div className="overview__address-card">
        <span className="overview__address-label">Endereco</span>
        <div className="overview__address-row">
          <span className="mono overview__address">{wallet.address}</span>
          <button className={`btn-icon ${copied ? 'btn-icon--ok' : ''}`} onClick={copy}>{copied ? 'Copiado' : 'Copiar'}</button>
        </div>
      </div>

      <div className="overview__balance-card">
        <span className="overview__balance-label">Saldo Total</span>
        {balance ? (
          <>
            <div className="overview__btc">{fmt8(balance.totalBtc)} <span className="overview__unit">BTC</span></div>
            {brlValue !== null && brlValue > 0 && (
              <div style={{ fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                R$ {brlValue.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
            )}
            <div style={{ display: 'flex', gap: '1.5rem', marginTop: '0.75rem', fontSize: '0.8rem' }}>
              <div><span style={{ color: 'var(--text-tertiary)', fontSize: '0.7rem' }}>On-chain</span><div className="text-mono">{fmt8(balance.onChainBtc)} BTC</div></div>
              <div><span style={{ color: 'var(--text-tertiary)', fontSize: '0.7rem' }}>P2P</span><div className="text-mono" style={{ color: balance.offChainBtc > 0 ? 'var(--accent)' : undefined }}>{fmt8(balance.offChainBtc)} BTC</div></div>
            </div>
          </>
        ) : (
          <div className="overview__loading">Consultando...</div>
        )}
        {error && <p className="color-error">{error}</p>}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.5rem' }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--success)', display: 'inline-block', animation: 'pulse 2s infinite' }} />
          <span style={{ fontSize: '0.7rem', color: 'var(--text-tertiary)' }}>Atualizando a cada 5s</span>
        </div>
      </div>
    </div>
  )
}

function SendTab({ wallet, user }) {
  const [recipient, setRecipient] = useState('')
  const [amountBtc, setAmountBtc] = useState('')
  const [feeSpeed, setFeeSpeed] = useState('normal')
  const [fees, setFees] = useState(null)
  const [sending, setSending] = useState(false)
  const [sendErr, setSendErr] = useState(null)
  const [txHash, setTxHash] = useState(null)
  const [confirm, setConfirm] = useState(false)
  const [password, setPassword] = useState('')
  const [otpCode, setOtpCode] = useState('')

  useEffect(() => { getFeeEstimate().then(setFees).catch(() => {}) }, [])

  const feeRateSatVbyte = fees ? Math.ceil(fees[feeSpeed]) : 10
  const feeBtc = feeRateSatVbyte * 226 / 1e8
  const amount = parseFloat(amountBtc) || 0
  const totalBtc = amount + feeBtc

  const isRecipientValid = recipient.trim().length > 25
  const isAmountValid = amount > 0 && amount <= 21000000
  const canReview = isRecipientValid && isAmountValid && !sending
  const canConfirm = canReview && password.length >= 6

  function handleAmountChange(value) {
    // Allow empty, or valid BTC decimal format only
    if (value === '' || value === '0' || value === '0.') {
      setAmountBtc(value)
      return
    }
    // Match valid BTC amounts: up to 8 decimal places
    if (/^\d*\.?\d{0,8}$/.test(value) && parseFloat(value) <= 21000000) {
      setAmountBtc(value)
    }
  }

  function setPresetAmount(val) {
    setAmountBtc(val)
  }

  async function handleSend() {
    setSending(true); setSendErr(null)
    try {
      const res = await sendBitcoin(wallet.id, { recipient: recipient.trim(), amountBtc: amount, feeRateSatVbyte, password, otpCode: otpCode || undefined })
      setTxHash(res.txHash); setConfirm(false)
    } catch (e) { setSendErr(e.message); setConfirm(false) }
    finally { setSending(false) }
  }

  if (txHash) return (
    <div className="tab-content send send--success">
      <div className="send__success-checkmark">✓</div>
      <h3 style={{ fontSize: '1.3rem', marginBottom: '0.25rem' }}>Transação Enviada!</h3>
      <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', marginBottom: '1.25rem' }}>
        Sua transação foi transmitida para a rede Bitcoin.
      </p>
      <div className="send__txhash-box">
        <span className="send__txhash-label">HASH DA TRANSAÇÃO</span>
        <span className="mono send__txhash">{txHash}</span>
        <a className="send__explorer-link" href={`https://blockstream.info/tx/${txHash}`} target="_blank" rel="noopener noreferrer">
          Explorar na Blockchain →
        </a>
      </div>
      <button className="btn-primary" style={{ width: '100%' }} onClick={() => { setTxHash(null); setAmountBtc(''); setRecipient(''); setPassword(''); setOtpCode('') }}>Nova Transação</button>
    </div>
  )

  return (
    <div className="tab-content send">
      {/* ── Confirmation Modal ────────────────────────── */}
      {confirm && (
        <div className="send__confirm-overlay">
          <div className="send__confirm-box">
            <div className="send__confirm-header">
              <div className="send__confirm-icon">₿</div>
              <h3 style={{ fontSize: '1.15rem' }}>Confirmar Envio</h3>
              <p className="send__confirm-warn">
                ⚠ Esta ação é irreversível. Verifique todos os dados.
              </p>
            </div>

            <div className="send__confirm-details">
              <div className="send__confirm-detail-row">
                <span className="send__confirm-detail-label">Destinatário</span>
                <span className="mono send__confirm-detail-value" style={{ fontSize: '0.75rem', wordBreak: 'break-all' }}>{recipient}</span>
              </div>
              <div className="send__confirm-detail-row">
                <span className="send__confirm-detail-label">Valor</span>
                <span className="send__confirm-detail-value">{fmt8(amount)} BTC</span>
              </div>
              <div className="send__confirm-detail-row">
                <span className="send__confirm-detail-label">Taxa de rede</span>
                <span className="send__confirm-detail-value">~{fmt8(feeBtc)} BTC <span style={{ fontSize: '0.7rem', color: 'var(--text-tertiary)' }}>({feeRateSatVbyte} sat/vB)</span></span>
              </div>
              <div className="send__confirm-detail-row send__confirm-detail-row--total">
                <span className="send__confirm-detail-label">Total debitado</span>
                <span className="send__confirm-detail-value" style={{ color: 'var(--accent)', fontWeight: 700 }}>{fmt8(totalBtc)} BTC</span>
              </div>
            </div>

            <div className="send__confirm-auth">
              <label className="send__label" style={{ marginBottom: '0.25rem' }}>🔒 Autenticação</label>
              <input className="input-text" type="password" placeholder="Sua senha" value={password} onChange={e => setPassword(e.target.value)} autoFocus />
              {user?.totpEnabled && (
                <input className="input-text" type="text" placeholder="Código 2FA (6 dígitos)" value={otpCode} onChange={e => setOtpCode(e.target.value)} maxLength={6} style={{ marginTop: '0.5rem' }} />
              )}
            </div>

            {sendErr && (
              <div className="send__confirm-error">
                <span>✕</span> {sendErr}
              </div>
            )}

            <div className="send__confirm-btns">
              <button className="btn-ghost" onClick={() => { setConfirm(false); setSendErr(null) }} disabled={sending}>Cancelar</button>
              <button className="btn-danger" onClick={handleSend} disabled={!canConfirm || sending}>
                {sending ? (
                  <><span className="send__spinner" /> Enviando...</>
                ) : (
                  'Confirmar Envio'
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Recipient ────────────────────────────────── */}
      <div className="send__field">
        <label className="send__label">
          <span className="send__label-icon">📍</span> Endereço de destino
        </label>
        <div className="send__input-wrap">
          <input
            className={`wallet-form__input ${recipient && !isRecipientValid ? 'wallet-form__input--invalid' : ''} ${isRecipientValid ? 'wallet-form__input--valid' : ''}`}
            type="text"
            placeholder="bc1q... ou 1A1zP1..."
            value={recipient}
            onChange={e => setRecipient(e.target.value)}
            spellCheck={false}
            autoComplete="off"
          />
          {isRecipientValid && <span className="send__input-check">✓</span>}
        </div>
      </div>

      {/* ── Amount ───────────────────────────────────── */}
      <div className="send__field">
        <label className="send__label">
          <span className="send__label-icon">💰</span> Quantidade
        </label>
        <div className="send__amount-wrap">
          <div className="send__amount-input-row">
            <input
              className="wallet-form__input send__amount-input"
              type="text"
              inputMode="decimal"
              placeholder="0.00000000"
              value={amountBtc}
              onChange={e => handleAmountChange(e.target.value)}
              autoComplete="off"
            />
            <span className="send__currency-badge">BTC</span>
          </div>
          <div className="send__presets">
            {[
              { label: '0.001', value: '0.001' },
              { label: '0.01', value: '0.01' },
              { label: '0.1', value: '0.1' },
              { label: '1.0', value: '1' },
            ].map(p => (
              <button
                key={p.value}
                type="button"
                className={`send__preset-btn ${amountBtc === p.value ? 'send__preset-btn--active' : ''}`}
                onClick={() => setPresetAmount(p.value)}
              >
                {p.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* ── Fee Speed ────────────────────────────────── */}
      <div className="send__field">
        <label className="send__label">
          <span className="send__label-icon">⛽</span> Velocidade da transação
        </label>
        <div className="send__fee-options">
          {[
            { icon: '⚡', label: 'Rápida', sub: '~10 min', key: 'fast' },
            { icon: '🕐', label: 'Normal', sub: '~1 hora', key: 'normal' },
            { icon: '🐢', label: 'Econômica', sub: '~24h', key: 'slow' },
          ].map(({ icon, label, sub, key }) => (
            <label key={key} className={`fee-option ${feeSpeed === key ? 'fee-option--active' : ''}`}>
              <input type="radio" name="fee-speed" value={key} checked={feeSpeed === key} onChange={() => setFeeSpeed(key)} className="fee-option__radio" />
              <span className="fee-option__icon">{icon}</span>
              <span className="fee-option__label">{label}</span>
              <span className="fee-option__sub">{sub}</span>
              {fees && <span className="fee-option__rate">{Math.ceil(fees[key])} sat/vB</span>}
            </label>
          ))}
        </div>
      </div>

      {/* ── Summary ──────────────────────────────────── */}
      {amount > 0 && (
        <div className="send__summary">
          <div className="send__summary-row">
            <span>Valor do envio</span>
            <span className="mono">{fmt8(amount)} BTC</span>
          </div>
          <div className="send__summary-row">
            <span>Taxa de rede <span style={{ fontSize: '0.7rem', color: 'var(--text-tertiary)' }}>({feeRateSatVbyte} sat/vB)</span></span>
            <span className="mono">~{fmt8(feeBtc)} BTC</span>
          </div>
          <div className="send__summary-row send__summary-row--total">
            <span>Total</span>
            <span className="mono">{fmt8(totalBtc)} BTC</span>
          </div>
        </div>
      )}

      {/* ── Review Button ────────────────────────────── */}
      <button
        className="btn-primary send__review-btn"
        disabled={!canReview}
        onClick={() => { setSendErr(null); setPassword(''); setOtpCode(''); setConfirm(true) }}
      >
        {!isRecipientValid && !isAmountValid ? 'Preencha os dados acima' :
         !isRecipientValid ? 'Informe um endereço válido' :
         !isAmountValid ? 'Informe a quantidade' :
         '🔒 Revisar Envio'}
      </button>
    </div>
  )
}

function HistoryTab({ wallet }) {
  const [txs, setTxs] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [noteTxId, setNoteTxId] = useState(null)
  const [noteContent, setNoteContent] = useState('')
  const [notes, setNotes] = useState({})

  useEffect(() => {
    getTransactions(wallet.id).then(setTxs).catch(e => setError(e.message)).finally(() => setLoading(false))
  }, [wallet.id])

  async function handleAddNote(e) {
    e.preventDefault()
    if (!noteContent.trim() || !noteTxId) return
    try {
      await createNote(noteTxId, noteContent.trim())
      setNotes(prev => ({ ...prev, [noteTxId]: noteContent.trim() }))
      setNoteTxId(null); setNoteContent('')
    } catch {}
  }

  if (loading) return <div className="tab-content history"><div className="history__loading">Carregando...</div></div>
  if (error) return <div className="tab-content history"><p className="color-error">{error}</p></div>
  if (!txs || txs.length === 0) return <div className="tab-content history"><div className="history__empty"><p>Nenhuma transacao</p></div></div>

  return (
    <div className="tab-content history">
      <p className="history__count">{txs.length} transacao{txs.length !== 1 ? 'oes' : ''}</p>
      <div className="history__list">
        {txs.map(tx => {
          const net = txNetAmount(tx, wallet.address)
          const recv = net >= 0
          const btc = Math.abs(net) / 1e8
          return (
            <div key={tx.txid} className={`tx-item ${recv ? 'tx-item--recv' : 'tx-item--sent'}`}>
              <div className="tx-item__arrow">{recv ? 'v' : '^'}</div>
              <div className="tx-item__info">
                <div className="tx-item__amount">{recv ? '+' : '-'}{fmt8(btc)} BTC</div>
                <div className="tx-item__meta">
                  <span className="mono">{tx.txid.slice(0, 16)}...</span>
                  <span>{fmtDate(tx.status?.block_time)}</span>
                </div>
                {!tx.status?.confirmed && <span className="tx-item__unconfirmed">Pendente</span>}
                {notes[tx.txid] && <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)', marginTop: '0.25rem' }}>Nota: {notes[tx.txid]}</div>}
                {!notes[tx.txid] && noteTxId !== tx.txid && (
                  <button style={{ fontSize: '0.7rem', color: 'var(--accent)', background: 'none', border: 'none', cursor: 'pointer', padding: 0, marginTop: '0.25rem' }} onClick={() => setNoteTxId(tx.txid)}>+ Nota</button>
                )}
                {noteTxId === tx.txid && (
                  <form onSubmit={handleAddNote} style={{ display: 'flex', gap: '0.25rem', marginTop: '0.25rem' }}>
                    <input className="input-text" style={{ fontSize: '0.75rem', padding: '0.3rem 0.5rem', flex: 1 }} placeholder="Nota..." value={noteContent} onChange={e => setNoteContent(e.target.value)} autoFocus />
                    <button type="submit" className="btn-primary" style={{ padding: '0.3rem 0.5rem', fontSize: '0.7rem' }}>OK</button>
                    <button type="button" className="btn-ghost" style={{ padding: '0.3rem', fontSize: '0.7rem' }} onClick={() => setNoteTxId(null)}>X</button>
                  </form>
                )}
              </div>
              <a href={`https://blockstream.info/tx/${tx.txid}`} target="_blank" rel="noopener noreferrer" className="tx-item__link">{'>'}</a>
            </div>
          )
        })}
      </div>
    </div>
  )
}

function TagsTab({ wallet, onUpdate }) {
  const [tags, setTags] = useState(wallet.tags || [])
  const [newTag, setNewTag] = useState('')
  const [saving, setSaving] = useState(false)

  function addTag() {
    if (!newTag.trim() || tags.includes(newTag.trim())) return
    setTags(prev => [...prev, newTag.trim()]); setNewTag('')
  }

  async function handleSave() {
    setSaving(true)
    try { const updated = await updateWalletTags(wallet.id, tags); onUpdate(updated) } catch {}
    finally { setSaving(false) }
  }

  return (
    <div className="tab-content" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
      <h3>Tags</h3>
      <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
        {tags.map(tag => (
          <span key={tag} style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem', padding: '0.25rem 0.6rem', background: 'var(--accent-dim)', color: 'var(--accent)', borderRadius: 'var(--radius-sm)', fontSize: '0.8rem' }}>
            {tag}
            <button style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', padding: 0 }} onClick={() => setTags(prev => prev.filter(t => t !== tag))}>x</button>
          </span>
        ))}
      </div>
      <div style={{ display: 'flex', gap: '0.5rem' }}>
        <input className="input-text" style={{ flex: 1, fontSize: '0.85rem' }} placeholder="Nova tag" value={newTag} onChange={e => setNewTag(e.target.value)} onKeyDown={e => e.key === 'Enter' && (e.preventDefault(), addTag())} />
        <button className="btn-outline" style={{ fontSize: '0.8rem' }} onClick={addTag}>+</button>
      </div>
      <button className="btn-primary" onClick={handleSave} disabled={saving}>{saving ? 'Salvando...' : 'Salvar Tags'}</button>
    </div>
  )
}

const TABS = [
  { id: 'overview', label: 'Visao Geral', Component: OverviewTab },
  { id: 'send', label: 'Enviar', Component: SendTab },
  { id: 'history', label: 'Historico', Component: HistoryTab },
  { id: 'tags', label: 'Tags', Component: TagsTab },
]

export default function WalletDrawer({ wallet, onClose, onDelete, onUpdate, btcPrice }) {
  const { user } = useAuth()
  const [tab, setTab] = useState('overview')
  const [deleting, setDel] = useState(false)
  const backdropRef = useRef(null)

  useEffect(() => {
    const h = e => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])

  const Active = TABS.find(t => t.id === tab)?.Component

  return (
    <div className="drawer-overlay" ref={backdropRef} onClick={e => { if (e.target === backdropRef.current) onClose() }}>
      <aside className="drawer-panel glass-panel">
        <div className="drawer__header">
          <div className="drawer__header-left">
            <div className="drawer__icon">₿</div>
            <div>
              <h2 className="drawer__title">{wallet.label}</h2>
              <span className="drawer__address mono">{truncAddr(wallet.address)}</span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <button className="btn-outline" style={{ padding: '0.4rem 0.8rem', fontSize: '0.75rem', color: 'var(--error)', borderColor: 'rgba(255,59,48,0.3)' }} onClick={async () => {
              if (!confirm(`Excluir "${wallet.label}"?`)) return
              setDel(true)
              try { await onDelete(wallet.id) } catch { setDel(false) }
            }} disabled={deleting}>Excluir</button>
            <button className="btn-close" onClick={onClose}>X</button>
          </div>
        </div>

        <div className="drawer__tabs nav__tabs" style={{ margin: '1rem 2rem', display: 'flex', justifyContent: 'space-around' }}>
          {TABS.map(t => (
            <button key={t.id} className={`nav__tab ${tab === t.id ? 'nav__tab--active' : ''}`} onClick={() => setTab(t.id)}>{t.label}</button>
          ))}
        </div>

        <div style={{ padding: '0 2rem 2rem', flex: 1, display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {Active && (Active === SendTab ? <Active wallet={wallet} user={user} /> : Active === OverviewTab ? <Active wallet={wallet} btcPrice={btcPrice} /> : Active === TagsTab ? <Active wallet={wallet} onUpdate={onUpdate} /> : <Active wallet={wallet} />)}
        </div>
      </aside>
    </div>
  )
}
