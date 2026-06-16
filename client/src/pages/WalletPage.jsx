import { useState, useEffect, useCallback } from 'react'
import WalletCard from '../components/WalletCard'
import WalletDrawer from '../components/WalletDrawer'
import MnemonicModal from '../components/MnemonicModal'
import ImportWalletModal from '../components/ImportWalletModal'
import ImportWatchOnlyModal from '../components/ImportWatchOnlyModal'
import { listWallets, deleteWallet, getConsolidated, getPrice, createWallet } from '../services/walletApi'

export default function WalletPage() {
  const [wallets, setWallets]         = useState([])
  const [loadingList, setLoadingList] = useState(true)
  const [listError, setListError]     = useState(null)

  const [mode, setMode]   = useState(null)
  const [formLabel, setLabel] = useState('')
  const [formTags, setTags] = useState('')
  const [creating, setCreating] = useState(false)
  const [createError, setCreateError] = useState(null)

  const [mnemonicData, setMnemonicData] = useState(null)
  const [selectedWallet, setSelectedWallet] = useState(null)

  const [consolidated, setConsolidated] = useState(null)
  const [btcPrice, setBtcPrice] = useState(null)

  useEffect(() => {
    listWallets()
      .then(setWallets)
      .catch(e => setListError(e.message))
      .finally(() => setLoadingList(false))
    getConsolidated().then(setConsolidated).catch(() => {})
    getPrice().then(p => setBtcPrice(p.brl)).catch(() => {})
  }, [])

  const handleCreate = useCallback(async (e) => {
    e.preventDefault()
    if (!formLabel.trim()) return
    setCreating(true); setCreateError(null)
    try {
      const tags = formTags.split(',').map(t => t.trim()).filter(Boolean)
      const data = await createWallet(formLabel.trim(), tags)
      setWallets(prev => [data.wallet, ...prev])
      setMnemonicData({ mnemonic: data.mnemonic, walletLabel: data.wallet.label })
      setLabel(''); setTags(''); setMode(null)
      const c = await getConsolidated()
      setConsolidated(c)
    } catch (err) { setCreateError(err.message) }
    finally { setCreating(false) }
  }, [formLabel, formTags])

  const handleImported = useCallback((data) => {
    setWallets(prev => [data.wallet, ...prev])
    setMnemonicData({ mnemonic: data.mnemonic, walletLabel: data.wallet.label })
    setMode(null)
  }, [])

  const handleWatchImported = useCallback((wallet) => {
    setWallets(prev => [wallet, ...prev])
    setMode(null)
  }, [])

  const handleDelete = useCallback(async (id) => {
    await deleteWallet(id)
    setWallets(prev => prev.filter(w => w.id !== id))
    setSelectedWallet(null)
    getConsolidated().then(setConsolidated).catch(() => {})
  }, [])

  const totalBrl = consolidated ? consolidated.totalBtc * (btcPrice || 0) : null

  return (
    <div className="wallet-page" style={{ display: 'flex', flexDirection: 'column', gap: '3rem' }}>
      <div className="wallet-hero">
        <h1 className="text-hero">Carteiras</h1>

        {consolidated && (
          <div className="glass-panel" style={{ padding: '1.5rem 2rem', borderRadius: 'var(--radius-lg)', textAlign: 'center', width: '100%', maxWidth: '400px' }}>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Saldo Total</div>
            <div style={{ fontSize: '2rem', fontWeight: 300, letterSpacing: '-0.04em' }}>
              {consolidated.totalBtc.toFixed(8)} <span style={{ fontSize: '1rem', color: 'var(--text-tertiary)' }}>BTC</span>
            </div>
            {btcPrice && totalBrl !== null && (
              <div style={{ fontSize: '1rem', color: 'var(--text-secondary)' }}>
                R$ {totalBrl.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
            )}
            <div style={{ fontSize: '0.7rem', color: 'var(--text-tertiary)', marginTop: '0.25rem' }}>
              {consolidated.wallets} carteira{consolidated.wallets !== 1 ? 's' : ''}
            </div>
          </div>
        )}

        <div className="wallet-actions-bar">
          <button className="btn-primary" onClick={() => { setMode(mode === 'create' ? null : 'create'); setCreateError(null) }}>
            {mode === 'create' ? 'X Cancelar' : '+ Nova Carteira'}
          </button>
          <button className="btn-outline" onClick={() => setMode('import')}>Importar</button>
          <button className="btn-outline" onClick={() => setMode('watch')}>Watch-Only</button>
        </div>
      </div>

      {mode === 'create' && (
        <form className="create-form glass-panel" onSubmit={handleCreate}>
          <div className="create-form__input-group">
            <input className="input-text" type="text" placeholder="Nome da carteira" value={formLabel} onChange={e => setLabel(e.target.value)} maxLength={60} autoFocus required />
            <button className="btn-primary" type="submit" disabled={creating || !formLabel.trim()} style={{ padding: '0.75rem 2rem' }}>
              {creating ? '...' : 'Criar'}
            </button>
          </div>
          <input className="input-text" type="text" placeholder="Tags (separadas por virgula): ex: investimento, poupanca" value={formTags} onChange={e => setTags(e.target.value)} style={{ fontSize: '0.85rem' }} />
          {createError && <p className="color-error" style={{ fontSize: '0.85rem' }}>{createError}</p>}
          <p className="color-warning" style={{ fontSize: '0.8rem', opacity: 0.8 }}>A seed phrase sera exibida apenas uma vez.</p>
        </form>
      )}

      <div className="wallet-list">
        {loadingList ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div className="glass-panel" style={{ height: '140px', borderRadius: 'var(--radius-lg)', opacity: 0.5 }} />
            <div className="glass-panel" style={{ height: '100px', borderRadius: 'var(--radius-lg)', opacity: 0.3 }} />
          </div>
        ) : listError ? (
          <div><p>Erro: {listError}</p></div>
        ) : wallets.length === 0 ? (
          <div className="wallet-list__empty">
            <div className="wallet-list__empty-icon">₿</div>
            <p>Nenhuma carteira ainda.</p>
            <p className="wallet-list__empty-hint">Crie uma nova ou importe com sua seed phrase.</p>
          </div>
        ) : (
          wallets.map(wallet => (
            <WalletCard key={wallet.id} wallet={wallet} btcPrice={btcPrice} onOpen={() => setSelectedWallet(wallet)} />
          ))
        )}
      </div>

      {mode === 'import' && <ImportWalletModal onImported={handleImported} onClose={() => setMode(null)} />}
      {mode === 'watch' && <ImportWatchOnlyModal onImported={handleWatchImported} onClose={() => setMode(null)} />}
      {mnemonicData && <MnemonicModal mnemonic={mnemonicData.mnemonic} walletLabel={mnemonicData.walletLabel} onClose={() => setMnemonicData(null)} />}
      {selectedWallet && <WalletDrawer wallet={selectedWallet} btcPrice={btcPrice} onClose={() => setSelectedWallet(null)} onDelete={handleDelete} onUpdate={w => setWallets(prev => prev.map(x => x.id === w.id ? w : x))} />}
    </div>
  )
}
