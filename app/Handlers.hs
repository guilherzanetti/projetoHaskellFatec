module Handlers
  ( AppAPI
  , Config(..)
  , walletServer
  ) where

import Servant
import Data.Aeson (encode, object, (.=), Value, FromJSON(..), withObject, (.:))
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (formatTime, defaultTimeLocale)
import Data.UUID.V4 (nextRandom)
import qualified Data.UUID as UUID
import Control.Monad (when, unless)
import Control.Monad.IO.Class (liftIO)

import Crypto
import WalletTypes
import WalletStore (AppStore(..))
import WalletService
import UserTypes

type AuthHeader = Header "Authorization" Text

type AppAPI =
       "api" :> "auth" :> AuthAPI
  :<|> "api" :> ProtectedAPI

type AuthAPI =
       "register" :> ReqBody '[JSON] RegisterRequest :> Post '[JSON] AuthResponse
  :<|> "login"    :> ReqBody '[JSON] LoginRequest    :> Post '[JSON] AuthResponse

type ProtectedAPI =
       "wallets" :> AuthHeader :> WalletRoutes
  :<|> "transfers" :> AuthHeader :> TransferRoutes
  :<|> "users"   :> Capture "userId" Text :> AuthHeader :> UserRoutes

type WalletRoutes =
       ReqBody '[JSON] CreateWalletRequest :> Post '[JSON] CreateWalletResponse
  :<|> "import" :> ReqBody '[JSON] ImportWalletRequest :> Post '[JSON] CreateWalletResponse
  :<|> "import-watch" :> ReqBody '[JSON] ImportWatchOnlyRequest :> Post '[JSON] Wallet
  :<|> "fee-estimate" :> Get '[JSON] FeeEstimate
  :<|> Get '[JSON] [Wallet]
  :<|> "consolidated" :> Get '[JSON] ConsolidatedBalance
  :<|> "price" :> Get '[JSON] PriceResponse
  :<|> Capture "id" Text :> "balance" :> Get '[JSON] CombinedBalance
  :<|> Capture "id" Text :> "transactions" :> Get '[JSON] Value
  :<|> Capture "id" Text :> "send" :> ReqBody '[JSON] SendRequest :> Post '[JSON] SendResponse
  :<|> Capture "id" Text :> "tags" :> ReqBody '[JSON] TagUpdateRequest :> Put '[JSON] Wallet
  :<|> Capture "id" Text :> Delete '[JSON] NoContent

type TransferRoutes =
       ReqBody '[JSON] TransferRequest :> Post '[JSON] TransferResponse
  :<|> Get '[JSON] [TransferResponse]

type UserRoutes =
       "contacts" :> (
            Get '[JSON] [Contact]
       :<|> ReqBody '[JSON] ContactRequest :> Post '[JSON] Contact
       :<|> Capture "contactId" Text :> DeleteNoContent
       )
  :<|> "notes" :> (
            ReqBody '[JSON] NoteRequest :> Post '[JSON] TxNote
       :<|> Capture "noteId" Text :> DeleteNoContent
       )
  :<|> "totp" :> "setup" :> Post '[JSON] TotpSetupResponse
  :<|> "totp" :> "enable" :> ReqBody '[JSON] EnableTotpRequest :> Post '[JSON] User
  :<|> "password" :> ReqBody '[JSON] ChangePasswordRequest :> Post '[JSON] User
  :<|> "username" :> ReqBody '[JSON] ChangeUsernameRequest :> Post '[JSON] User

data Config = Config
  { cfgGenerateScript :: !FilePath
  , cfgImportScript   :: !FilePath
  , cfgSendScript     :: !FilePath
  }

newtype TagUpdateRequest = TagUpdateRequest { turTags :: [Text] }

instance FromJSON TagUpdateRequest where
  parseJSON = withObject "TagUpdateRequest" $ \v ->
    TagUpdateRequest <$> v .: "tags"

walletServer :: AppStore -> Config -> Server AppAPI
walletServer store cfg = authServer store :<|> protectedServer store cfg

