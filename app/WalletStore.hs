module WalletStore
  ( AppStore(..)
  ) where

import WalletTypes
import UserTypes
import Data.Text (Text)

data AppStore = AppStore
  { storeRegisterUser     :: User -> IO ()
  , storeFindUserByEmail  :: Text -> IO (Maybe User)
  , storeFindUserById     :: Text -> IO (Maybe User)
  , storeUpdateUser       :: User -> IO ()
  , storeSaveWallet       :: StoredWallet -> IO ()
  , storeListWallets      :: Text -> IO [StoredWallet]
  , storeFindWallet       :: Text -> IO (Maybe StoredWallet)
  , storeDeleteWallet     :: Text -> IO Bool
  , storeUpdateWalletTags :: Text -> [Text] -> IO Bool
  , storeSaveContact      :: Contact -> IO ()
  , storeListContacts     :: Text -> IO [Contact]
  , storeDeleteContact    :: Text -> IO Bool
  , storeSaveNote         :: TxNote -> IO ()
  , storeListNotes        :: Text -> Text -> IO [TxNote]
  , storeDeleteNote       :: Text -> IO Bool
  , storeGetInternalBalance :: Text -> Text -> IO Integer
  , storeUpdateInternalBalance :: Text -> Text -> Integer -> IO ()
  , storeSaveTransfer     :: Text -> Text -> Text -> Integer -> IO ()
  , storeListTransfers    :: Text -> IO [(Text, Text, Text, Integer, Text)]
  }
