module DatabaseStore
  ( newDatabaseStore
  ) where

import qualified Data.ByteString.Char8 as BS
import WalletStore (WalletStore(..))
import WalletTypes (StoredWallet(..), Wallet(..))
import Database.PostgreSQL.Simple
import Data.Text (Text)
import qualified Data.Text as T

newDatabaseStore :: String -> IO WalletStore
newDatabaseStore connStr = do
  conn <- connectPostgreSQL (fromString connStr)
  pure WalletStore
    { storeSave = \sw -> do
        let w = swPublic sw
        execute conn
          "INSERT INTO wallets (id, label, address, created_at, private_key) VALUES (?, ?, ?, ?, ?)"
          ( wId w
          , wLabel w
          , wAddress w
          , wCreatedAt w
          , swPrivateKey sw
          )
        pure ()

    , storeList = do
        rows <- query_ conn
          "SELECT id, label, address, created_at, private_key FROM wallets"
        pure (map rowToStored rows)

    , storeFind = \wid -> do
        rows <- query conn
          "SELECT id, label, address, created_at, private_key FROM wallets WHERE id = ?"
          (Only wid)
        pure $ case rows of
          []    -> Nothing
          (r:_) -> Just (rowToStored r)

    , storeDelete = \wid -> do
        n <- execute conn
          "DELETE FROM wallets WHERE id = ?"
          (Only wid)
        pure (n > 0)
    }

rowToStored :: (Text, Text, Text, Text, Text) -> StoredWallet
rowToStored (wid, lbl, addr, cat, pk) =
  StoredWallet
    { swPublic     = Wallet { wId = wid, wLabel = lbl, wAddress = addr, wCreatedAt = cat }
    , swPrivateKey = pk
    }

fromString :: String -> BS.ByteString
fromString = BS.pack