authServer :: AppStore -> Server AuthAPI
authServer store = registerHandler store :<|> loginHandler store

protectedServer :: AppStore -> Config -> Server ProtectedAPI
protectedServer store cfg = walletRoutes store cfg :<|> transferRoutes store :<|> userRoutes store

walletRoutes :: AppStore -> Config -> Maybe Text -> Server WalletRoutes
walletRoutes store cfg mAuth =
       createHandler     store cfg mAuth
  :<|> importHandler     store cfg mAuth
  :<|> importWatchHandler store mAuth
  :<|> feeEstHandler
  :<|> listHandler       store mAuth
  :<|> consolidatedHandler store mAuth
  :<|> priceHandler
  :<|> balanceHandler    store mAuth
  :<|> txHandler         store mAuth
  :<|> sendHandler       store cfg mAuth
  :<|> updateTagsHandler store mAuth
  :<|> deleteHandler     store mAuth

transferRoutes :: AppStore -> Maybe Text -> Server TransferRoutes
transferRoutes store mAuth =
       transferHandler store mAuth
  :<|> listTransfersHandler store mAuth

userRoutes :: AppStore -> Text -> Maybe Text -> Server UserRoutes
userRoutes store uid mAuth =
       contactsHandler store uid mAuth
  :<|> notesHandler store uid mAuth
  :<|> totpSetupHandler store uid mAuth
  :<|> totpEnableHandler store uid mAuth
  :<|> changePasswordHandler store uid mAuth
  :<|> changeUsernameHandler store uid mAuth

registerHandler :: AppStore -> RegisterRequest -> Handler AuthResponse
registerHandler store req = do
  existing <- liftIO $ storeFindUserByEmail store (rrEmail req)
  case existing of
    Just _  -> throwError $ errFor 409 "Email ja cadastrado"
    Nothing -> do
      uid <- liftIO $ T.pack . UUID.toString <$> nextRandom
      ph  <- liftIO $ hashPassword (rrPassword req)
      let user = User uid (rrEmail req) (rrUsername req) ph Nothing False
      liftIO $ storeRegisterUser store user
      token <- liftIO $ createJWT uid
      pure $ AuthResponse token user

loginHandler :: AppStore -> LoginRequest -> Handler AuthResponse
loginHandler store req = do
  mUser <- liftIO $ storeFindUserByEmail store (lrEmail req)
  case mUser of
    Nothing -> throwError $ errFor 401 "Credenciais invalidas"
    Just user
      | not (verifyPassword (lrPassword req) (uPasswordHash user)) ->
          throwError $ errFor 401 "Credenciais invalidas"
      | uTotpEnabled user ->
          case lrOtpCode req of
            Nothing  -> throwError $ errFor 403 "Codigo OTP necessario"
            Just code -> do
              valid <- liftIO $ verifyTOTP (maybe "" id (uTotpSecret user)) code
              if valid then issueToken user
              else throwError $ errFor 401 "Codigo OTP invalido"
      | otherwise -> issueToken user
  where
    issueToken user = do
      token <- liftIO $ createJWT (uId user)
      pure $ AuthResponse token user

createHandler :: AppStore -> Config -> Maybe Text -> CreateWalletRequest -> Handler CreateWalletResponse
createHandler store cfg mAuth req = do
  uid <- requireAuth mAuth
  gw  <- liftIO (generateWallet (cfgGenerateScript cfg)) >>= orServerError 500
  encKey <- liftIO $ encryptPrivateKey uid (gwPrivateKey gw)
  makeAndSave store uid (cwrLabel req) (cwrTags req) False gw (Just encKey)

importHandler :: AppStore -> Config -> Maybe Text -> ImportWalletRequest -> Handler CreateWalletResponse
importHandler store cfg mAuth req = do
  uid <- requireAuth mAuth
  gw  <- liftIO (importWallet (cfgImportScript cfg) (iwrMnemonic req)) >>= orServerError 400
  encKey <- liftIO $ encryptPrivateKey (iwrPassword req) (gwPrivateKey gw)
  makeAndSave store uid (iwrLabel req) (iwrTags req) False gw (Just encKey)

