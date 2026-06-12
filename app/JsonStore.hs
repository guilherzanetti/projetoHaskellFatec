-- | JsonStore: V1 storage backend — wallets persisted to a JSON file.
--
-- Uses a TVar for in-memory caching + thread-safe updates.
-- Writes are atomic at the Haskell level (single modifyTVar' + file write).
--
-- To migrate to PostgreSQL in V2:
--   1. Create DatabaseStore.hs implementing the same WalletStore record.
--   2. In Main.hs, replace `newJsonStore` with `newDatabaseStore connStr`.
--   3. Delete this file. Done.
module JsonStore
  ( newJsonStore
  ) where

import WalletStore (WalletStore(..))
import WalletTypes (StoredWallet(..), Wallet(..))
import Data.Aeson (encode, decode)
import qualified Data.ByteString.Lazy as LBS
import Control.Concurrent.STM (TVar, newTVarIO, readTVarIO, modifyTVar', writeTVar, atomically)
import System.Directory (doesFileExist)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Control.Monad (when)

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

data JsonRepo = JsonRepo
  { repoPath  :: !FilePath
  , repoCache :: !(TVar [StoredWallet])
  }

loadFromDisk :: FilePath -> IO [StoredWallet]
loadFromDisk path = do
  exists <- doesFileExist path
  if exists
    then fromMaybe [] . decode <$> LBS.readFile path
    else pure []

persistToDisk :: JsonRepo -> [StoredWallet] -> IO ()
persistToDisk repo ws = LBS.writeFile (repoPath repo) (encode ws)

findByid :: Text -> [StoredWallet] -> Maybe StoredWallet
findByid wid = foldr (\w acc -> if wId (swPublic w) == wid then Just w else acc) Nothing

removeById :: Text -> [StoredWallet] -> (Bool, [StoredWallet])
removeById wid = foldr step (False, [])
  where
    step w (found, acc)
      | wId (swPublic w) == wid = (True, acc)
      | otherwise               = (found, w : acc)

-- ---------------------------------------------------------------------------
-- Public constructor
-- ---------------------------------------------------------------------------

newJsonStore :: FilePath -> IO WalletStore
newJsonStore path = do
  initial <- loadFromDisk path
  cache   <- newTVarIO initial   -- TVar extracted directly, no record field warning
  let repo = JsonRepo { repoPath = path, repoCache = cache }

  pure WalletStore
    { storeSave = \sw -> do
        atomically $ modifyTVar' cache (sw :)
        ws <- readTVarIO cache
        persistToDisk repo ws

    , storeList = readTVarIO cache

    , storeFind = \wid -> findByid wid <$> readTVarIO cache

    , storeDelete = \wid -> do
        ws <- readTVarIO cache
        let (removed, remaining) = removeById wid ws
        when removed $ do
          atomically $ writeTVar cache remaining
          persistToDisk repo remaining
        pure removed
    }
