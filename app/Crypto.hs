module Crypto
  ( encryptPrivateKey
  , decryptPrivateKey
  , hashPassword
  , verifyPassword
  , createJWT
  , validateJWT
  , generateTOTPSecret
  , verifyTOTP
  , totpUri
  , generateRandomBase64
  , generateRandomBytes
  ) where

import qualified Crypto.Cipher.AES as AES
import qualified Crypto.Cipher.Types as CT
import qualified Crypto.Error as CE
import qualified Crypto.KDF.Argon2 as Argon2
import qualified Crypto.MAC.HMAC as HMAC
import Crypto.Hash (SHA256(..))
import qualified Data.ByteArray as BA
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Char8 as BS8
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Word (Word64)
import System.Random (randomRIO)
import Data.Time.Clock (getCurrentTime, utctDayTime)
import Data.Bits (shiftR, (.&.))

appPepper :: BS.ByteString
appPepper = "HaskellWallet_v3_2024"

jwtSecret :: BS.ByteString
jwtSecret = "HaskellWallet_JWT_Secret_Change_In_Production_2024"

toBase64Url :: BS.ByteString -> BS.ByteString
toBase64Url = BS.map replace . B64.encode
  where
    replace 43 = 45
    replace 47 = 95
    replace c  = c

fromBase64Url :: BS.ByteString -> BS.ByteString
fromBase64Url bs =
  case B64.decode (BS.map replace bs) of
    Left _  -> BS.empty
    Right r -> r
  where
    replace 45 = 43
    replace 95 = 47
    replace c  = c

encryptPrivateKey :: T.Text -> T.Text -> IO T.Text
encryptPrivateKey keyText plainText = do
  ivBS <- generateRandomBytes 12
  let keyBytes   = deriveKey32 (TE.encodeUtf8 keyText)
      plainBytes = TE.encodeUtf8 plainText
  case CT.cipherInit keyBytes of
    CE.CryptoFailed _ -> pure T.empty
    CE.CryptoPassed (aes :: AES.AES256) ->
      case CT.aeadInit CT.AEAD_GCM aes ivBS of
        CE.CryptoFailed _ -> pure T.empty
        CE.CryptoPassed aead ->
          let (tag, encrypted) = CT.aeadSimpleEncrypt aead BS.empty plainBytes 16
              tagBS = BA.convert tag :: BS.ByteString
              combined = ivBS <> tagBS <> encrypted
          in  pure $ TE.decodeUtf8 (B64.encode combined)

decryptPrivateKey :: T.Text -> T.Text -> IO (Maybe T.Text)
decryptPrivateKey keyText encText = do
  let combined = B64.decodeLenient (TE.encodeUtf8 encText)
      keyBytes = deriveKey32 (TE.encodeUtf8 keyText)
  if BS.length combined < 28
    then pure Nothing
    else do
      let ivBS     = BS.take 12 combined
          tagBS    = BS.take 16 (BS.drop 12 combined)
          cipherBS = BS.drop 28 combined
      case CT.cipherInit keyBytes of
        CE.CryptoFailed _ -> pure Nothing
        CE.CryptoPassed (aes :: AES.AES256) ->
          case CT.aeadInit CT.AEAD_GCM aes ivBS of
            CE.CryptoFailed _ -> pure Nothing
            CE.CryptoPassed aead ->
              let tag = CT.AuthTag (BA.convert tagBS)
              in  case CT.aeadSimpleDecrypt aead BS.empty cipherBS tag of
                    Nothing  -> pure Nothing
                    Just dec -> pure $ Just (TE.decodeUtf8 dec)

deriveKey32 :: BS.ByteString -> BS.ByteString
deriveKey32 password =
  let salt = BS.take 16 (appPepper <> password)
      options = Argon2.Options
        { Argon2.iterations = 3
        , Argon2.memory = 65536
        , Argon2.parallelism = 1
        , Argon2.variant = Argon2.Argon2i
        , Argon2.version = Argon2.Version13
        }
  in  case Argon2.hash options password salt 32 of
        CE.CryptoFailed _ -> BS.replicate 32 0
        CE.CryptoPassed h -> h

hashPassword :: T.Text -> IO T.Text
hashPassword password = do
  salt <- generateRandomBytes 16
  let options = Argon2.Options
        { Argon2.iterations = 3
        , Argon2.memory = 65536
        , Argon2.parallelism = 1
        , Argon2.variant = Argon2.Argon2i
        , Argon2.version = Argon2.Version13
        }
      hash = case Argon2.hash options (TE.encodeUtf8 password) salt 32 of
        CE.CryptoFailed _ -> BS.replicate 32 0
        CE.CryptoPassed h -> h
      encoded = B64.encode salt <> BS8.pack ":" <> B64.encode hash
  pure $ TE.decodeUtf8 encoded

verifyPassword :: T.Text -> T.Text -> Bool
verifyPassword password storedHash =
  case BS8.split ':' (TE.encodeUtf8 storedHash) of
    [saltB64, hashB64] ->
      let options = Argon2.Options
            { Argon2.iterations = 3
            , Argon2.memory = 65536
            , Argon2.parallelism = 1
            , Argon2.variant = Argon2.Argon2i
            , Argon2.version = Argon2.Version13
            }
          salt = B64.decodeLenient saltB64
          computed = case Argon2.hash options (TE.encodeUtf8 password) salt 32 of
            CE.CryptoFailed _ -> BS.replicate 32 0
            CE.CryptoPassed h -> h
      in  B64.encode computed == hashB64
    _ -> False

