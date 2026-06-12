-- | WalletStore: repository abstraction via record-of-functions.
--
-- This is the ONLY file that needs to change between storage backends.
-- V1: JsonStore   — newJsonStore  "wallets.json"
-- V2: PostgresStore — newPostgresStore connectionString
--
-- Handlers and all other modules depend only on this type, never on a
-- concrete implementation.
module WalletStore where

import WalletTypes (StoredWallet)
import Data.Text (Text)

data WalletStore = WalletStore
  { storeSave   :: StoredWallet -> IO ()
  , storeList   :: IO [StoredWallet]
  , storeFind   :: Text -> IO (Maybe StoredWallet)
  , storeDelete :: Text -> IO Bool
  }