importWatchHandler :: AppStore -> Maybe Text -> ImportWatchOnlyRequest -> Handler Wallet
importWatchHandler store mAuth req = do
  uid <- requireAuth mAuth
  wid  <- liftIO $ T.pack . UUID.toString <$> nextRandom
  now  <- liftIO $ T.pack . formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" <$> getCurrentTime
  let wallet = Wallet wid uid (worLabel req) (worAddress req) now (worTags req) True
      stored = StoredWallet wallet Nothing
  liftIO $ storeSaveWallet store stored
  pure wallet

feeEstHandler :: Handler FeeEstimate
feeEstHandler = liftIO fetchFeeEstimate >>= orServerError 502

listHandler :: AppStore -> Maybe Text -> Handler [Wallet]
listHandler store mAuth = do
  uid <- requireAuth mAuth
  liftIO $ map swPublic <$> storeListWallets store uid

consolidatedHandler :: AppStore -> Maybe Text -> Handler ConsolidatedBalance
consolidatedHandler store mAuth = do
  uid <- requireAuth mAuth
  wallets <- liftIO $ storeListWallets store uid
  let addrs = map (wAddress . swPublic) wallets
      getBal addr = do
        result <- fetchBalance addr
        case result of
          Left err -> pure (Left err)
          Right b  -> pure (Right b)
  result <- liftIO $ fetchConsolidatedBalance getBal addrs
  case result of
    Right cb -> pure cb
    Left err -> throwError $ errFor 502 err

priceHandler :: Handler PriceResponse
priceHandler = do
  result <- liftIO fetchPrice
  case result of
    Right p  -> pure $ PriceResponse p
    Left err -> throwError $ errFor 502 err

balanceHandler :: AppStore -> Maybe Text -> Text -> Handler CombinedBalance
balanceHandler store mAuth wid = do
  uid <- requireAuth mAuth
  sw  <- requireWallet store uid wid
  let addr = wAddress (swPublic sw)
  balResult <- liftIO $ fetchBalance addr
  offChain  <- liftIO $ storeGetInternalBalance store uid wid
  case balResult of
    Left _ -> pure $ CombinedBalance 0 offChain offChain 0 (satsToBtc offChain) (satsToBtc offChain)
    Right br -> do
      let onChain = brConfirmedSats br
          total   = onChain + offChain
      pure $ CombinedBalance
        { cbOnChainSats  = onChain
        , cbOffChainSats = offChain
        , cbTotalSats    = total
        , cbOnChainBtc   = satsToBtc onChain
        , cbOffChainBtc  = satsToBtc offChain
        , cbCombinedBtc  = satsToBtc total
        }

txHandler :: AppStore -> Maybe Text -> Text -> Handler Value
txHandler store mAuth wid = do
  uid <- requireAuth mAuth
  sw  <- requireWallet store uid wid
  liftIO (fetchTransactions (wAddress (swPublic sw))) >>= orServerError 502

sendHandler :: AppStore -> Config -> Maybe Text -> Text -> SendRequest -> Handler SendResponse
sendHandler store cfg mAuth wid req = do
  uid <- requireAuth mAuth
  sw  <- requireWallet store uid wid
  when (wWatchOnly (swPublic sw)) $
    throwError $ errFor 400 "Carteira watch-only nao pode enviar"
  mUser <- liftIO $ storeFindUserById store uid
  case mUser of
    Nothing -> throwError err404
    Just user -> do
      case swEncryptedKey sw of
        Nothing -> throwError $ errFor 400 "Chave privada nao disponivel"
        Just encKey -> do
          mPk <- liftIO $ decryptPrivateKey (srPassword req) encKey
          case mPk of
            Nothing -> throwError $ errFor 401 "Senha incorreta para descriptografar"
            Just pk -> do
              when (uTotpEnabled user) $
                case srOtpCode req of
                  Nothing  -> throwError $ errFor 403 "Codigo OTP necessario"
                  Just code -> do
                    valid <- liftIO $ verifyTOTP (maybe "" id (uTotpSecret user)) code
                    unless valid $ throwError $ errFor 401 "Codigo OTP invalido"
              let addr = wAddress (swPublic sw)
              txHash <- liftIO (sendBitcoin (cfgSendScript cfg) pk addr (srRecipient req) (srAmountBtc req) (srFeeRateSatVbyte req))
                          >>= orServerError 400
              pure $ SendResponse txHash

