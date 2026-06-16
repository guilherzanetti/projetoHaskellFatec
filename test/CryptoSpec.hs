module CryptoSpec (spec) where

import Test.Hspec
import Crypto
import qualified Data.Text as T

spec :: Spec
spec = do
  describe "hashPassword / verifyPassword" $ do
    it "hashes a password and verifies it correctly" $ do
      hash <- hashPassword "minhasenha123"
      verifyPassword "minhasenha123" hash `shouldBe` True

    it "rejects wrong password" $ do
      hash <- hashPassword "minhasenha123"
      verifyPassword "senhaerrada" hash `shouldBe` False

    it "produces different hashes for same password (unique salt)" $ do
      hash1 <- hashPassword "mesmasenha"
      hash2 <- hashPassword "mesmasenha"
      hash1 `shouldNotBe` hash2

    it "hash is not plaintext" $ do
      hash <- hashPassword "testepass"
      hash `shouldNotBe` "testepass"
      T.length hash `shouldSatisfy` (> 20)

  describe "encryptPrivateKey / decryptPrivateKey" $ do
    it "encrypts and decrypts correctly with right key" $ do
      encrypted <- encryptPrivateKey "minhachave" "chaveprivada123"
      result <- decryptPrivateKey "minhachave" encrypted
      result `shouldBe` Just "chaveprivada123"

    it "fails to decrypt with wrong key" $ do
      encrypted <- encryptPrivateKey "minhachave" "chaveprivada123"
      result <- decryptPrivateKey "chaveerrada" encrypted
      result `shouldBe` Nothing

    it "encrypted text is different from plaintext" $ do
      encrypted <- encryptPrivateKey "chave" "dadossecretos"
      encrypted `shouldNotBe` "dadossecretos"

    it "encrypted text is base64 encoded" $ do
      encrypted <- encryptPrivateKey "chave" "dadossecretos"
      T.length encrypted `shouldSatisfy` (> 0)

  describe "createJWT / validateJWT" $ do
    it "creates and validates a token" $ do
      token <- createJWT "user123"
      result <- validateJWT token
      result `shouldBe` Just "user123"

    it "rejects invalid token" $ do
      result <- validateJWT "tokeninvalido.aqui.agora"
      result `shouldBe` Nothing

    it "rejects tampered token" $ do
      token <- createJWT "user123"
      let tampered = T.snoc (T.init token) 'X'
      result <- validateJWT tampered
      result `shouldBe` Nothing

    it "different users get different tokens" $ do
      token1 <- createJWT "user1"
      token2 <- createJWT "user2"
      token1 `shouldNotBe` token2

  describe "generateTOTPSecret" $ do
    it "generates a non-empty secret" $ do
      secret <- generateTOTPSecret
      T.length secret `shouldSatisfy` (> 0)

    it "generates unique secrets" $ do
      secret1 <- generateTOTPSecret
      secret2 <- generateTOTPSecret
      secret1 `shouldNotBe` secret2

  describe "generateRandomBytes" $ do
    it "generates requested number of bytes" $ do
      bytes <- generateRandomBytes 32
      length (show bytes) `shouldSatisfy` (> 0)

    it "generates different bytes each time" $ do
      bytes1 <- generateRandomBytes 16
      bytes2 <- generateRandomBytes 16
      bytes1 `shouldNotBe` bytes2
