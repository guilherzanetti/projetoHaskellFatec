module WalletTypes where

import Data.Aeson
import Data.Text (Text)

-- ---------------------------------------------------------------------------
-- Public wallet (safe to send to the client — no private key)
-- ---------------------------------------------------------------------------

data Wallet = Wallet
  { wId        :: !Text
  , wLabel     :: !Text
  , wAddress   :: !Text
  , wCreatedAt :: !Text
  } deriving (Show)

instance ToJSON Wallet where
  toJSON w = object
    [ "id"        .= wId w
    , "label"     .= wLabel w
    , "address"   .= wAddress w
    , "createdAt" .= wCreatedAt w
    ]

-- ---------------------------------------------------------------------------
-- Stored wallet (has private key — NEVER returned to the client)
-- ---------------------------------------------------------------------------

data StoredWallet = StoredWallet
  { swPublic     :: !Wallet
  , swPrivateKey :: !Text
  } deriving (Show)

instance ToJSON StoredWallet where
  toJSON sw = object
    [ "id"         .= wId (swPublic sw)
    , "label"      .= wLabel (swPublic sw)
    , "address"    .= wAddress (swPublic sw)
    , "createdAt"  .= wCreatedAt (swPublic sw)
    , "privateKey" .= swPrivateKey sw
    ]

instance FromJSON StoredWallet where
  parseJSON = withObject "StoredWallet" $ \v -> do
    wid  <- v .: "id"
    lbl  <- v .: "label"
    addr <- v .: "address"
    cAt  <- v .: "createdAt"
    pk   <- v .: "privateKey"
    pure $ StoredWallet (Wallet wid lbl addr cAt) pk

-- ---------------------------------------------------------------------------
-- API request / response types
-- ---------------------------------------------------------------------------

newtype CreateWalletRequest = CreateWalletRequest
  { cwrLabel :: Text
  } deriving (Show)

instance FromJSON CreateWalletRequest where
  parseJSON = withObject "CreateWalletRequest" $ \v ->
    CreateWalletRequest <$> v .: "label"

data CreateWalletResponse = CreateWalletResponse
  { crWallet   :: !Wallet
  , crMnemonic :: !Text       -- shown to the user exactly once
  } deriving (Show)

instance ToJSON CreateWalletResponse where
  toJSON r = object [ "wallet" .= crWallet r, "mnemonic" .= crMnemonic r ]

-- Import request
data ImportWalletRequest = ImportWalletRequest
  { iwrLabel    :: !Text
  , iwrMnemonic :: !Text
  } deriving (Show)

instance FromJSON ImportWalletRequest where
  parseJSON = withObject "ImportWalletRequest" $ \v ->
    ImportWalletRequest <$> v .: "label" <*> v .: "mnemonic"

-- Send request
data SendRequest = SendRequest
  { srRecipient       :: !Text
  , srAmountBtc       :: !Double
  , srFeeRateSatVbyte :: !Int
  } deriving (Show)

instance FromJSON SendRequest where
  parseJSON = withObject "SendRequest" $ \v ->
    SendRequest
      <$> v .: "recipient"
      <*> v .: "amountBtc"
      <*> v .: "feeRateSatVbyte"

newtype SendResponse = SendResponse { srTxHash :: Text } deriving (Show)

instance ToJSON SendResponse where
  toJSON r = object [ "txHash" .= srTxHash r ]

-- Fee estimate response
data FeeEstimate = FeeEstimate
  { feFast   :: !Double   -- sat/vbyte, ~1 block  (~10 min)
  , feNormal :: !Double   -- sat/vbyte, ~6 blocks (~1 hour)
  , feSlow   :: !Double   -- sat/vbyte, ~144 blocks (~1 day)
  } deriving (Show)

instance ToJSON FeeEstimate where
  toJSON fe = object
    [ "fast"   .= feFast fe
    , "normal" .= feNormal fe
    , "slow"   .= feSlow fe
    ]

-- ---------------------------------------------------------------------------
-- Balance response
-- ---------------------------------------------------------------------------

data BalanceResponse = BalanceResponse
  { brAddress         :: !Text
  , brConfirmedSats   :: !Integer
  , brUnconfirmedSats :: !Integer
  , brConfirmedBtc    :: !Double
  , brUnconfirmedBtc  :: !Double
  } deriving (Show)

instance ToJSON BalanceResponse where
  toJSON b = object
    [ "address"         .= brAddress b
    , "confirmedSats"   .= brConfirmedSats b
    , "unconfirmedSats" .= brUnconfirmedSats b
    , "confirmedBtc"    .= brConfirmedBtc b
    , "unconfirmedBtc"  .= brUnconfirmedBtc b
    ]

-- ---------------------------------------------------------------------------
-- Internal: Blockstream API parsing (balance)
-- ---------------------------------------------------------------------------

data BsStats = BsStats
  { bsFunded :: !Integer
  , bsSpent  :: !Integer
  } deriving (Show)

instance FromJSON BsStats where
  parseJSON = withObject "BsStats" $ \v ->
    BsStats <$> v .: "funded_txo_sum" <*> v .: "spent_txo_sum"

data BsResponse = BsResponse
  { bsChain   :: !BsStats
  , bsMempool :: !BsStats
  } deriving (Show)

instance FromJSON BsResponse where
  parseJSON = withObject "BsResponse" $ \v ->
    BsResponse <$> v .: "chain_stats" <*> v .: "mempool_stats"

-- ---------------------------------------------------------------------------
-- Internal: Python generator / import output
-- ---------------------------------------------------------------------------

data GeneratedWallet = GeneratedWallet
  { gwMnemonic   :: !Text
  , gwAddress    :: !Text
  , gwPrivateKey :: !Text
  } deriving (Show)

instance FromJSON GeneratedWallet where
  parseJSON = withObject "GeneratedWallet" $ \v ->
    GeneratedWallet
      <$> v .: "mnemonic"
      <*> v .: "address"
      <*> v .: "privateKey"

-- ---------------------------------------------------------------------------
-- Internal: Python send script output
-- ---------------------------------------------------------------------------

data SendScriptResult = SendScriptResult
  { ssrTxHash :: !(Maybe Text)
  , ssrError  :: !(Maybe Text)
  } deriving (Show)

instance FromJSON SendScriptResult where
  parseJSON = withObject "SendScriptResult" $ \v ->
    SendScriptResult <$> v .:? "txHash" <*> v .:? "error"
