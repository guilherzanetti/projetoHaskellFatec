import { useState, useEffect, useCallback } from 'react'
import WalletCard from '../components/WalletCard'
import WalletDrawer from '../components/WalletDrawer'
import MnemonicModal from '../components/MnemonicModal'
import ImportWalletModal from '../components/ImportWalletModal'
import { createWallet, listWallets, deleteWallet } from '../services/walletApi'

export default function WalletPage() {
  const [wallets, setWallets]         = useState([])
  const [loadingList, setLoadingList] = useState(true)
  const [listError, setListError]     = useState(null)

  const [mode, setMode]   = useState(null) // null | 'create' | 'import'
  const [formLabel, setLabel] = useState('')
  const [creating, setCreating] = useState(false)
  const [createError, setCreateError] = useState(null)

  const [mnemonicData, setMnemonicData] = useState(null) // { mnemonic, walletLabel }
  const [selectedWallet, setSelectedWallet] = useState(null)

  // Load wallet list on mount
  useEffect(() => {
    listWallets()
      .then(setWallets)
      .catch((e) => setListError(e.message))
      .finally(() => setLoadingList(false))
  }, [])

  // Create new wallet
  const handleCreate = useCallback(async (e) => {
    e.preventDefault()
    if (!formLabel.trim()) return
    setCreating(true)
    setCreateError(null)
    try {
      const data = await createWallet(formLabel.trim())
      setWallets((prev) => [data.wallet, ...prev])
      setMnemonicData({ mnemonic: data.mnemonic, walletLabel: data.wallet.label })
      setLabel('')
      setMode(null)
    } catch (err) {
      setCreateError(err.message)
    } finally {
      setCreating(false)
    }
  }, [formLabel])

  // Import existing wallet
  const handleImported = useCallback((data) => {
    setWallets((prev) => [data.wallet, ...prev])
    setMnemonicData({ mnemonic: data.mnemonic, walletLabel: data.wallet.label })
    setMode(null)
  }, [])

  // Delete wallet (called from drawer)
  const handleDelete = useCallback(async (id) => {
    await deleteWallet(id)
    setWallets((prev) => prev.filter((w) => w.id !== id))
    setSelectedWallet(null)
  }, [])

  return (
    <div className="wallet-page" style={{ display: 'flex', flexDirection: 'column', gap: '3rem' }}>
      {/* Massive Typographic Hero */}
      <div className="wallet-hero">
        <h1 className="text-hero">Carteiras</h1>
        <p className="wallet-hero__subtitle">
          Gerencie seus ativos digitais com segurança local. Chaves geradas no seu ambiente.
        </p>
        <div className="wallet-actions-bar">
          <button
            id="new-wallet-btn"
            className={`btn-primary`}
            onClick={() => { setMode(mode === 'create' ? null : 'create'); setCreateError(null) }}
            style={{ opacity: mode === 'create' ? 0.8 : 1 }}
          >
            {mode === 'create' ? '✕ Cancelar' : '+ Nova Carteira'}
          </button>
          <button
            id="import-wallet-btn"
            className="btn-outline"
            onClick={() => setMode('import')}
          >
            🔑 Importar
          </button>
        </div>
      </div>

      {/* Create form */}
      {mode === 'create' && (
        <form className="create-form glass-panel" onSubmit={handleCreate}>
          <div className="create-form__input-group">
            <input
              id="wallet-label-input"
              className="input-text"
              type="text"
              placeholder="Nome da carteira (ex: Poupança Bitcoin)"
              value={formLabel}
              onChange={(e) => setLabel(e.target.value)}
              maxLength={60}
              autoFocus
              required
            />
            <button
              id="create-wallet-submit"
              className="btn-primary"
              type="submit"
              disabled={creating || !formLabel.trim()}
              style={{ padding: '0.75rem 2rem' }}
            >
              {creating ? <span className="spinner-inline" style={{ animation: 'shimmer 1s infinite' }}>⟳</span> : 'Criar'}
            </button>
          </div>
          {createError && <p className="color-error" style={{ fontSize: '0.85rem' }}>⚠ {createError}</p>}
          <p className="color-warning" style={{ fontSize: '0.8rem', opacity: 0.8 }}>
            Atenção: A seed phrase será exibida apenas uma vez.
          </p>
        </form>
      )}

      {/* Wallet list */}
      <div className="wallet-list">
        {loadingList ? (
          <div className="wallet-list__loading" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div className="glass-panel" style={{ height: '140px', borderRadius: 'var(--radius-lg)', opacity: 0.5, animation: 'shimmer 2s infinite' }} />
            <div className="glass-panel" style={{ height: '100px', borderRadius: 'var(--radius-lg)', opacity: 0.3, animation: 'shimmer 2s infinite' }} />
          </div>
        ) : listError ? (
          <div className="wallet-list__error">
            <span>⚠️</span>
            <p>Erro ao carregar carteiras: {listError}</p>
          </div>
        ) : wallets.length === 0 ? (
          <div className="wallet-list__empty">
            <div className="wallet-list__empty-icon">₿</div>
            <p>Nenhuma carteira ainda.</p>
            <p className="wallet-list__empty-hint">Crie uma nova ou importe com sua seed phrase.</p>
          </div>
        ) : (
          wallets.map((wallet) => (
            <WalletCard
              key={wallet.id}
              wallet={wallet}
              onOpen={() => setSelectedWallet(wallet)}
              onDelete={handleDelete}
            />
          ))
        )}
      </div>

      {/* Import modal */}
      {mode === 'import' && (
        <ImportWalletModal
          onImported={handleImported}
          onClose={() => setMode(null)}
        />
      )}

      {/* Mnemonic modal (shown after create or import) */}
      {mnemonicData && (
        <MnemonicModal
          mnemonic={mnemonicData.mnemonic}
          walletLabel={mnemonicData.walletLabel}
          onClose={() => setMnemonicData(null)}
        />
      )}

      {/* Wallet drawer (shown when a wallet is selected) */}
      {selectedWallet && (
        <WalletDrawer
          wallet={selectedWallet}
          onClose={() => setSelectedWallet(null)}
          onDelete={handleDelete}
        />
      )}
    </div>
  )
}
