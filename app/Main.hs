module Main where

import Servant
import Network.Wai.Handler.Warp (run)
import Data.Aeson (ToJSON)
import GHC.Generics (Generic)

import JsonStore  (newJsonStore)
import Handlers   (WalletAPI, Config (..), walletServer)

-- ---------------------------------------------------------------------------
-- Original API (ping + info)
-- ---------------------------------------------------------------------------

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
          [ "GET    /api/ping"
          , "GET    /api/info"
          , "POST   /api/wallets                { label }"
          , "POST   /api/wallets/import         { label, mnemonic }"
          , "GET    /api/wallets/fee-estimate"
          , "GET    /api/wallets"
          , "GET    /api/wallets/:id/balance"
          , "GET    /api/wallets/:id/transactions"
          , "POST   /api/wallets/:id/send       { recipient, amountBtc, feeRateSatVbyte }"
          , "DELETE /api/wallets/:id"
          ]
      }

-- ---------------------------------------------------------------------------
-- Combined application
-- ---------------------------------------------------------------------------

type AppAPI = CoreAPI :<|> WalletAPI

main :: IO ()
main = do
  -- V1: JSON-file storage.
  -- To migrate to PostgreSQL in V2: replace newJsonStore with newDatabaseStore connStr.
  store <- newJsonStore "wallets.json"

  let cfg = Config
        { cfgGenerateScript = "scripts/generate_wallet.py"
        , cfgImportScript   = "scripts/import_wallet.py"
        , cfgSendScript     = "scripts/send_transaction.py"
        }
      app = serve (Proxy :: Proxy AppAPI)
              (coreServer :<|> walletServer store cfg)

  putStrLn "╔══════════════════════════════════════╗"
  putStrLn "║  Haskell Bitcoin Wallet API  v2.0    ║"
  putStrLn "║  http://localhost:8080               ║"
  putStrLn "╚══════════════════════════════════════╝"
  run 8080 app
