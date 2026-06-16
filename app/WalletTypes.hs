module WalletTypes where

import Data.Aeson
import Data.Text (Text)

data Wallet = Wallet
  { wId        :: !Text
  , wUserId    :: !Text
  , wLabel     :: !Text
  , wAddress   :: !Text
  , wCreatedAt :: !Text
  , wTags      :: ![Text]
  , wWatchOnly :: !Bool
  } deriving (Show)

instance ToJSON Wallet where
  toJSON w = object
    [ "id"        .= wId w
    , "userId"    .= wUserId w
    , "label"     .= wLabel w
    , "address"   .= wAddress w
    , "createdAt" .= wCreatedAt w
    , "tags"      .= wTags w
    , "watchOnly" .= wWatchOnly w
    ]

data StoredWallet = StoredWallet
  { swPublic       :: !Wallet
  , swEncryptedKey :: !(Maybe Text)
  } deriving (Show)

instance ToJSON StoredWallet where
  toJSON sw = object
    [ "id"           .= wId (swPublic sw)
    , "userId"       .= wUserId (swPublic sw)
    , "label"        .= wLabel (swPublic sw)
    , "address"      .= wAddress (swPublic sw)
    , "createdAt"    .= wCreatedAt (swPublic sw)
    , "tags"         .= wTags (swPublic sw)
    , "watchOnly"    .= wWatchOnly (swPublic sw)
    , "encryptedKey" .= swEncryptedKey sw
    ]

instance FromJSON StoredWallet where
  parseJSON = withObject "StoredWallet" $ \v -> do
    wid  <- v .: "id"
    uid  <- v .: "userId"
    lbl  <- v .: "label"
    addr <- v .: "address"
    cAt  <- v .: "createdAt"
    tags <- v .:? "tags" .!= []
    wo   <- v .:? "watchOnly" .!= False
    ek   <- v .:? "encryptedKey"
    pure $ StoredWallet
      (Wallet wid uid lbl addr cAt tags wo) ek

data CreateWalletRequest = CreateWalletRequest
  { cwrLabel :: !Text
  , cwrTags  :: ![Text]
  } deriving (Show)

instance FromJSON CreateWalletRequest where
  parseJSON = withObject "CreateWalletRequest" $ \v ->
    CreateWalletRequest <$> v .: "label" <*> v .:? "tags" .!= []

data CreateWalletResponse = CreateWalletResponse
  { crWallet   :: !Wallet
  , crMnemonic :: !Text
  } deriving (Show)

instance ToJSON CreateWalletResponse where
  toJSON r = object [ "wallet" .= crWallet r, "mnemonic" .= crMnemonic r ]

data ImportWalletRequest = ImportWalletRequest
  { iwrLabel    :: !Text
  , iwrMnemonic :: !Text
  , iwrPassword :: !Text
  , iwrTags     :: ![Text]
  } deriving (Show)

instance FromJSON ImportWalletRequest where
  parseJSON = withObject "ImportWalletRequest" $ \v ->
    ImportWalletRequest
      <$> v .: "label"
      <*> v .: "mnemonic"
      <*> v .: "password"
      <*> v .:? "tags" .!= []

data ImportWatchOnlyRequest = ImportWatchOnlyRequest
  { worLabel   :: !Text
  , worAddress :: !Text
  , worTags    :: ![Text]
  } deriving (Show)

instance FromJSON ImportWatchOnlyRequest where
  parseJSON = withObject "ImportWatchOnlyRequest" $ \v ->
    ImportWatchOnlyRequest
      <$> v .: "label"
      <*> v .: "address"
      <*> v .:? "tags" .!= []

data SendRequest = SendRequest
  { srRecipient       :: !Text
  , srAmountBtc       :: !Double
  , srFeeRateSatVbyte :: !Int
  , srPassword        :: !Text
  , srOtpCode         :: !(Maybe Text)
  } deriving (Show)

instance FromJSON SendRequest where
  parseJSON = withObject "SendRequest" $ \v ->
    SendRequest
      <$> v .: "recipient"
      <*> v .: "amountBtc"
      <*> v .: "feeRateSatVbyte"
      <*> v .: "password"
      <*> v .:? "otpCode"

newtype SendResponse = SendResponse { srTxHash :: Text } deriving (Show)

instance ToJSON SendResponse where
  toJSON r = object [ "txHash" .= srTxHash r ]

data FeeEstimate = FeeEstimate
  { feFast   :: !Double
  , feNormal :: !Double
  , feSlow   :: !Double
  } deriving (Show)

instance ToJSON FeeEstimate where
  toJSON fe = object
    [ "fast"   .= feFast fe
    , "normal" .= feNormal fe
    , "slow"   .= feSlow fe
    ]

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

data SendScriptResult = SendScriptResult
  { ssrTxHash :: !(Maybe Text)
  , ssrError  :: !(Maybe Text)
  } deriving (Show)