updateTagsHandler :: AppStore -> Maybe Text -> Text -> TagUpdateRequest -> Handler Wallet
updateTagsHandler store mAuth wid req = do
  uid <- requireAuth mAuth
  _   <- requireWallet store uid wid
  ok <- liftIO $ storeUpdateWalletTags store wid (turTags req)
  if ok
    then do
      Just sw <- liftIO $ storeFindWallet store wid
      pure $ swPublic sw
    else throwError err404

deleteHandler :: AppStore -> Maybe Text -> Text -> Handler NoContent
deleteHandler store mAuth wid = do
  uid <- requireAuth mAuth
  _   <- requireWallet store uid wid
  removed <- liftIO $ storeDeleteWallet store wid
  if removed then pure NoContent else throwError err404

contactsHandler :: AppStore -> Text -> Maybe Text -> Server
  (    Get '[JSON] [Contact]
  :<|> ReqBody '[JSON] ContactRequest :> Post '[JSON] Contact
  :<|> Capture "contactId" Text :> DeleteNoContent
  )
contactsHandler store uid mAuth =
       listContactsH
  :<|> createContactH
  :<|> deleteContactH
  where
    listContactsH = do
      _ <- requireAuthFor uid mAuth
      liftIO $ storeListContacts store uid
    createContactH req = do
      _ <- requireAuthFor uid mAuth
      cid <- liftIO $ T.pack . UUID.toString <$> nextRandom
      let contact = Contact cid uid (crName req) (crAddress req)
      liftIO $ storeSaveContact store contact
      pure contact
    deleteContactH cid = do
      _ <- requireAuthFor uid mAuth
      removed <- liftIO $ storeDeleteContact store cid
      if removed then pure NoContent else throwError err404

notesHandler :: AppStore -> Text -> Maybe Text -> Server
  (    ReqBody '[JSON] NoteRequest :> Post '[JSON] TxNote
  :<|> Capture "noteId" Text :> DeleteNoContent
  )
notesHandler store uid mAuth =
       createNoteH
  :<|> deleteNoteH
  where
    createNoteH req = do
      _ <- requireAuthFor uid mAuth
      nid <- liftIO $ T.pack . UUID.toString <$> nextRandom
      let note = TxNote nid uid (nrTxId req) (nrContent req)
      liftIO $ storeSaveNote store note
      pure note
    deleteNoteH nid = do
      _ <- requireAuthFor uid mAuth
      removed <- liftIO $ storeDeleteNote store nid
      if removed then pure NoContent else throwError err404

totpSetupHandler :: AppStore -> Text -> Maybe Text -> Handler TotpSetupResponse
totpSetupHandler store uid mAuth = do
  _ <- requireAuthFor uid mAuth
  secret <- liftIO generateTOTPSecret
  mUser <- liftIO $ storeFindUserById store uid
  case mUser of
    Nothing -> throwError err404
    Just user -> do
      liftIO $ storeUpdateUser store user { uTotpSecret = Just secret }
      pure $ TotpSetupResponse secret (totpUri secret (uEmail user))

totpEnableHandler :: AppStore -> Text -> Maybe Text -> EnableTotpRequest -> Handler User
totpEnableHandler store uid mAuth req = do
  _ <- requireAuthFor uid mAuth
  mUser <- liftIO $ storeFindUserById store uid
  case mUser of
    Nothing -> throwError err404
    Just user -> do
      case uTotpSecret user of
        Nothing -> throwError $ errFor 400 "Configure o TOTP primeiro"
        Just secret -> do
          valid <- liftIO $ verifyTOTP secret (etrCode req)
          if valid
            then do
              let updated = user { uTotpEnabled = True }
              liftIO $ storeUpdateUser store updated
              pure updated
            else throwError $ errFor 401 "Codigo OTP invalido"

