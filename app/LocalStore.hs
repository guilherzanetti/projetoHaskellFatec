module LocalStore
  ( newLocalStore
  ) where

import WalletStore (AppStore(..))
import WalletTypes
import UserTypes
import Data.Text (Text)
import qualified Data.Text as T
import qualified Database.SQLite3 as SQL
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (formatTime, defaultTimeLocale)

newLocalStore :: FilePath -> IO AppStore
newLocalStore dbPath = do
  conn <- SQL.open (T.pack dbPath)
  execSql conn "CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL, username TEXT, password_hash TEXT NOT NULL, totp_secret TEXT, totp_enabled INTEGER NOT NULL DEFAULT 0)"
  execSql conn "CREATE TABLE IF NOT EXISTS wallets (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, label TEXT NOT NULL, address TEXT NOT NULL, created_at TEXT NOT NULL, tags TEXT NOT NULL DEFAULT '', watch_only INTEGER NOT NULL DEFAULT 0, encrypted_key TEXT)"
  execSql conn "CREATE TABLE IF NOT EXISTS contacts (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, name TEXT NOT NULL, address TEXT NOT NULL)"
  execSql conn "CREATE TABLE IF NOT EXISTS notes (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, tx_id TEXT NOT NULL, content TEXT NOT NULL)"
  execSql conn "CREATE TABLE IF NOT EXISTS internal_balances (wallet_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, balance_sats INTEGER NOT NULL DEFAULT 0)"
  execSql conn "CREATE TABLE IF NOT EXISTS transfers (id TEXT PRIMARY KEY, from_user_id TEXT NOT NULL, to_user_id TEXT NOT NULL, amount_sats INTEGER NOT NULL, created_at TEXT NOT NULL)"
  pure AppStore
    { storeRegisterUser = \user -> do
        stmt <- SQL.prepare conn "INSERT INTO users (id, email, username, password_hash, totp_secret, totp_enabled) VALUES (?, ?, ?, ?, ?, ?)"
        SQL.bind stmt [SQL.SQLText (uId user), SQL.SQLText (uEmail user), maybe SQL.SQLNull SQL.SQLText (uUsername user), SQL.SQLText (uPasswordHash user), maybe SQL.SQLNull SQL.SQLText (uTotpSecret user), SQL.SQLInteger (if uTotpEnabled user then 1 else 0)]
        _ <- SQL.step stmt
        SQL.finalize stmt

    , storeFindUserByEmail = \email -> do
        stmt <- SQL.prepare conn "SELECT id, email, username, password_hash, totp_secret, totp_enabled FROM users WHERE email = ?"
        SQL.bind stmt [SQL.SQLText email]
        rows <- collectUserRows stmt
        SQL.finalize stmt
        pure $ case rows of
          [] -> Nothing
          (u : _) -> Just u

    , storeFindUserById = \uid -> do
        stmt <- SQL.prepare conn "SELECT id, email, username, password_hash, totp_secret, totp_enabled FROM users WHERE id = ?"
        SQL.bind stmt [SQL.SQLText uid]
        rows <- collectUserRows stmt
        SQL.finalize stmt
        pure $ case rows of
          [] -> Nothing
          (u : _) -> Just u

    , storeUpdateUser = \user -> do
        stmt <- SQL.prepare conn "UPDATE users SET email = ?, username = ?, password_hash = ?, totp_secret = ?, totp_enabled = ? WHERE id = ?"
        SQL.bind stmt [SQL.SQLText (uEmail user), maybe SQL.SQLNull SQL.SQLText (uUsername user), SQL.SQLText (uPasswordHash user), maybe SQL.SQLNull SQL.SQLText (uTotpSecret user), SQL.SQLInteger (if uTotpEnabled user then 1 else 0), SQL.SQLText (uId user)]
        _ <- SQL.step stmt
        SQL.finalize stmt

    , storeSaveWallet = \sw -> do
        let w = swPublic sw
            tagsStr = T.intercalate "," (wTags w)
            ek = case swEncryptedKey sw of
                   Just t | T.null t -> SQL.SQLNull
                   Just t            -> SQL.SQLText t
                   Nothing           -> SQL.SQLNull
        stmt <- SQL.prepare conn "INSERT INTO wallets (id, user_id, label, address, created_at, tags, watch_only, encrypted_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        SQL.bind stmt [SQL.SQLText (wId w), SQL.SQLText (wUserId w), SQL.SQLText (wLabel w), SQL.SQLText (wAddress w), SQL.SQLText (wCreatedAt w), SQL.SQLText tagsStr, SQL.SQLInteger (if wWatchOnly w then 1 else 0), ek]
        _ <- SQL.step stmt
        SQL.finalize stmt

    , storeListWallets = \uid -> do
        stmt <- SQL.prepare conn "SELECT id, user_id, label, address, created_at, tags, watch_only, encrypted_key FROM wallets WHERE user_id = ?"
        SQL.bind stmt [SQL.SQLText uid]
        rows <- collectWalletRows stmt
        SQL.finalize stmt
        pure rows

    , storeFindWallet = \wid -> do
        stmt <- SQL.prepare conn "SELECT id, user_id, label, address, created_at, tags, watch_only, encrypted_key FROM wallets WHERE id = ?"
        SQL.bind stmt [SQL.SQLText wid]
        rows <- collectWalletRows stmt
        SQL.finalize stmt
        pure $ case rows of
          []    -> Nothing
          (r:_) -> Just r

    , storeDeleteWallet = \wid -> do
        stmt <- SQL.prepare conn "DELETE FROM wallets WHERE id = ?"
        SQL.bind stmt [SQL.SQLText wid]
        _ <- SQL.step stmt
        SQL.finalize stmt
        pure True

    , storeUpdateWalletTags = \wid tags -> do
        let tagsStr = T.intercalate "," tags
        stmt <- SQL.prepare conn "UPDATE wallets SET tags = ? WHERE id = ?"
        SQL.bind stmt [SQL.SQLText tagsStr, SQL.SQLText wid]
        _ <- SQL.step stmt
        SQL.finalize stmt
        pure True

    , storeSaveContact = \contact -> do
        stmt <- SQL.prepare conn "INSERT INTO contacts (id, user_id, name, address) VALUES (?, ?, ?, ?)"
        SQL.bind stmt [SQL.SQLText (cId contact), SQL.SQLText (cUserId contact), SQL.SQLText (cName contact), SQL.SQLText (cAddress contact)]
        _ <- SQL.step stmt
        SQL.finalize stmt

    , storeListContacts = \uid -> do
        stmt <- SQL.prepare conn "SELECT id, user_id, name, address FROM contacts WHERE user_id = ?"
        SQL.bind stmt [SQL.SQLText uid]
        rows <- collectContactRows stmt
        SQL.finalize stmt
        pure rows

    , storeDeleteContact = \cid -> do
        stmt <- SQL.prepare conn "DELETE FROM contacts WHERE id = ?"
        SQL.bind stmt [SQL.SQLText cid]
        _ <- SQL.step stmt
        SQL.finalize stmt
        pure True

    , storeSaveNote = \note -> do
        stmt <- SQL.prepare conn "INSERT INTO notes (id, user_id, tx_id, content) VALUES (?, ?, ?, ?)"
        SQL.bind stmt [SQL.SQLText (tnId note), SQL.SQLText (tnUserId note), SQL.SQLText (tnTxId note), SQL.SQLText (tnContent note)]
        _ <- SQL.step stmt
        SQL.finalize stmt

    , storeListNotes = \uid txid -> do
        stmt <- SQL.prepare conn "SELECT id, user_id, tx_id, content FROM notes WHERE user_id = ? AND tx_id = ?"
        SQL.bind stmt [SQL.SQLText uid, SQL.SQLText txid]
        rows <- collectNoteRows stmt
        SQL.finalize stmt
        pure rows

    , storeDeleteNote = \nid -> do
        stmt <- SQL.prepare conn "DELETE FROM notes WHERE id = ?"
        SQL.bind stmt [SQL.SQLText nid]
        _ <- SQL.step stmt
        SQL.finalize stmt
        pure True

    , storeGetInternalBalance = \uid wid -> do
        stmt <- SQL.prepare conn "SELECT balance_sats FROM internal_balances WHERE user_id = ? AND wallet_id = ?"
        SQL.bind stmt [SQL.SQLText uid, SQL.SQLText wid]
        result <- SQL.step stmt
        balance <- case result of
          SQL.Done -> pure 0
          SQL.Row  -> getInt stmt 0
        SQL.finalize stmt
        pure balance

    , storeUpdateInternalBalance = \uid wid newBalance -> do
        stmt <- SQL.prepare conn "INSERT OR REPLACE INTO internal_balances (wallet_id, user_id, balance_sats) VALUES (?, ?, ?)"
        SQL.bind stmt [SQL.SQLText wid, SQL.SQLText uid, SQL.SQLInteger (fromIntegral newBalance)]
        _ <- SQL.step stmt
        SQL.finalize stmt

    , storeSaveTransfer = \tid fromUid toUid amount -> do
        now <- getCurrentTime
        let nowText = T.pack $ formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" now
        stmt <- SQL.prepare conn "INSERT INTO transfers (id, from_user_id, to_user_id, amount_sats, created_at) VALUES (?, ?, ?, ?, ?)"
        SQL.bind stmt [SQL.SQLText tid, SQL.SQLText fromUid, SQL.SQLText toUid, SQL.SQLInteger (fromIntegral amount), SQL.SQLText nowText]
        _ <- SQL.step stmt
        SQL.finalize stmt

    , storeListTransfers = \uid -> do
        stmt <- SQL.prepare conn "SELECT id, from_user_id, to_user_id, amount_sats, created_at FROM transfers WHERE from_user_id = ? OR to_user_id = ? ORDER BY created_at DESC"
        SQL.bind stmt [SQL.SQLText uid, SQL.SQLText uid]
        rows <- collectTransferRows stmt
        SQL.finalize stmt
        pure rows
    }

