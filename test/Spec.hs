module Main (main) where

import Test.Hspec
import qualified CryptoSpec
import qualified P2PSpec

main :: IO ()
main = hspec $ do
  describe "Crypto" CryptoSpec.spec
  describe "P2P" P2PSpec.spec
