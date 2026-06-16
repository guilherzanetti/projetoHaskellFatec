module DatabaseStore
  ( newDatabaseStore
  ) where

import WalletStore (AppStore(..))
import WalletTypes
import UserTypes
import Data.Text (Text)

newDatabaseStore :: String -> IO AppStore
newDatabaseStore _ = error "PostgreSQL support requires postgresql-simple. Set STORAGE_MODE=local to use SQLite instead."