createJWT :: T.Text -> IO T.Text
createJWT userId = do
  now <- getCurrentTime
  let epochSecs = truncate (utctDayTime now) :: Integer
      expSecs   = epochSecs + 86400
      header    = toBase64Url "{\"alg\":\"HS256\",\"typ\":\"JWT\"}"
      payload   = toBase64Url $ TE.encodeUtf8 $ T.concat
        [ "{\"sub\":\"", userId, "\",\"exp\":", T.pack (show expSecs), ",\"iat\":", T.pack (show epochSecs), "}" ]
      signingInput = header <> BS8.pack "." <> payload
      sig = toBase64Url $ hmacSha256 jwtSecret signingInput
  pure $ TE.decodeUtf8 $ signingInput <> BS8.pack "." <> sig

validateJWT :: T.Text -> IO (Maybe T.Text)
validateJWT token = do
  let parts = T.splitOn "." token
  case parts of
    [h, p, s] -> do
      let signingInput = TE.encodeUtf8 h <> BS8.pack "." <> TE.encodeUtf8 p
          expectedSig  = toBase64Url $ hmacSha256 jwtSecret signingInput
          actualSig    = TE.encodeUtf8 s
      if expectedSig /= actualSig
        then pure Nothing
        else do
          let payloadBytes = fromBase64Url (TE.encodeUtf8 p)
          now <- getCurrentTime
          let epochSecs = truncate (utctDayTime now) :: Integer
          case extractField "sub" payloadBytes of
            Nothing  -> pure Nothing
            Just sub ->
              case extractNumField "exp" payloadBytes of
                Nothing  -> pure Nothing
                Just exp' ->
                  if exp' > epochSecs
                    then pure $ Just (TE.decodeUtf8 sub)
                    else pure Nothing
    _ -> pure Nothing

extractField :: BS.ByteString -> BS.ByteString -> Maybe BS.ByteString
extractField field json =
  let needle = BS8.pack $ "\"" ++ T.unpack (TE.decodeUtf8 field) ++ "\":\""
  in  case BS8.breakSubstring needle json of
        (_, rest) | BS.null rest -> Nothing
                  | otherwise ->
                      let after = BS.drop (BS.length needle) rest
                      in  Just $ BS.takeWhile (/= 34) after

extractNumField :: BS.ByteString -> BS.ByteString -> Maybe Integer
extractNumField field json =
  let needle = BS8.pack $ "\"" ++ T.unpack (TE.decodeUtf8 field) ++ "\":"
  in  case BS8.breakSubstring needle json of
        (_, rest) | BS.null rest -> Nothing
                  | otherwise ->
                      let after = BS.drop (BS.length needle) rest
                          numStr = BS8.takeWhile (\c -> c >= '0' && c <= '9') after
                      in  case BS8.readInteger numStr of
                            Just (n, _) -> Just n
                            Nothing     -> Nothing

hmacSha256 :: BS.ByteString -> BS.ByteString -> BS.ByteString
hmacSha256 key msg =
  let ctx = HMAC.initialize key :: HMAC.Context SHA256
      ctx' = HMAC.update ctx msg
  in  BA.convert (HMAC.finalize ctx' :: HMAC.HMAC SHA256)

generateTOTPSecret :: IO T.Text
generateTOTPSecret = do
  bytes <- generateRandomBytes 20
  pure $ TE.decodeUtf8 (B64.encode bytes)

verifyTOTP :: T.Text -> T.Text -> IO Bool
verifyTOTP secret code = do
  now <- getCurrentTime
  let epochSecs = truncate (utctDayTime now) :: Integer
      timeStep  = epochSecs `div` 30
      secretBytes = B64.decodeLenient (TE.encodeUtf8 secret)
      check offset = generateTOTPCode secretBytes (timeStep + offset) == code
  pure $ any check [-1..1 :: Integer]

generateTOTPCode :: BS.ByteString -> Integer -> T.Text
generateTOTPCode secret timeStep =
  let counterBS = word64ToBS (fromIntegral timeStep)
      hmac = hmacSha256 secret counterBS
      offset = fromIntegral (BS.last hmac) .&. 0x0F :: Int
      binCode = fromIntegral (BS.index hmac offset .&. 0x7F) * 16777216
              + fromIntegral (BS.index hmac (offset + 1)) * 65536
              + fromIntegral (BS.index hmac (offset + 2)) * 256
              + fromIntegral (BS.index hmac (offset + 3))
      code = binCode `mod` 1000000 :: Int
  in  T.pack $ replicate (6 - length (show code)) '0' ++ show code

word64ToBS :: Word64 -> BS.ByteString
word64ToBS n = BS.pack
  [ fromIntegral (n `shiftR` 56)
  , fromIntegral (n `shiftR` 48)
  , fromIntegral (n `shiftR` 40)
  , fromIntegral (n `shiftR` 32)
  , fromIntegral (n `shiftR` 24)
  , fromIntegral (n `shiftR` 16)
  , fromIntegral (n `shiftR` 8)
  , fromIntegral n
  ]

totpUri :: T.Text -> T.Text -> T.Text
totpUri secret email =
  T.concat ["otpauth://totp/HaskellWallet:", email, "?secret=", secret, "&issuer=HaskellWallet&digits=6&period=30"]

generateRandomBase64 :: Int -> IO T.Text
generateRandomBase64 n = do
  bytes <- generateRandomBytes n
  pure $ TE.decodeUtf8 (B64.encode bytes)

generateRandomBytes :: Int -> IO BS.ByteString
generateRandomBytes n = BS.pack <$> mapM (\_ -> randomRIO (0, 255)) [1..n]
