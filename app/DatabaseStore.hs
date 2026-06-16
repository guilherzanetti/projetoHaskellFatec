module DatabaseStore
  ( newDatabaseStore
  ) where

import WalletStore (AppStore(..))
import WalletTypes
import UserTypes
import Data.Text (Text)
import qualified Data.Text as T
import qualified Database.PostgreSQL.Simple as PG
import Database.PostgreSQL.Simple (Only(..))
import qualified Data.ByteString.Char8 as BS8
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (formatTime, defaultTimeLocale)

-- ---------------------------------------------------------------------------
-- Public constructor
-- ---------------------------------------------------------------------------

newDatabaseStore :: String -> IO AppStore
newDatabaseStore connStr = do
  conn <- PG.connectPostgreSQL (BS8.pack connStr)
  pure AppStore
    { storeRegisterUser = \user -> do
        _ <- PG.execute conn
              "INSERT INTO users (id, email, username, password_hash, totp_secret, totp_enabled) \
              \VALUES (?, ?, ?, ?, ?, ?)"
              ( uId user
              , uEmail user
              , uUsername user
              , uPasswordHash user
              , uTotpSecret user
              , uTotpEnabled user
              )
        pure ()

    , storeFindUserByEmail = \email -> do
        rows <- PG.query conn
                  "SELECT id, email, username, password_hash, totp_secret, totp_enabled \
                  \FROM users WHERE email = ?"
                  (Only email)
        pure $ case rows of
          []    -> Nothing
          (r:_) -> Just (rowToUser r)

    , storeFindUserById = \uid -> do
        rows <- PG.query conn
                  "SELECT id, email, username, password_hash, totp_secret, totp_enabled \
                  \FROM users WHERE id = ?"
                  (Only uid)
        pure $ case rows of
          []    -> Nothing
          (r:_) -> Just (rowToUser r)

    , storeUpdateUser = \user -> do
        _ <- PG.execute conn
              "UPDATE users SET email = ?, username = ?, password_hash = ?, \
              \totp_secret = ?, totp_enabled = ? WHERE id = ?"
              ( uEmail user
              , uUsername user
              , uPasswordHash user
              , uTotpSecret user
              , uTotpEnabled user
              , uId user
              )
        pure ()

    , storeSaveWallet = \sw -> do
        let w       = swPublic sw
            tagsStr = T.intercalate "," (wTags w)
        _ <- PG.execute conn
              "INSERT INTO wallets (id, user_id, label, address, created_at, tags, watch_only, encrypted_key) \
              \VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
              ( wId w
              , wUserId w
              , wLabel w
              , wAddress w
              , wCreatedAt w
              , tagsStr
              , wWatchOnly w
              , swEncryptedKey sw
              )
        pure ()

    , storeListWallets = \uid -> do
        rows <- PG.query conn
                  "SELECT id, user_id, label, address, created_at, tags, watch_only, encrypted_key \
                  \FROM wallets WHERE user_id = ?"
                  (Only uid)
        pure $ map rowToStoredWallet rows

    , storeFindWallet = \wid -> do
        rows <- PG.query conn
                  "SELECT id, user_id, label, address, created_at, tags, watch_only, encrypted_key \
                  \FROM wallets WHERE id = ?"
                  (Only wid)
        pure $ case rows of
          []    -> Nothing
          (r:_) -> Just (rowToStoredWallet r)

    , storeDeleteWallet = \wid -> do
        n <- PG.execute conn "DELETE FROM wallets WHERE id = ?" (Only wid)
        pure (n > 0)

    , storeUpdateWalletTags = \wid tags -> do
        let tagsStr = T.intercalate "," tags
        n <- PG.execute conn "UPDATE wallets SET tags = ? WHERE id = ?" (tagsStr, wid)
        pure (n > 0)

    , storeSaveContact = \contact -> do
        _ <- PG.execute conn
              "INSERT INTO contacts (id, user_id, name, address) VALUES (?, ?, ?, ?)"
              (cId contact, cUserId contact, cName contact, cAddress contact)
        pure ()

    , storeListContacts = \uid -> do
        rows <- PG.query conn
                  "SELECT id, user_id, name, address FROM contacts WHERE user_id = ?"
                  (Only uid)
        pure $ map rowToContact rows

    , storeDeleteContact = \cid -> do
        n <- PG.execute conn "DELETE FROM contacts WHERE id = ?" (Only cid)
        pure (n > 0)

    , storeSaveNote = \note -> do
        _ <- PG.execute conn
              "INSERT INTO notes (id, user_id, tx_id, content) VALUES (?, ?, ?, ?)"
              (tnId note, tnUserId note, tnTxId note, tnContent note)
        pure ()

    , storeListNotes = \uid txid -> do
        rows <- PG.query conn
                  "SELECT id, user_id, tx_id, content FROM notes WHERE user_id = ? AND tx_id = ?"
                  (uid, txid)
        pure $ map rowToNote rows

    , storeDeleteNote = \nid -> do
        n <- PG.execute conn "DELETE FROM notes WHERE id = ?" (Only nid)
        pure (n > 0)

    , storeGetInternalBalance = \uid wid -> do
        rows <- PG.query conn
                  "SELECT balance_sats FROM internal_balances \
                  \WHERE user_id = ? AND wallet_id = ?"
                  (uid, wid)
        pure $ case rows of
          []           -> 0
          (Only b : _) -> b

    , storeUpdateInternalBalance = \uid wid newBalance -> do
        _ <- PG.execute conn
              "INSERT INTO internal_balances (wallet_id, user_id, balance_sats) \
              \VALUES (?, ?, ?) \
              \ON CONFLICT (wallet_id) DO UPDATE SET balance_sats = EXCLUDED.balance_sats"
              (wid, uid, newBalance)
        pure ()

    , storeSaveTransfer = \tid fromUid toUid amount -> do
        now <- getCurrentTime
        let nowText = T.pack $ formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" now
        _ <- PG.execute conn
              "INSERT INTO transfers (id, from_user_id, to_user_id, amount_sats, created_at) \
              \VALUES (?, ?, ?, ?, ?)"
              (tid, fromUid, toUid, amount, nowText)
        pure ()

    , storeListTransfers = \uid -> do
        rows <- PG.query conn
                  "SELECT id, from_user_id, to_user_id, amount_sats, created_at \
                  \FROM transfers WHERE from_user_id = ? OR to_user_id = ? \
                  \ORDER BY created_at DESC"
                  (uid, uid)
        pure $ map rowToTransfer rows
    }