changePasswordHandler :: AppStore -> Text -> Maybe Text -> ChangePasswordRequest -> Handler User
changePasswordHandler store uid mAuth req = do
  _ <- requireAuthFor uid mAuth
  mUser <- liftIO $ storeFindUserById store uid
  case mUser of
    Nothing -> throwError err404
    Just user -> do
      unless (verifyPassword (cprCurrentPassword req) (uPasswordHash user)) $
        throwError $ errFor 401 "Senha atual incorreta"
      when (T.length (cprNewPassword req) < 6) $
        throwError $ errFor 400 "Nova senha deve ter pelo menos 6 caracteres"
      newHash <- liftIO $ hashPassword (cprNewPassword req)
      let updated = user { uPasswordHash = newHash }
      liftIO $ storeUpdateUser store updated
      pure updated

changeUsernameHandler :: AppStore -> Text -> Maybe Text -> ChangeUsernameRequest -> Handler User
changeUsernameHandler store uid mAuth req = do
  _ <- requireAuthFor uid mAuth
  mUser <- liftIO $ storeFindUserById store uid
  case mUser of
    Nothing -> throwError err404
    Just user -> do
      when (T.length (curUsername req) < 3) $
        throwError $ errFor 400 "Username deve ter pelo menos 3 caracteres"
      when (T.length (curUsername req) > 30) $
        throwError $ errFor 400 "Username deve ter no maximo 30 caracteres"
      let updated = user { uUsername = Just (curUsername req) }
      liftIO $ storeUpdateUser store updated
      pure updated

satsToBtc :: Integer -> Double
satsToBtc = (/ 1.0e8) . fromIntegral

transferHandler :: AppStore -> Maybe Text -> TransferRequest -> Handler TransferResponse
transferHandler store mAuth req = do
  fromUid <- requireAuth mAuth
  when (trAmountSats req <= 0) $ throwError $ errFor 400 "Valor deve ser positivo"
  mRecipient <- liftIO $ storeFindUserByEmail store (trRecipientEmail req)
  case mRecipient of
    Nothing -> throwError $ errFor 404 "Destinatario nao encontrado"
    Just toUser -> do
      when (uId toUser == fromUid) $ throwError $ errFor 400 "Nao pode enviar para si mesmo"
      fromUser <- liftIO (storeFindUserById store fromUid) >>= maybe (throwError err404) pure
      when (uTotpEnabled fromUser) $
        case trOtpCode req of
          Nothing  -> throwError $ errFor 403 "Codigo OTP necessario"
          Just code -> do
            valid <- liftIO $ verifyTOTP (maybe "" id (uTotpSecret fromUser)) code
            unless valid $ throwError $ errFor 401 "Codigo OTP invalido"
      fromWallets <- liftIO $ storeListWallets store fromUid
      let nonWatch = filter (not . wWatchOnly . swPublic) fromWallets
      found <- liftIO $ findWalletWithBalance store fromUid nonWatch (trAmountSats req)
      case found of
        Nothing -> throwError $ errFor 400 "Saldo off-chain insuficiente em todas as carteiras"
        Just (fromWid, currentBal) -> do
          let newFromBal = currentBal - trAmountSats req
          liftIO $ storeUpdateInternalBalance store fromUid fromWid newFromBal
          toWallets <- liftIO $ storeListWallets store (uId toUser)
          let toWid = case filter (not . wWatchOnly . swPublic) toWallets of
                (w:_) -> wId (swPublic w)
                []    -> T.empty
          if T.null toWid
            then throwError $ errFor 400 "Destinatario nao possui carteiras para receber"
            else do
              toBal <- liftIO $ storeGetInternalBalance store (uId toUser) toWid
              liftIO $ storeUpdateInternalBalance store (uId toUser) toWid (toBal + trAmountSats req)
              tid <- liftIO $ T.pack . UUID.toString <$> nextRandom
              liftIO $ storeSaveTransfer store tid fromUid (uId toUser) (trAmountSats req)
              pure $ TransferResponse
                { trsId         = tid
                , trsFromUser   = uEmail fromUser
                , trsToUser     = uEmail toUser
                , trsAmountSats = trAmountSats req
                , trsCreatedAt  = T.empty
                }

