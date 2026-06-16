module Main where

import Servant
import Network.Wai.Handler.Warp (run)
import Data.Aeson (ToJSON)
import GHC.Generics (Generic)
import System.Environment (getEnv, lookupEnv)
import qualified LocalStore (newLocalStore)
import qualified DatabaseStore (newDatabaseStore)
import Handlers (AppAPI, Config(..), walletServer)
import WalletStore (AppStore)
import Data.Proxy (Proxy(..))

data PingResponse = PingResponse { message :: String, status :: String }
  deriving (Show, Generic, ToJSON)

data ServerInfo = ServerInfo { name :: String, ghc :: String, endpoints :: [String] }
  deriving (Show, Generic, ToJSON)

type CoreAPI =
  "api" :>
  (    "ping" :> Get '[JSON] PingResponse
  :<|> "info" :> Get '[JSON] ServerInfo
  )

coreServer :: Server CoreAPI
coreServer = pingH :<|> infoH
  where
    pingH = pure $ PingResponse "pong" "ok"
    infoH = pure $ ServerInfo
      { name = "Haskell Bitcoin Wallet API"
      , ghc  = "9.12.4"
      , endpoints =
          [ "POST   /api/auth/register"
          , "POST   /api/auth/login"
          , "POST   /api/wallets"
          , "POST   /api/wallets/import"
          , "POST   /api/wallets/import-watch"
          , "GET    /api/wallets/fee-estimate"
          , "GET    /api/wallets"
          , "GET    /api/wallets/consolidated"
          , "GET    /api/wallets/price"
          , "GET    /api/wallets/:id/balance"
          , "GET    /api/wallets/:id/transactions"
          , "POST   /api/wallets/:id/send"
          , "PUT    /api/wallets/:id/tags"
          , "DELETE /api/wallets/:id"
          , "POST   /api/transfers"
          , "GET    /api/transfers"
          , "GET    /api/users/:userId/contacts"
          , "POST   /api/users/:userId/contacts"
          , "DELETE /api/users/:userId/contacts/:contactId"
          , "POST   /api/users/:userId/notes"
          , "DELETE /api/users/:userId/notes/:noteId"
          , "POST   /api/users/:userId/totp/setup"
          , "POST   /api/users/:userId/totp/enable"
          ]
      }

type FullAPI = CoreAPI :<|> AppAPI

main :: IO ()
main = do
  mode <- lookupEnv "STORAGE_MODE"
  store <- case mode of
    Just "database" -> do
      connStr <- getEnv "DATABASE_URL"
      DatabaseStore.newDatabaseStore connStr
    _ -> do
      let dbPath = "local_data.db"
      LocalStore.newLocalStore dbPath

  let cfg = Config
        { cfgGenerateScript = "scripts/generate_wallet.py"
        , cfgImportScript   = "scripts/import_wallet.py"
        , cfgSendScript     = "scripts/send_transaction.py"
        }
      app = serve (Proxy :: Proxy FullAPI)
              (coreServer :<|> walletServer store cfg)

  putStrLn "=================================================="
  putStrLn "  Haskell Bitcoin Wallet API  v3.0"
  putStrLn "  http://localhost:8080"
  putStrLn $ "  Storage: " ++ maybe "database" id mode
  putStrLn "=================================================="
  run 8080 app
