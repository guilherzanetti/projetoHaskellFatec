-- | Handlers: Servant API type + all request handlers.
module Handlers
  ( WalletAPI
  , Config (..)
  , walletServer
  ) where

import Servant
import Data.Aeson (encode, object, (.=), Value)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (formatTime, defaultTimeLocale)
import Data.UUID.V4 (nextRandom)
import qualified Data.UUID as UUID
import Control.Monad.IO.Class (liftIO)

import WalletTypes
import WalletStore (WalletStore (..))
import WalletService

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------

data Config = Config
  { cfgGenerateScript :: !FilePath
  , cfgImportScript   :: !FilePath
  , cfgSendScript     :: !FilePath
  }

-- ---------------------------------------------------------------------------
-- API type
-- ---------------------------------------------------------------------------

type WalletAPI =
  "api" :> "wallets" :>
  (    -- POST /api/wallets            — create new wallet
       ReqBody '[JSON] CreateWalletRequest  :> Post '[JSON] CreateWalletResponse
  :<|> -- POST /api/wallets/import     — import from mnemonic
       "import"       :> ReqBody '[JSON] ImportWalletRequest :> Post '[JSON] CreateWalletResponse
  :<|> -- GET  /api/wallets/fee-estimate
       "fee-estimate" :> Get  '[JSON] FeeEstimate
  :<|> -- GET  /api/wallets
       Get '[JSON] [Wallet]
  :<|> -- GET  /api/wallets/:id/balance
       Capture "id" Text :> "balance"      :> Get  '[JSON] BalanceResponse
  :<|> -- GET  /api/wallets/:id/transactions
       Capture "id" Text :> "transactions" :> Get  '[JSON] Value
  :<|> -- POST /api/wallets/:id/send
       Capture "id" Text :> "send"
         :> ReqBody '[JSON] SendRequest
         :> Post '[JSON] SendResponse
  :<|> -- DELETE /api/wallets/:id
       Capture "id" Text :> Delete '[JSON] NoContent
  )

-- ---------------------------------------------------------------------------
-- Server
-- ---------------------------------------------------------------------------

walletServer :: WalletStore -> Config -> Server WalletAPI
walletServer store cfg =
       createHandler   store cfg
  :<|> importHandler   store cfg
  :<|> feeEstHandler
  :<|> listHandler     store
  :<|> balanceHandler  store
  :<|> txHandler       store
  :<|> sendHandler     store cfg
  :<|> deleteHandler   store

-- ---------------------------------------------------------------------------
-- Handlers
-- ---------------------------------------------------------------------------

-- | Create a brand-new wallet.
createHandler :: WalletStore -> Config -> CreateWalletRequest -> Handler CreateWalletResponse
createHandler store cfg req = do
  gw <- liftIO (generateWallet (cfgGenerateScript cfg)) >>= orServerError 500
  makeAndSave store (cwrLabel req) gw

-- | Import a wallet from an existing BIP39 mnemonic.
importHandler :: WalletStore -> Config -> ImportWalletRequest -> Handler CreateWalletResponse
importHandler store cfg req = do
  gw <- liftIO (importWallet (cfgImportScript cfg) (iwrMnemonic req)) >>= orServerError 400
  makeAndSave store (iwrLabel req) gw

-- | Return current fee estimates (sat/vbyte).
feeEstHandler :: Handler FeeEstimate
feeEstHandler =
  liftIO fetchFeeEstimate >>= orServerError 502

-- | List all wallets (public info only).
listHandler :: WalletStore -> Handler [Wallet]
listHandler store = liftIO $ map swPublic <$> storeList store

-- | Get balance for a wallet.
balanceHandler :: WalletStore -> Text -> Handler BalanceResponse
balanceHandler store wid = do
  sw <- requireWallet store wid
  liftIO (fetchBalance (wAddress (swPublic sw))) >>= orServerError 502

-- | Get transaction history for a wallet.
txHandler :: WalletStore -> Text -> Handler Value
txHandler store wid = do
  sw <- requireWallet store wid
  liftIO (fetchTransactions (wAddress (swPublic sw))) >>= orServerError 502

-- | Send Bitcoin from a wallet.
sendHandler :: WalletStore -> Config -> Text -> SendRequest -> Handler SendResponse
sendHandler store cfg wid req = do
  sw <- requireWallet store wid
  let pk      = swPrivateKey sw
      addr    = wAddress (swPublic sw)
      recipient = srRecipient req
      amt     = srAmountBtc req
      feeRate = srFeeRateSatVbyte req
  txHash <- liftIO (sendBitcoin (cfgSendScript cfg) pk addr recipient amt feeRate)
              >>= orServerError 400
  pure (SendResponse txHash)

-- | Delete a wallet by id.
deleteHandler :: WalletStore -> Text -> Handler NoContent
deleteHandler store wid = do
  removed <- liftIO $ storeDelete store wid
  if removed then pure NoContent else throwError err404

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

-- | Look up a stored wallet or throw 404.
requireWallet :: WalletStore -> Text -> Handler StoredWallet
requireWallet store wid = do
  mw <- liftIO $ storeFind store wid
  case mw of
    Just sw -> pure sw
    Nothing -> throwError err404

-- | Turn an Either error into a Servant error with the given HTTP status.
orServerError :: Int -> Either String a -> Handler a
orServerError _code (Right v)  = pure v
orServerError code  (Left msg) = throwError (errFor code msg)
  where
    errFor 400 m = err400 { errBody = encode (object ["error" .= m]) }
    errFor 502 m = err502 { errBody = encode (object ["error" .= m]) }
    errFor _   m = err500 { errBody = encode (object ["error" .= m]) }

-- | Generate a new wallet id + creation timestamp, persist, and return the response.
makeAndSave :: WalletStore -> Text -> GeneratedWallet -> Handler CreateWalletResponse
makeAndSave store label gw = do
  wid <- liftIO $ T.pack . UUID.toString <$> nextRandom
  now <- liftIO $ T.pack . formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" <$> getCurrentTime
  let wallet = Wallet { wId = wid, wLabel = label, wAddress = gwAddress gw, wCreatedAt = now }
      stored = StoredWallet { swPublic = wallet, swPrivateKey = gwPrivateKey gw }
  liftIO $ storeSave store stored
  pure CreateWalletResponse { crWallet = wallet, crMnemonic = gwMnemonic gw }
