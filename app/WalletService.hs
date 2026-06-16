module WalletService
  ( generateWallet
  , importWallet
  , fetchBalance
  , fetchTransactions
  , fetchFeeEstimate
  , sendBitcoin
  , fetchPrice
  , fetchConsolidatedBalance
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

generateWallet :: FilePath -> IO (Either String GeneratedWallet)
generateWallet scriptPath = runGeneratorScript scriptPath ""

importWallet :: FilePath -> Text -> IO (Either String GeneratedWallet)
importWallet scriptPath mnemonic =
  runGeneratorScript scriptPath . LBSC.unpack . encode $
    object ["mnemonic" .= mnemonic]

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

fetchTransactions :: Text -> IO (Either String Value)
fetchTransactions address = do
  body <- httpGet $ "https://blockstream.info/api/address/" <> T.unpack address <> "/txs"
  case body of
    Left  err  -> pure (Left err)
    Right body' ->
      case eitherDecode body' of
        Left  err -> pure . Left $ "Transactions parse error: " <> err
        Right v   -> pure (Right v)

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

sendBitcoin
  :: FilePath
  -> Text
  -> Text
  -> Text
  -> Double
  -> Int
  -> IO (Either String Text)
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

fetchPrice :: IO (Either String Double)
fetchPrice = do
  body <- httpGet "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=brl"
  case body of
    Left err  -> pure (Left err)
    Right body' ->
      case eitherDecode body' :: Either String (Map.Map T.Text (Map.Map T.Text Double)) of
        Left err -> pure . Left $ "Price parse error: " <> err
        Right m  -> case Map.lookup "bitcoin" m >>= Map.lookup "brl" of
          Nothing  -> pure . Left $ "Price not found"
          Just price -> pure (Right price)

fetchConsolidatedBalance :: (Text -> IO (Either String BalanceResponse)) -> [Text] -> IO (Either String ConsolidatedBalance)
fetchConsolidatedBalance getBal addresses = do
  results <- mapM getBal addresses
  let errs  = [e | Left e <- results]
      bals  = [b | Right b <- results]
  if not (null errs)
    then pure . Left $ T.unpack (T.intercalate "; " (map T.pack errs))
    else do
      let totalBtc = sum (map brConfirmedBtc bals)
      priceResult <- fetchPrice
      let totalBrl = case priceResult of
            Right p  -> totalBtc * p
            Left _   -> 0.0
      pure . Right $ ConsolidatedBalance totalBtc totalBrl (length bals)

runGeneratorScript :: FilePath -> String -> IO (Either String GeneratedWallet)
runGeneratorScript scriptPath stdin_ = do
  result <- try (readProcess "python" [scriptPath] stdin_) :: IO (Either SomeException String)
  case result of
    Left  err    -> pure . Left $ "Script error: " <> show err
    Right output ->
      case eitherDecode (LBSC.pack output) of
        Left  err -> pure . Left $ "Parse error: " <> err <> "\nOutput: " <> output
        Right gw  -> pure (Right gw)

httpGet :: String -> IO (Either String LBS.ByteString)
httpGet url = do
  result <- try (parseRequest url >>= httpLBS) :: IO (Either SomeException (Response LBS.ByteString))
  case result of
    Left  err      -> pure . Left $ "Network error: " <> show err
    Right response -> pure . Right $ getResponseBody response