execSql :: SQL.Database -> Text -> IO ()
execSql conn sql = do
  stmt <- SQL.prepare conn sql
  _ <- SQL.step stmt
  SQL.finalize stmt

getText :: SQL.Statement -> Int -> IO Text
getText stmt col = do
  val <- SQL.column stmt (fromIntegral col)
  case val of
    SQL.SQLText t -> pure t
    _             -> pure T.empty

getMaybeText :: SQL.Statement -> Int -> IO (Maybe Text)
getMaybeText stmt col = do
  val <- SQL.column stmt (fromIntegral col)
  case val of
    SQL.SQLNull   -> pure Nothing
    SQL.SQLText t -> pure (Just t)
    _             -> pure Nothing

getInt :: SQL.Statement -> Int -> IO Integer
getInt stmt col = do
  val <- SQL.column stmt (fromIntegral col)
  case val of
    SQL.SQLInteger i -> pure (fromIntegral i)
    _                -> pure 0

collectUserRows :: SQL.Statement -> IO [User]
collectUserRows stmt = do
  result <- SQL.step stmt
  case result of
    SQL.Done -> pure []
    SQL.Row -> do
      uid  <- getText stmt 0
      em   <- getText stmt 1
      un   <- getMaybeText stmt 2
      ph   <- getText stmt 3
      ts   <- getMaybeText stmt 4
      te   <- getInt stmt 5
      rest <- collectUserRows stmt
      pure $ User uid em un ph ts (te /= 0) : rest

