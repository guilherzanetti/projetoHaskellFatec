module P2PSpec (spec) where

import Test.Hspec
import qualified LocalStore
import WalletStore
import WalletTypes
import UserTypes
import Crypto
import qualified Data.Text as T

spec :: Spec
spec = beforeAll (setupTestStore) $ do
  describe "Internal balance operations" $ do
    it "starts with zero balance" $ \store -> do
      bal <- storeGetInternalBalance store "user1" "wallet1"
      bal `shouldBe` 0

    it "updates balance correctly" $ \store -> do
      storeUpdateInternalBalance store "user1" "wallet1" 100000
      bal <- storeGetInternalBalance store "user1" "wallet1"
      bal `shouldBe` 100000

    it "can set balance to zero" $ \store -> do
      storeUpdateInternalBalance store "user1" "wallet1" 0
      bal <- storeGetInternalBalance store "user1" "wallet1"
      bal `shouldBe` 0

    it "handles large values" $ \store -> do
      storeUpdateInternalBalance store "user1" "wallet1" 2100000000000000
      bal <- storeGetInternalBalance store "user1" "wallet1"
      bal `shouldBe` 2100000000000000

  describe "Transfer operations" $ do
    it "saves a transfer record" $ \store -> do
      storeSaveTransfer store "tx1" "user1" "user2" 50000
      transfers <- storeListTransfers store "user1"
      length transfers `shouldSatisfy` (>= 1)

    it "transfer appears in both users history" $ \store -> do
      storeSaveTransfer store "tx2" "user1" "user2" 75000
      transfers1 <- storeListTransfers store "user1"
      transfers2 <- storeListTransfers store "user2"
      length transfers1 `shouldSatisfy` (>= 1)
      length transfers2 `shouldSatisfy` (>= 1)

  describe "User registration and lookup" $ do
    it "registers and finds user by email" $ \store -> do
      ph <- hashPassword "testpass"
      let user = User "testuser1" "test@test.com" Nothing ph Nothing False
      storeRegisterUser store user
      found <- storeFindUserByEmail store "test@test.com"
      found `shouldSatisfy` isJust

    it "returns Nothing for non-existent email" $ \store -> do
      found <- storeFindUserByEmail store "nonexistent@test.com"
      found `shouldSatisfy` isNothing

    it "finds user by id" $ \store -> do
      found <- storeFindUserById store "testuser1"
      found `shouldSatisfy` isJust

  describe "Wallet operations" $ do
    it "saves and retrieves wallet" $ \store -> do
      let wallet = Wallet "w1" "user1" "Test" "1abc" "2024-01-01" ["tag1"] False
          stored = StoredWallet wallet (Just "encrypted")
      storeSaveWallet store stored
      found <- storeFindWallet store "w1"
      found `shouldSatisfy` isJust

    it "lists wallets by user" $ \store -> do
      wallets <- storeListWallets store "user1"
      length wallets `shouldSatisfy` (>= 1)

    it "deletes wallet" $ \store -> do
      deleted <- storeDeleteWallet store "w1"
      deleted `shouldBe` True
      found <- storeFindWallet store "w1"
      found `shouldSatisfy` isNothing

  describe "Contact operations" $ do
    it "saves and lists contacts" $ \store -> do
      let contact = Contact "c1" "user1" "Alice" "1AliceAddr"
      storeSaveContact store contact
      contacts <- storeListContacts store "user1"
      length contacts `shouldSatisfy` (>= 1)

    it "deletes contact" $ \store -> do
      deleted <- storeDeleteContact store "c1"
      deleted `shouldBe` True

  describe "Note operations" $ do
    it "saves and lists notes" $ \store -> do
      let note = TxNote "n1" "user1" "txhash123" "Minha nota"
      storeSaveNote store note
      notes <- storeListNotes store "user1" "txhash123"
      length notes `shouldBe` 1

    it "deletes note" $ \store -> do
      deleted <- storeDeleteNote store "n1"
      deleted `shouldBe` True

isJust :: Maybe a -> Bool
isJust (Just _) = True
isJust Nothing  = False

isNothing :: Maybe a -> Bool
isNothing (Just _) = False
isNothing Nothing  = True

setupTestStore :: IO AppStore
setupTestStore = LocalStore.newLocalStore "test_data.db"