-- ---------------------------------------------------------------------------
-- Row type aliases & conversion helpers
-- ---------------------------------------------------------------------------

type UserRow     = (Text, Text, Maybe Text, Text, Maybe Text, Bool)
type WalletRow   = (Text, Text, Text, Text, Text, Text, Bool, Maybe Text)
type ContactRow  = (Text, Text, Text, Text)
type NoteRow     = (Text, Text, Text, Text)
type TransferRow = (Text, Text, Text, Integer, Text)

rowToUser :: UserRow -> User
rowToUser (uid, em, un, ph, ts, te) = User uid em un ph ts te

rowToStoredWallet :: WalletRow -> StoredWallet
rowToStoredWallet (wid, uid, lbl, addr, cat, tags, wo, ek) =
  StoredWallet wallet ek
  where
    wallet = Wallet
      { wId        = wid
      , wUserId    = uid
      , wLabel     = lbl
      , wAddress   = addr
      , wCreatedAt = cat
      , wTags      = filter (not . T.null) (T.splitOn "," tags)
      , wWatchOnly = wo
      }

rowToContact :: ContactRow -> Contact
rowToContact (cid, cuid, nm, addr) = Contact cid cuid nm addr

rowToNote :: NoteRow -> TxNote
rowToNote (nid, nuid, ntx, nc) = TxNote nid nuid ntx nc

rowToTransfer :: TransferRow -> (Text, Text, Text, Integer, Text)
rowToTransfer = id