collectWalletRows :: SQL.Statement -> IO [StoredWallet]
collectWalletRows stmt = do
  result <- SQL.step stmt
  case result of
    SQL.Done -> pure []
    SQL.Row -> do
      wid  <- getText stmt 0
      uid  <- getText stmt 1
      lbl  <- getText stmt 2
      addr <- getText stmt 3
      cat  <- getText stmt 4
      tags <- getText stmt 5
      wo   <- getInt stmt 6
      ek   <- getMaybeText stmt 7
      let wallet = Wallet
            { wId = wid
            , wUserId = uid
            , wLabel = lbl
            , wAddress = addr
            , wCreatedAt = cat
            , wTags = filter (not . T.null) (T.splitOn "," tags)
            , wWatchOnly = wo /= 0
            }
          stored = StoredWallet wallet ek
      rest <- collectWalletRows stmt
      pure $ stored : rest

collectContactRows :: SQL.Statement -> IO [Contact]
collectContactRows stmt = do
  result <- SQL.step stmt
  case result of
    SQL.Done -> pure []
    SQL.Row -> do
      cid  <- getText stmt 0
      cuid <- getText stmt 1
      nm   <- getText stmt 2
      addr <- getText stmt 3
      rest <- collectContactRows stmt
      pure $ Contact cid cuid nm addr : rest

collectNoteRows :: SQL.Statement -> IO [TxNote]
collectNoteRows stmt = do
  result <- SQL.step stmt
  case result of
    SQL.Done -> pure []
    SQL.Row -> do
      nid  <- getText stmt 0
      nuid <- getText stmt 1
      ntx  <- getText stmt 2
      nc   <- getText stmt 3
      rest <- collectNoteRows stmt
      pure $ TxNote nid nuid ntx nc : rest

collectTransferRows :: SQL.Statement -> IO [(Text, Text, Text, Integer, Text)]
collectTransferRows stmt = do
  result <- SQL.step stmt
  case result of
    SQL.Done -> pure []
    SQL.Row -> do
      tid    <- getText stmt 0
      fromU  <- getText stmt 1
      toU    <- getText stmt 2
      amount <- getInt stmt 3
      cat    <- getText stmt 4
      rest <- collectTransferRows stmt
      pure $ (tid, fromU, toU, amount, cat) : rest
