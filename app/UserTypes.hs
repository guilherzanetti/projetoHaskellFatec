module UserTypes where

import Data.Aeson
import Data.Text (Text)

data User = User
  { uId           :: !Text
  , uEmail        :: !Text
  , uUsername     :: !(Maybe Text)
  , uPasswordHash :: !Text
  , uTotpSecret   :: !(Maybe Text)
  , uTotpEnabled  :: !Bool
  } deriving (Show)

instance ToJSON User where
  toJSON u = object
    [ "id"          .= uId u
    , "email"       .= uEmail u
    , "username"    .= uUsername u
    , "totpEnabled" .= uTotpEnabled u
    ]

data RegisterRequest = RegisterRequest
  { rrEmail    :: !Text
  , rrUsername :: !(Maybe Text)
  , rrPassword :: !Text
  } deriving (Show)

instance FromJSON RegisterRequest where
  parseJSON = withObject "RegisterRequest" $ \v ->
    RegisterRequest <$> v .: "email" <*> v .:? "username" <*> v .: "password"

data LoginRequest = LoginRequest
  { lrEmail    :: !Text
  , lrPassword :: !Text
  , lrOtpCode  :: !(Maybe Text)
  } deriving (Show)

instance FromJSON LoginRequest where
  parseJSON = withObject "LoginRequest" $ \v ->
    LoginRequest <$> v .: "email" <*> v .: "password" <*> v .:? "otpCode"

data AuthResponse = AuthResponse
  { arToken :: !Text
  , arUser  :: !User
  } deriving (Show)

instance ToJSON AuthResponse where
  toJSON a = object [ "token" .= arToken a, "user" .= arUser a ]

data EnableTotpRequest = EnableTotpRequest
  { etrCode :: !Text
  } deriving (Show)

instance FromJSON EnableTotpRequest where
  parseJSON = withObject "EnableTotpRequest" $ \v ->
    EnableTotpRequest <$> v .: "code"

data TotpSetupResponse = TotpSetupResponse
  { tsrSecret :: !Text
  , tsrUri    :: !Text
  } deriving (Show)

instance ToJSON TotpSetupResponse where
  toJSON t = object [ "secret" .= tsrSecret t, "uri" .= tsrUri t ]

data ChangePasswordRequest = ChangePasswordRequest
  { cprCurrentPassword :: !Text
  , cprNewPassword     :: !Text
  } deriving (Show)

instance FromJSON ChangePasswordRequest where
  parseJSON = withObject "ChangePasswordRequest" $ \v ->
    ChangePasswordRequest <$> v .: "currentPassword" <*> v .: "newPassword"

data ChangeUsernameRequest = ChangeUsernameRequest
  { curUsername :: !Text
  } deriving (Show)

instance FromJSON ChangeUsernameRequest where
  parseJSON = withObject "ChangeUsernameRequest" $ \v ->
    ChangeUsernameRequest <$> v .: "username"