instance FromJSON SendScriptResult where
  parseJSON = withObject "SendScriptResult" $ \v ->
    SendScriptResult <$> v .:? "txHash" <*> v .:? "error"

data Contact = Contact
  { cId      :: !Text
  , cUserId  :: !Text
  , cName    :: !Text
  , cAddress :: !Text
  } deriving (Show)

instance ToJSON Contact where
  toJSON c = object
    [ "id"      .= cId c
    , "userId"  .= cUserId c
    , "name"    .= cName c
    , "address" .= cAddress c
    ]

instance FromJSON Contact where
  parseJSON = withObject "Contact" $ \v ->
    Contact <$> v .: "id" <*> v .: "userId" <*> v .: "name" <*> v .: "address"

data ContactRequest = ContactRequest
  { crName    :: !Text
  , crAddress :: !Text
  } deriving (Show)

instance FromJSON ContactRequest where
  parseJSON = withObject "ContactRequest" $ \v ->
    ContactRequest <$> v .: "name" <*> v .: "address"

data TxNote = TxNote
  { tnId      :: !Text
  , tnUserId  :: !Text
  , tnTxId    :: !Text
  , tnContent :: !Text
  } deriving (Show)

instance ToJSON TxNote where
  toJSON n = object
    [ "id"      .= tnId n
    , "userId"  .= tnUserId n
    , "txId"    .= tnTxId n
    , "content" .= tnContent n
    ]

instance FromJSON TxNote where
  parseJSON = withObject "TxNote" $ \v ->
    TxNote <$> v .: "id" <*> v .: "userId" <*> v .: "txId" <*> v .: "content"

data NoteRequest = NoteRequest
  { nrTxId    :: !Text
  , nrContent :: !Text
  } deriving (Show)

instance FromJSON NoteRequest where
  parseJSON = withObject "NoteRequest" $ \v ->
    NoteRequest <$> v .: "txId" <*> v .: "content"

data PriceResponse = PriceResponse
  { prBrl :: !Double
  } deriving (Show)

instance ToJSON PriceResponse where
  toJSON p = object [ "brl" .= prBrl p ]

data ConsolidatedBalance = ConsolidatedBalance
  { cbTotalBtc :: !Double
  , cbTotalBrl :: !Double
  , cbWallets  :: !Int
  } deriving (Show)

instance ToJSON ConsolidatedBalance where
  toJSON cb = object
    [ "totalBtc" .= cbTotalBtc cb
    , "totalBrl" .= cbTotalBrl cb
    , "wallets"  .= cbWallets cb
    ]

-- P2P Off-Chain Transfers

data TransferRequest = TransferRequest
  { trRecipientEmail :: !Text
  , trAmountSats     :: !Integer
  , trPassword       :: !Text
  , trOtpCode        :: !(Maybe Text)
  } deriving (Show)

instance FromJSON TransferRequest where
  parseJSON = withObject "TransferRequest" $ \v ->
    TransferRequest
      <$> v .: "recipientEmail"
      <*> v .: "amountSats"
      <*> v .: "password"
      <*> v .:? "otpCode"

data TransferResponse = TransferResponse
  { trsId        :: !Text
  , trsFromUser  :: !Text
  , trsToUser    :: !Text
  , trsAmountSats :: !Integer
  , trsCreatedAt :: !Text
  } deriving (Show)

instance ToJSON TransferResponse where
  toJSON tr = object
    [ "id"         .= trsId tr
    , "fromUser"   .= trsFromUser tr
    , "toUser"     .= trsToUser tr
    , "amountSats" .= trsAmountSats tr
    , "createdAt"  .= trsCreatedAt tr
    ]

data InternalBalance = InternalBalance
  { ibWalletId     :: !Text
  , ibUserId       :: !Text
  , ibBalanceSats  :: !Integer
  } deriving (Show)

instance ToJSON InternalBalance where
  toJSON ib = object
    [ "walletId"    .= ibWalletId ib
    , "userId"      .= ibUserId ib
    , "balanceSats" .= ibBalanceSats ib
    ]

data CombinedBalance = CombinedBalance
  { cbOnChainSats   :: !Integer
  , cbOffChainSats  :: !Integer
  , cbTotalSats     :: !Integer
  , cbOnChainBtc    :: !Double
  , cbOffChainBtc   :: !Double
  , cbCombinedBtc   :: !Double
  } deriving (Show)

instance ToJSON CombinedBalance where
  toJSON cb = object
    [ "onChainSats"  .= cbOnChainSats cb
    , "offChainSats" .= cbOffChainSats cb
    , "totalSats"    .= cbTotalSats cb
    , "onChainBtc"   .= cbOnChainBtc cb
    , "offChainBtc"  .= cbOffChainBtc cb
    , "totalBtc"     .= cbCombinedBtc cb
    ]