findWalletWithBalance :: AppStore -> Text -> [StoredWallet] -> Integer -> IO (Maybe (Text, Integer))
findWalletWithBalance _ _ [] _ = pure Nothing
findWalletWithBalance store uid (sw:rest) needed = do
  let wid = wId (swPublic sw)
  bal <- storeGetInternalBalance store uid wid
  if bal >= needed
    then pure $ Just (wid, bal)
    else findWalletWithBalance store uid rest needed

listTransfersHandler :: AppStore -> Maybe Text -> Handler [TransferResponse]
listTransfersHandler store mAuth = do
  uid <- requireAuth mAuth
  rows <- liftIO $ storeListTransfers store uid
  mapM (\(tid, fromUid, toUid, amt, cat) -> do
    fromUser <- liftIO $ storeFindUserById store fromUid
    toUser   <- liftIO $ storeFindUserById store toUid
    let fromEmail = maybe "unknown" uEmail fromUser
        toEmail   = maybe "unknown" uEmail toUser
    pure $ TransferResponse
      { trsId = tid
      , trsFromUser = fromEmail
      , trsToUser = toEmail
      , trsAmountSats = amt
      , trsCreatedAt = cat
      }) rows

requireAuth :: Maybe Text -> Handler Text
requireAuth Nothing       = throwError $ errFor 401 "Token de autenticacao necessario"
requireAuth (Just header) = do
  let token = T.drop 7 header
  result <- liftIO $ validateJWT token
  case result of
    Nothing  -> throwError $ errFor 401 "Token invalido ou expirado"
    Just uid -> pure uid

requireAuthFor :: Text -> Maybe Text -> Handler Text
requireAuthFor targetUid mAuth = do
  uid <- requireAuth mAuth
  if uid == targetUid then pure uid
  else throwError $ errFor 403 "Acesso negado"

requireWallet :: AppStore -> Text -> Text -> Handler StoredWallet
requireWallet store uid wid = do
  mw <- liftIO $ storeFindWallet store wid
  case mw of
    Nothing -> throwError err404
    Just sw
      | wUserId (swPublic sw) /= uid -> throwError $ errFor 403 "Acesso negado"
      | otherwise -> pure sw

orServerError :: Int -> Either String a -> Handler a
orServerError _   (Right v) = pure v
orServerError code (Left msg) = throwError (errFor code msg)

errFor :: Int -> String -> ServerError
errFor code msg = mkErr code (encode (object ["error" .= msg]))
  where
    mkErr 400 m = err400 { errBody = m }
    mkErr 401 m = err401 { errBody = m }
    mkErr 403 m = err403 { errBody = m }
    mkErr 404 m = err404 { errBody = m }
    mkErr 409 m = err409 { errBody = m }
    mkErr 502 m = err502 { errBody = m }
    mkErr _   m = err500 { errBody = m }

makeAndSave :: AppStore -> Text -> Text -> [Text] -> Bool -> GeneratedWallet -> Maybe Text -> Handler CreateWalletResponse
makeAndSave store uid label tags wo gw encKey = do
  wid <- liftIO $ T.pack . UUID.toString <$> nextRandom
  now <- liftIO $ T.pack . formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" <$> getCurrentTime
  let wallet = Wallet wid uid label (gwAddress gw) now tags wo
      stored = StoredWallet wallet encKey
  liftIO $ storeSaveWallet store stored
  pure $ CreateWalletResponse wallet (gwMnemonic gw)
