{-# LANGUAGE LambdaCase         #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE OverloadedStrings  #-}
{-# LANGUAGE TypeApplications   #-}
module Main(main) where

import qualified Cardano.Api.Shelley            as C
import           Cardano.Ledger.Alonzo.Scripts  (AlonzoScript (..),
                                                 transProtocolVersion,
                                                 validScript)
import           Cardano.Ledger.Language        (Language (..))
import           Control.Lens                   (_3, _4, view, (&), (.~))
import           Control.Monad                  (void)
import           Control.Monad.Except           (runExcept)
import           Convex.BuildTx                 (BuildTxT, assetValue,
                                                 execBuildTx', execBuildTxT,
                                                 mintPlutusV1, payToAddress,
                                                 payToAddressTxOut,
                                                 payToPlutusV1, payToPlutusV2,
                                                 payToPlutusV2Inline,
                                                 prependTxOut,
                                                 setMinAdaDepositAll,
                                                 spendPlutusV1, spendPlutusV2,
                                                 spendPlutusV2Ref)
import           Convex.Class                   (MonadBlockchain (..),
                                                 MonadMockchain (resolveDatumHash))
import qualified Convex.Lenses                  as L
import           Convex.MockChain.CoinSelection (balanceAndSubmit, paymentTo)
import qualified Convex.MockChain.Defaults      as Defaults
import           Convex.MockChain.Utils         (mockchainSucceeds)
import           Convex.Wallet                  (Wallet)
import qualified Convex.Wallet                  as Wallet
import qualified Convex.Wallet.MockWallet       as Wallet
import qualified Data.Map                       as Map
import qualified Data.Set                       as Set
import qualified PlutusLedgerApi.V2             as PV2
import qualified Scripts
import           Test.Tasty                     (TestTree, defaultMain,
                                                 testGroup)
import           Test.Tasty.HUnit               (Assertion, assertBool,
                                                 testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "unit tests"
  [ testGroup "payments"
    [ testCase "spending a public key output" spendPublicKeyOutput
    , testCase "making several payments" makeSeveralPayments
    ]
  , testGroup "scripts"
    [ testCase "paying to a plutus script" (mockchainSucceeds payToPlutusScript)
    , testCase "spending a plutus script output" (mockchainSucceeds (payToPlutusScript >>= spendPlutusScript))
    , testCase "spending a plutus script (V2) output" (mockchainSucceeds (payToPlutusV2Script >>= spendPlutusV2Script))
    , testCase "well-formed scripts" wellFormedScripts
    , testCase "creating a reference script output" (mockchainSucceeds $ putReferenceScript Wallet.w1)
    , testCase "using a reference script" (mockchainSucceeds (payToPlutusV2Script >>= spendPlutusScriptReference))
    , testCase "minting a token" (mockchainSucceeds mintingPlutus)
    , testCase "making payments with tokens" (mockchainSucceeds (mintingPlutus >>= spendTokens))
    ]
  , testGroup "mockchain"
    [ testCase "resolveDatumHash" (mockchainSucceeds checkResolveDatumHash)

    ]
  ]

spendPublicKeyOutput :: Assertion
spendPublicKeyOutput = mockchainSucceeds (Wallet.w2 `paymentTo` Wallet.w1)

wellFormedScripts :: Assertion
wellFormedScripts = do
  let protVer = Defaults.protVer Defaults.nodeParams
      s = Cardano.Ledger.Alonzo.Scripts.PlutusScript PlutusV2 Scripts.v2SpendingScriptSerialised
  either (fail . show) pure (runExcept (PV2.assertScriptWellFormed (transProtocolVersion protVer) Scripts.v2SpendingScriptSerialised))
  assertBool "validScript" (validScript protVer s)

makeSeveralPayments :: Assertion
makeSeveralPayments = mockchainSucceeds $ do
  void $ Wallet.w1 `paymentTo` Wallet.w2
  void $ Wallet.w2 `paymentTo` Wallet.w1
  void $ Wallet.w3 `paymentTo` Wallet.w1
  void $ Wallet.w1 `paymentTo` Wallet.w2

txInscript :: C.PlutusScript C.PlutusScriptV1
txInscript = C.examplePlutusScriptAlwaysSucceeds C.WitCtxTxIn

mintingScript :: C.PlutusScript C.PlutusScriptV1
mintingScript = C.examplePlutusScriptAlwaysSucceeds C.WitCtxMint

payToPlutusScript :: (MonadFail m, MonadMockchain m) => m C.TxIn
payToPlutusScript = do
  let tx = execBuildTx' (payToPlutusV1 Defaults.networkId txInscript () C.NoStakeAddress (C.lovelaceToValue 10_000_000))
  i <- C.getTxId . C.getTxBody <$> balanceAndSubmit Wallet.w1 tx
  pure (C.TxIn i (C.TxIx 0))

payToPlutusV2Script :: (MonadFail m, MonadMockchain m) => m C.TxIn
payToPlutusV2Script = do
  let tx = execBuildTx' (payToPlutusV2 Defaults.networkId Scripts.v2SpendingScript () C.NoStakeAddress (C.lovelaceToValue 10_000_000))
  i <- C.getTxId . C.getTxBody <$> balanceAndSubmit Wallet.w1 tx
  pure (C.TxIn i (C.TxIx 0))

spendPlutusScript :: (MonadFail m, MonadMockchain m) => C.TxIn -> m C.TxId
spendPlutusScript ref = do
  let tx = execBuildTx' (spendPlutusV1 ref txInscript () ())
  C.getTxId . C.getTxBody <$> balanceAndSubmit Wallet.w1 tx

spendPlutusV2Script :: (MonadFail m, MonadMockchain m) => C.TxIn -> m C.TxId
spendPlutusV2Script ref = do
  let tx = execBuildTx' (spendPlutusV2 ref Scripts.v2SpendingScript () ())
  C.getTxId . C.getTxBody <$> balanceAndSubmit Wallet.w1 tx

putReferenceScript :: (MonadFail m, MonadMockchain m) => Wallet -> m C.TxIn
putReferenceScript wallet = do
  let hsh = C.hashScript (C.PlutusScript C.PlutusScriptV2 Scripts.v2SpendingScript)
      addr = C.makeShelleyAddressInEra Defaults.networkId (C.PaymentCredentialByScript hsh) C.NoStakeAddress
      tx = execBuildTx' $
            payToPlutusV2Inline addr Scripts.v2SpendingScript (C.lovelaceToValue 10_000_000)
            >> setMinAdaDepositAll Defaults.bundledProtocolParameters
  txId <- C.getTxId . C.getTxBody <$> balanceAndSubmit wallet tx
  let outRef = C.TxIn txId (C.TxIx 0)
  C.UTxO utxo <- utxoByTxIn (Set.singleton outRef)
  case Map.lookup outRef utxo of
    Nothing  -> fail "Utxo not found"
    Just out -> case view (L._TxOut . _4) out of
      C.ReferenceScript{} -> pure ()
      _                   -> fail "No reference script found"
  pure outRef

spendPlutusScriptReference :: (MonadFail m, MonadMockchain m) =>  C.TxIn -> m C.TxId
spendPlutusScriptReference txIn = do
  refTxIn <- putReferenceScript Wallet.w1
  let tx = execBuildTx' (spendPlutusV2Ref txIn refTxIn (Just $ C.hashScript (C.PlutusScript C.PlutusScriptV2 Scripts.v2SpendingScript)) () ())
  C.getTxId . C.getTxBody <$> balanceAndSubmit Wallet.w1 tx

mintingPlutus :: (MonadFail m, MonadMockchain m) => m C.TxId
mintingPlutus = do
  void $ Wallet.w2 `paymentTo` Wallet.w1
  let tx = execBuildTx' (mintPlutusV1 mintingScript () "assetName" 100)
  C.getTxId . C.getTxBody <$> balanceAndSubmit Wallet.w1 tx

spendTokens :: (MonadFail m, MonadMockchain m) => C.TxId -> m C.TxId
spendTokens _ = do
  _ <- nativeAssetPaymentTo 49 Wallet.w1 Wallet.w2
  _ <- nativeAssetPaymentTo 51 Wallet.w1 Wallet.w2
  _ <- nativeAssetPaymentTo 100 Wallet.w2 Wallet.w3
  nativeAssetPaymentTo 99 Wallet.w3 Wallet.w1

nativeAssetPaymentTo :: (MonadMockchain m, MonadFail m) => C.Quantity -> Wallet -> Wallet -> m C.TxId
nativeAssetPaymentTo q wFrom wTo = do
  let vl = assetValue (C.hashScript $ C.PlutusScript C.PlutusScriptV1 mintingScript) "assetName" q
      tx = execBuildTx' $
            payToAddress (Wallet.addressInEra Defaults.networkId wTo) vl
            >> setMinAdaDepositAll Defaults.bundledProtocolParameters
  -- create a public key output for the sender to make
  -- sure that the sender has enough Ada in ada-only inputs
  void $ wTo `paymentTo` wFrom
  C.getTxId . C.getTxBody <$> balanceAndSubmit wFrom tx

checkResolveDatumHash :: (MonadMockchain m, MonadFail m) => m ()
checkResolveDatumHash = do
  let addr = Wallet.addressInEra Defaults.networkId Wallet.w1
      assertDatumPresent vl = resolveDatumHash (C.hashScriptDataBytes vl) >>= \case
        Nothing -> fail "Expected datum"
        Just x
          | x == C.getScriptData vl -> pure ()
          | otherwise -> fail $ "Expected " <> show (C.getScriptData vl) <> ", found " <> show x


  -- 1. resolve an inline datum
  let datum1 = C.unsafeHashableScriptData  (C.ScriptDataConstructor 5 [])
      dat = C.TxOutDatumInline C.ReferenceTxInsScriptsInlineDatumsInBabbageEra datum1
      txOut = payToAddressTxOut addr mempty
                & L._TxOut . _3 .~ dat

  _ <- execBuildTxWallet Wallet.w1 (prependTxOut txOut)

  assertDatumPresent datum1

  -- 2. resolve a datum that was provided as a "TxOutDatumInTx" (this is what 'payToPlutusV1' does)
  let d2 = (11 :: Integer, 12 :: Integer)
      datum2 = C.unsafeHashableScriptData $ C.fromPlutusData $ PV2.toData d2
  _ <- execBuildTxWallet Wallet.w1 (payToPlutusV1 Defaults.networkId txInscript d2 C.NoStakeAddress mempty)
  assertDatumPresent datum2

  -- 3. resolve a datum that was provided by a redeeming transaction
  let d3 = 500 :: Integer
      datum3 = C.unsafeHashableScriptData $ C.fromPlutusData $ PV2.toData d3
      txo =
        C.TxOut
          (C.makeShelleyAddressInEra Defaults.networkId (C.PaymentCredentialByScript (C.hashScript (C.PlutusScript C.PlutusScriptV1 txInscript))) C.NoStakeAddress)
          (C.TxOutValue C.MultiAssetInBabbageEra mempty)
          (C.TxOutDatumHash C.ScriptDataInBabbageEra (C.hashScriptDataBytes datum3))
          C.ReferenceScriptNone
  txId <- execBuildTxWallet Wallet.w1 (prependTxOut txo)
  _ <- execBuildTxWallet Wallet.w1 (spendPlutusV1 (C.TxIn txId (C.TxIx 0)) txInscript d3 ())
  assertDatumPresent datum3


{-| Build a transaction, then balance and sign it with the wallet, then
  submit it to the mockchain.
-}
execBuildTxWallet :: (MonadMockchain m, MonadFail m) => Wallet -> BuildTxT m a -> m C.TxId
execBuildTxWallet wallet action = do
  tx <- execBuildTxT (action >> setMinAdaDepositAll Defaults.bundledProtocolParameters)
  C.getTxId . C.getTxBody <$> balanceAndSubmit wallet (tx L.emptyTx)
