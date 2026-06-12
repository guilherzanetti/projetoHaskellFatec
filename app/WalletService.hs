-- | WalletService: all business logic — wallet generation, import, balance,
--   transaction history, fee estimation, and sending Bitcoin.
module WalletService
  ( generateWallet
  , importWallet
  , fetchBalance
  , fetchTransactions
  , fetchFeeEstimate
  , sendBitcoin
  ) where

import WalletTypes
import Data.Aeson (eitherDecode, encode, object, (.=), Value)
import qualified Data.ByteString.Lazy       as LBS
import qualified Data.ByteString.Lazy.Char8 as LBSC
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import System.Process (readProcess)
import Network.HTTP.Simple (parseRequest, httpLBS, getResponseBody, Response)
import Control.Exception (try, SomeException)

-- ---------------------------------------------------------------------------
-- Wallet generation (new wallet)
-- ---------------------------------------------------------------------------

generateWallet :: FilePath -> IO (Either String GeneratedWallet)
generateWallet scriptPath = runGeneratorScript scriptPath ""

-- ---------------------------------------------------------------------------
-- Wallet import (from existing BIP39 mnemonic)
-- ---------------------------------------------------------------------------

importWallet :: FilePath -> Text -> IO (Either String GeneratedWallet)
importWallet scriptPath mnemonic =
  runGeneratorScript scriptPath . LBSC.unpack . encode $
    object ["mnemonic" .= mnemonic]

-- ---------------------------------------------------------------------------
-- Balance (Blockstream Esplora)
-- ---------------------------------------------------------------------------

fetchBalance :: Text -> IO (Either String BalanceResponse)
fetchBalance address = do
  body <- httpGet $ "https://blockstream.info/api/address/" <> T.unpack address
  case body of
    Left  err  -> pure (Left err)
    Right body' ->
      case eitherDecode body' of
        Left  err                 -> pure . Left $ "Balance parse error: " <> err
        Right (BsResponse ch mem) ->
          let conf   = bsFunded ch  - bsSpent ch
              unconf = bsFunded mem - bsSpent mem
              toBtc  = (/ 1.0e8) . fromIntegral
          in  pure . Right $ BalanceResponse address conf unconf (toBtc conf) (toBtc unconf)

-- ---------------------------------------------------------------------------
-- Transaction history (raw Blockstream JSON proxied to frontend)
-- ---------------------------------------------------------------------------

fetchTransactions :: Text -> IO (Either String Value)
fetchTransactions address = do
  body <- httpGet $ "https://blockstream.info/api/address/" <> T.unpack address <> "/txs"
  case body of
    Left  err  -> pure (Left err)
    Right body' ->
      case eitherDecode body' of
        Left  err -> pure . Left $ "Transactions parse error: " <> err
        Right v   -> pure (Right v)

-- ---------------------------------------------------------------------------
-- Fee estimate (sat/vbyte for fast/normal/slow targets)
-- ---------------------------------------------------------------------------

fetchFeeEstimate :: IO (Either String FeeEstimate)
fetchFeeEstimate = do
  body <- httpGet "https://blockstream.info/api/fee-estimates"
  case body of
    Left  err  -> pure (Left err)
    Right body' ->
      case eitherDecode body' :: Either String (Map.Map T.Text Double) of
        Left  err -> pure . Left $ "Fee parse error: " <> err
        Right m   ->
          let get k = fromMaybe 10.0 (Map.lookup k m)
          in  pure . Right $ FeeEstimate (get "1") (get "6") (get "144")

-- ---------------------------------------------------------------------------
-- Send Bitcoin (Python script handles UTXO selection, signing, broadcast)
-- ---------------------------------------------------------------------------

sendBitcoin
  :: FilePath  -- path to send_transaction.py
  -> Text      -- sender private key (hex)
  -> Text      -- sender address (to look up UTXOs)
  -> Text      -- recipient address
  -> Double    -- amount in BTC
  -> Int       -- fee rate sat/vbyte
  -> IO (Either String Text)   -- Right txHash | Left errorMessage
sendBitcoin scriptPath pk senderAddr recipient amtBtc feeRate = do
  let inputJson = LBSC.unpack . encode $ object
        [ "privateKey"      .= pk
        , "senderAddress"   .= senderAddr
        , "recipient"       .= recipient
        , "amountBtc"       .= amtBtc
        , "feeRateSatVbyte" .= feeRate
        ]
  result <- try (readProcess "python" [scriptPath] inputJson) :: IO (Either SomeException String)
  case result of
    Left  err    -> pure . Left $ "Script error: " <> show err
    Right output ->
      case eitherDecode (LBSC.pack output) of
        Left  err -> pure . Left $ "Parse error: " <> err
        Right res ->
          case (ssrTxHash res, ssrError res) of
            (Just h, _) -> pure (Right h)
            (_, Just e) -> pure (Left (T.unpack e))
            _           -> pure . Left $ "Unexpected script output: " <> output

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

-- | Run a Python wallet-generator script with optional stdin, parse GeneratedWallet.
runGeneratorScript :: FilePath -> String -> IO (Either String GeneratedWallet)
runGeneratorScript scriptPath stdin_ = do
  result <- try (readProcess "python" [scriptPath] stdin_) :: IO (Either SomeException String)
  case result of
    Left  err    -> pure . Left $ "Script error: " <> show err
    Right output ->
      case eitherDecode (LBSC.pack output) of
        Left  err -> pure . Left $ "Parse error: " <> err <> "\nOutput: " <> output
        Right gw  -> pure (Right gw)

-- | Perform an HTTP GET and return the response body or an error string.
httpGet :: String -> IO (Either String LBS.ByteString)
httpGet url = do
  result <- try (parseRequest url >>= httpLBS) :: IO (Either SomeException (Response LBS.ByteString))
  case result of
    Left  err      -> pure . Left $ "Network error: " <> show err
    Right response -> pure . Right $ getResponseBody response
