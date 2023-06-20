module Component.CreateContract where

import Prelude

import CardanoMultiplatformLib (bech32FromString, bech32ToString)
import CardanoMultiplatformLib as CardanoMultiplatformLib
import CardanoMultiplatformLib.Types (Bech32)
import Component.BodyLayout (BodyContent(..))
import Component.BodyLayout as BodyLayout
import Component.CreateContract.Machine as Machine
import Component.MarloweYaml (marloweYaml)
import Component.Types (MkComponentM, WalletInfo)
import Component.Widgets (link, spinner)
import Contrib.Polyform.Batteries.UrlEncoded (requiredV')
import Contrib.React.Basic.Hooks.UseMooreMachine (useMooreMachine)
import Contrib.ReactBootstrap.FormBuilder (booleanField) as FormBuilder
import Control.Monad.Maybe.Trans (MaybeT(..), runMaybeT)
import Control.Monad.Reader.Class (asks)
import Control.Promise (Promise)
import Control.Promise as Promise
import Data.Argonaut (decodeJson, encodeJson, parseJson, stringifyWithIndent)
import Data.Array as Array
import Data.Array.NonEmpty (NonEmptyArray)
import Data.Bifunctor (lmap)
import Data.BigInt.Argonaut (BigInt)
import Data.BigInt.Argonaut as BigInt
import Data.DateTime.Instant (Instant, instant, unInstant)
import Data.Either (Either(..))
import Data.FormURLEncoded.Query (FieldId(..), Query)
import Data.Int as Int
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe, isJust)
import Data.Monoid.Disj (Disj(..))
import Data.Newtype (un)
import Data.Nullable (Nullable)
import Data.Nullable as Nullable
import Data.String (Pattern(..), split, trim)
import Data.Time.Duration (Milliseconds(..), Seconds(..))
import Data.Traversable (for)
import Data.Tuple (snd)
import Data.Tuple.Nested (type (/\))
import Data.Validation.Semigroup (V(..))
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Effect.Class (liftEffect)
import Effect.Now (now)
import JS.Unsafe.Stringify (unsafeStringify)
import Language.Marlowe.Core.V1.Semantics.Types as V1
import Marlowe.Runtime.Web.Client (ClientError)
import Marlowe.Runtime.Web.Types (ContractEndpoint, Metadata(..), PostContractsError, RoleTokenConfig(..), RolesConfig(..), Tags(..))
import Partial.Unsafe (unsafeCrashWith)
import Polyform.Validator (liftFn)
import Polyform.Validator (liftFnEither, liftFnMMaybe) as Validator
import React.Basic (fragment) as DOOM
import React.Basic.DOM (css)
import React.Basic.DOM (div, div_, input, text) as DOOM
import React.Basic.DOM as R
import React.Basic.DOM.Simplified.Generated as DOM
import React.Basic.Events (handler_)
import React.Basic.Hooks (JSX, Ref, component, fragment, readRef, useRef, (/\))
import React.Basic.Hooks as React
import React.Basic.Hooks.UseForm (useForm)
import React.Basic.Hooks.UseForm as UseForm
import ReactBootstrap.FormBuilder (BootstrapForm, FormBuilder')
import ReactBootstrap.FormBuilder (evalBuilder', textArea, textInput) as FormBuilder
import Wallet as Wallet
import WalletContext (WalletContext(..))
import Web.DOM.Node (Node)
import Web.File.File (File)
import Web.File.FileList (FileList)
import Web.File.FileList as FileList
import Web.HTML.HTMLInputElement (HTMLInputElement)
import Web.HTML.HTMLInputElement as HTMLInputElement

type Props =
  { onDismiss :: Effect Unit
  , onSuccess :: ContractEndpoint -> Effect Unit
  , connectedWallet :: WalletInfo Wallet.Api
  }

newtype AutoRun = AutoRun Boolean

type Result = V1.Contract /\ Tags /\ AutoRun

contractFieldId = FieldId "contract-json"

mkContractForm :: (Maybe V1.Contract /\ AutoRun) -> BootstrapForm Effect Query Result
mkContractForm (possibleInitialContract /\ (AutoRun initialAutoRun)) = FormBuilder.evalBuilder' $ ado
  contract <- FormBuilder.textArea
    { missingError: "Please provide contract terms JSON value"
    , helpText: Just $ DOOM.div_
        [ DOOM.text "Basic JSON validation"
        ]
    , initial: case possibleInitialContract of
        Nothing -> ""
        Just initialContract -> stringifyWithIndent 2 $ encodeJson initialContract
    , label: Just $ DOOM.text "Contract JSON"
    , touched: isJust possibleInitialContract
    , validator: requiredV' $ Validator.liftFnEither \jsonString -> do
        json <- lmap (const $ [ "Invalid JSON" ]) $ parseJson jsonString
        lmap (Array.singleton <<< show) (decodeJson json)
    , rows: 15
    , name: Just contractFieldId
    }

  tags <- FormBuilder.textInput
    { helpText: Just $ DOOM.div_
        [ DOOM.text "Tags"
        ]
    , initial: ""
    , label: Just $ DOOM.text "Tags"
    , touched: false
    , validator: liftFn case _ of
        Nothing -> Tags mempty
        Just tags ->
          (Tags $ Map.singleton runLiteTag
             (Metadata $ Map.fromFoldableWithIndex
               $ map (encodeJson <<< trim) $ split (Pattern ",") tags))
    }

  autoRun <- AutoRun <$> do
    -- FIXME: This should be documented I left this as an example of more hard core lifting of validator
    -- let
    --   toAutoRun = liftBuilderM $ pure $ liftValidator $ liftFnM \value -> do
    --       let
    --         value' = AutoRun value
    --       -- onAutoRunChange value'
    --       pure value'
    FormBuilder.booleanField
      { label: DOOM.text "Auto run"
      , helpText: DOOM.text "Whether to run the contract creation process automatically"
      , initial: initialAutoRun
      }
  in
    contract /\ tags /\ autoRun

mkRolesConfigForm :: NonEmptyArray String -> CardanoMultiplatformLib.Lib -> BootstrapForm Effect Query RolesConfig
mkRolesConfigForm roleNames cardanoMultiplatformLib = FormBuilder.evalBuilder' $ Mint <<< Map.fromFoldable <$> for roleNames \roleName -> ado
  address <- FormBuilder.textInput
    { missingError: "Please provide an address for a role token"
    , helpText: Just $ DOOM.div_
        [ DOOM.text "Role token destination address"
        ]
    , initial: ""
    , label: Just $ DOOM.text roleName
    , touched: false
    , validator: requiredV' $ Validator.liftFnMMaybe (const $ pure [ "Invalid address" ]) \str -> do
       bech32FromString cardanoMultiplatformLib str
    }
  in (roleName /\ (RoleTokenSimple address))

type ClientError' = ClientError PostContractsError


foreign import _loadFile :: File -> Promise (Nullable String)

loadFile :: File -> Aff (Maybe String)
loadFile = map Nullable.toMaybe <<< Promise.toAff <<< _loadFile

hoistMaybe :: forall m a. Applicative m => Maybe a -> MaybeT m a
hoistMaybe = MaybeT <<< pure

mkLoadFileButtonComponent :: MkComponentM ({ onFileload :: Maybe String -> Effect Unit } -> JSX)
mkLoadFileButtonComponent =
  liftEffect $ component "LoadFileButton" \{ onFileload } -> React.do
    {- Working example in raw HTML:
      <script>
      const onfile = () => {
        const fr = new FileReader()
        fr.onload = e => {
          console.log("hey ho")
          console.log(e.target.result)
        }
        fr.readAsText(document.getElementById("yo").files[0])
      }
      </script>
      <input id="yo" type="file" onchange="onfile()" />
    -}
    ref :: Ref (Nullable Node) <- useRef Nullable.null

    let
      onChange :: Effect Unit
      onChange = map (fromMaybe unit) $ runMaybeT do
        node :: Node <- MaybeT $ Nullable.toMaybe <$> readRef ref
        inputElement :: HTMLInputElement <- hoistMaybe $ HTMLInputElement.fromNode node
        files :: FileList <- MaybeT $ HTMLInputElement.files inputElement
        file :: File <- hoistMaybe $ FileList.item 0 files
        liftEffect $ launchAff_ $ (liftEffect <<< onFileload) =<< loadFile file

    pure $ DOOM.input { type: "file", onChange: handler_ onChange, ref }


machineProps (AutoRun autoRun) connectedWallet cardanoMultiplatformLib runtime = do
  let
    env = { connectedWallet, cardanoMultiplatformLib, runtime }
  { initialState: Machine.initialState
  , step: Machine.step
  , driver: if autoRun
      then Machine.driver env
      else const Nothing
  , output: identity
  }

data CurrentRun
  = Automatic
  -- This boolean indicates whether we are actually performing the request
  -- at the moment. This is useful to avoid double clicking and show throbber
  | Manual Boolean

addressInput :: CardanoMultiplatformLib.Lib -> String -> String -> Maybe FieldId -> FormBuilder' Effect Bech32
addressInput cardanoMultiplatformLib label initial name = do
  let
    props =
      { initial
      , label: Just $ DOOM.text label
      , name
      , validator: requiredV' $ Validator.liftFnMMaybe (const $ pure [ "Invalid address" ]) \str -> do
          bech32FromString cardanoMultiplatformLib str
      }
  FormBuilder.textInput props

type RoleProps =
  { onDismiss :: Effect Unit
  , onSuccess :: RolesConfig -> Effect Unit
  , connectedWallet :: WalletInfo Wallet.Api
  , roleNames :: NonEmptyArray String
  }

mkRoleTokensComponent :: MkComponentM (RoleProps -> JSX)
mkRoleTokensComponent = do
  cardanoMultiplatformLib <- asks _.cardanoMultiplatformLib
  liftEffect $ component "RoleTokensAssignment" \{ onDismiss , onSuccess, roleNames } -> React.do
    let
      form = mkRolesConfigForm roleNames cardanoMultiplatformLib

      onSubmit :: _ -> Effect Unit
      onSubmit = _.result >>> case _ of
        Just (V (Right roleAssignments) /\ _) -> onSuccess roleAssignments
        _ -> pure unit

    { formState, onSubmit: onSubmit', result } <- useForm
      { spec: form
      , onSubmit
      , validationDebounce: Seconds 0.5
      }

    pure $ do
      let
        fields = UseForm.renderForm form formState
        formBody = DOM.div { className: "form-group" } fields
        formActions = DOOM.fragment
          [ link
              { label: DOOM.text "Cancel"
              , onClick: onDismiss
              , showBorders: true
              , extraClassNames: "me-3"
              }
          , DOM.button
              do
                let
                  disabled = case result of
                    Just (V (Right _) /\ _) -> false
                    _ -> true
                { className: "btn btn-primary"
                , onClick: onSubmit'
                , disabled
                }
              [ R.text "Submit" ]
          ]
      BodyLayout.component
        { title: "Role token assignments"
        , description: R.text "Assign addresses to role tokens"
        , content: ContentWithFooter
          { body: DOM.div { className: "row" }
              [ DOM.div { className: "col-12" } [ formBody ]
              ]
          , footer: formActions
          }
        }

runLiteTag :: String
runLiteTag = "run-lite"

mkComponent :: MkComponentM (Props -> JSX)
mkComponent = do
  runtime <- asks _.runtime
  cardanoMultiplatformLib <- asks _.cardanoMultiplatformLib
  walletInfoCtx <- asks _.walletInfoCtx

  let
    initialAutoRun = AutoRun false

  roleTokenComponent <- mkRoleTokensComponent

  liftEffect $ component "CreateContract" \{ connectedWallet, onSuccess, onDismiss } -> React.do
    currentRun /\ setCurrentRun <- React.useState' Nothing
    { state: submissionState, applyAction, reset: resetStateMachine } <- do
      let
        props = machineProps initialAutoRun connectedWallet cardanoMultiplatformLib runtime
      useMooreMachine props

    form <- React.useMemo unit \_ -> mkContractForm (Nothing /\ initialAutoRun)

    let
      onSubmit :: _ -> Effect Unit
      onSubmit = _.result >>> case _ of
        Just (V (Right (contract /\ tags /\ autoRun)) /\ _) -> do
          let
            props = machineProps autoRun connectedWallet cardanoMultiplatformLib runtime
          applyAction' <- resetStateMachine (Just props)
          case autoRun of
            AutoRun true -> do
              setCurrentRun $ Just $ Automatic
            AutoRun false -> do
              setCurrentRun $ Just $ Manual false
          applyAction' $ Machine.TriggerSubmission contract tags
        _ -> pure unit

    { formState, onSubmit: onSubmit', result } <- useForm
      { spec: form
      , onSubmit
      , validationDebounce: Seconds 0.5
      }


    possibleWalletInfo <- React.useContext walletInfoCtx
    React.useEffect (_.changeAddress <<< un WalletContext <<< snd <$> possibleWalletInfo) $ do
      case possibleWalletInfo of
        Just (_ /\ (WalletContext { changeAddress: Just changeAddress })) -> do
          { multiChoiceTest: initialContract } <- liftEffect $ mkInitialContracts changeAddress
          case Map.lookup contractFieldId formState.fields of
            Just { touched, onChange } -> do
              when (not $ un Disj touched) do
                onChange [ stringifyWithIndent 2 $ encodeJson initialContract ]
            Nothing -> pure unit
        _ -> pure unit
      pure (pure unit)

    pure $ case submissionState of
      Machine.DefiningContract -> do
        let
          fields = UseForm.renderForm form formState
          formBody = DOM.div { className: "form-group" } fields
          formActions = DOOM.fragment
            [ link
                { label: DOOM.text "Cancel"
                , onClick: onDismiss
                , showBorders: true
                , extraClassNames: "me-3"
                }
            , DOM.button
                do
                  let
                    disabled = case result of
                      Just (V (Right _) /\ _) -> false
                      _ -> true
                  { className: "btn btn-primary"
                  , onClick: onSubmit'
                  , disabled
                  }
                [ R.text "Submit" ]
            ]
        BodyLayout.component
          { title: stateToTitle submissionState
          , description: stateToDetailedDescription submissionState
          , content: ContentWithFooter
            { body: formBody
            , footer: formActions
            }
          }

      Machine.DefiningRoleTokens { roleNames } -> do
        let
          onSuccess' :: RolesConfig -> Effect Unit
          onSuccess' rolesConfig =
            let action = Machine.DefineRoleTokensSucceeded rolesConfig
            in applyAction action

        BodyLayout.component
          { title: stateToTitle submissionState
          , description: stateToDetailedDescription submissionState
          , content: ContentWithFooter
            { body: roleTokenComponent { onDismiss: pure unit, onSuccess : onSuccess', connectedWallet , roleNames }
            , footer: DOOM.fragment
              [ link
                  { label: DOOM.text "Cancel"
                  , onClick: onDismiss
                  , showBorders: true
                  , extraClassNames: "me-3"
                  }
              ]
            }
          }
      Machine.ContractCreated { contract, createTxResponse } -> do
        let
          { links: { contract: contractEndpoint }} = createTxResponse
        BodyLayout.component
          { title: stateToTitle submissionState
          , description: stateToDetailedDescription submissionState
          , content: ContentWithFooter
            { body: marloweYaml contract
            , footer: DOOM.fragment
              [ DOM.button
                { className: "btn btn-primary"
                , onClick: handler_ (onSuccess contractEndpoint)
                }
                [ R.text "Ok" ]
              ]
            }
          }

      machineState -> do
        let
          machineEnv = { connectedWallet, cardanoMultiplatformLib, runtime }
          possibleRequest = currentRun >>= case _ of
            Manual _ -> do
              Machine.driver machineEnv machineState
            _ -> Nothing

          body = fragment
              [ do
                  let
                    StepIndex index = (machineStateToStepIndex machineState)
                  if index < machineStepsCardinality
                  then do
                    let
                      stepPercent = Int.ceil $ (Int.toNumber (index - 1)/ Int.toNumber (machineStepsCardinality - 1)) * 100.0
                      style = css { width: show stepPercent <> "%" }
                    DOM.div { className: "progress mb-3" } $ do
                        DOOM.div { className: "progress-bar", style, children: [] }
                  else mempty
              , case currentRun of
                  Just (Manual true) -> do
                    DOM.div { className: "d-flex justify-content-center" } $ spinner Nothing
                  _ -> DOOM.text "REQUEST / RESPONSE"
              ]

          formActions = case possibleRequest of
            Nothing -> mempty
            Just request -> DOOM.fragment
              [ link
                  { label: DOOM.text "Cancel"
                  , onClick: onDismiss
                  , showBorders: true
                  , extraClassNames: "me-3"
                  }
              , DOM.button
                  { className: "btn btn-primary"
                  , disabled: case currentRun of
                      Just (Manual b) -> b
                      _ -> false
                  , onClick: handler_ do
                    setCurrentRun (Just $ Manual true)
                    launchAff_ do
                      action <- request
                      liftEffect $ do
                        applyAction action
                        setCurrentRun (Just $ Manual false)
                  }
                  [ R.text "Run" ]
              ]
        BodyLayout.component
          { title: stateToTitle submissionState
          , description: stateToDetailedDescription submissionState
          , content: ContentWithFooter
            { body
            , footer: formActions
            }
          }

stateToTitle :: Machine.State -> String
stateToTitle state = case state of
  Machine.DefiningContract -> "Defining contract"
  Machine.DefiningRoleTokens {} -> "Defining role tokens"
  Machine.FetchingRequiredWalletContext {} -> "Fetching required wallet context"
  Machine.CreatingTx {} -> "Creating transaction"
  Machine.SigningTx {} -> "Signing transaction"
  Machine.SubmittigTx {} -> "Submitting transaction"
  Machine.ContractCreated {} -> "Contract created"

-- To display progress bar
newtype StepIndex = StepIndex Int

machineStepsCardinality :: Int
machineStepsCardinality = 7

machineStateToStepIndex :: Machine.State -> StepIndex
machineStateToStepIndex state = StepIndex $ case state of
  Machine.DefiningContract -> 1
  Machine.DefiningRoleTokens {} -> 2
  Machine.FetchingRequiredWalletContext {} -> 3
  Machine.CreatingTx {} -> 4
  Machine.SigningTx {} -> 5
  Machine.SubmittigTx {} -> 6
  Machine.ContractCreated {} -> 7

-- | We want to describe in details what kind of data we are gathering
-- | when we are performing a given transtition (state determines the next transition in our case)
-- | The output should be readable to the developer which should understand the whole flow.
-- | Let's use standard react-basic JSX functions like: DOM.div { className: "foo" } [ DOOM.text "bar" ]
stateToDetailedDescription :: Machine.State -> JSX
stateToDetailedDescription state = case state of
  Machine.DefiningContract -> DOOM.div_
    [ DOM.p {} $ DOOM.text "We are in the initial state, we are waiting for the user to trigger the contract creation process."
    , DOM.p {} $ DOOM.text "When we get the correct contract value (JSON) we gonna use it as a part of the request to the marlowe-runtime."
    ]
  Machine.DefiningRoleTokens {} -> DOOM.div_
    [ DOM.p {} $ DOOM.text "NOT IMPLEMENTED YET"
    ]
  Machine.FetchingRequiredWalletContext { errors: Nothing } -> DOOM.div_
    [ DOM.p {} $ DOOM.text "We are fetching the required wallet context."
    , DOM.p {} $ DOOM.text "marlowe-runtime requires information about wallet addresses so it can pick UTxO to pay for the initial transaction."
    , DOM.p {} $ DOOM.text $
        "To gain the address set from the wallet we use CIP-30 `getUsedAddresses` method and reencoding them from lower "
          <> "level cardano CBOR hex into Bech32 (`addr_test...`)."
    ]
  Machine.FetchingRequiredWalletContext { errors: Just error } -> DOOM.div_
    [ DOM.p {} $ DOOM.text "It seems that the provided wallet is lacking addresses or failed to execute the method:"
    , DOM.p {} $ DOOM.text error
    ]
  Machine.CreatingTx { errors: Nothing } -> DOOM.div_
    [ DOM.p {} $ DOOM.text "We are using the marlowe-runtime to create the initial transaction."
    ]
  Machine.CreatingTx { reqWalletContext, errors: Just error } -> DOOM.div_
    [ DOM.p {} $ DOOM.text "It seems that the marlowe-runtime failed to create the initial transaction:"
    , DOM.p {} $ DOOM.text error
    , DOM.p {} $ DOOM.text "The wallet context we used:"
    , DOM.p {} $ DOOM.text $ unsafeStringify reqWalletContext
    ]
  Machine.SigningTx { errors: Nothing } -> DOOM.div_
    [ DOM.p {} $ DOOM.text "We are signing the initial transaction."
    ]
  Machine.SigningTx { errors: Just error } -> DOOM.div_
    [ DOM.p {} $ DOOM.text "It seems that the wallet failed to sign the initial transaction:"
    , DOM.p {} $ DOOM.text error
    ]
  Machine.SubmittigTx { errors: Nothing } -> DOOM.div_
    [ DOM.p {} $ DOOM.text "We are submitting the initial transaction."
    ]
  Machine.SubmittigTx { errors: Just error } -> DOOM.div_
    [ DOM.p {} $ DOOM.text "It seems that the marlowe-runtime failed to submit the initial transaction:"
    , DOM.p {} $ DOOM.text error
    ]
  Machine.ContractCreated _ -> DOOM.div_
    [ DOM.p {} $ DOOM.text "The contract was created successfully."
    ]

-- | Let's use error information and other details of the state to describe the sitution.
-- | Let's use standard react-basic JSX functions like: DOM.div { className: "foo" } [ DOOM.text "bar" ]
stateToDescription :: Machine.State -> JSX
stateToDescription state = case state of
  Machine.DefiningContract -> DOOM.text "Please define your contract."
  Machine.DefiningRoleTokens { errors } -> case errors of
    Nothing -> DOOM.text "Defining role tokens."
    Just err -> DOOM.text $ "Defining role tokens failed: " <> err
  Machine.FetchingRequiredWalletContext { errors } -> case errors of
    Nothing -> DOOM.text "Fetching required wallet context."
    Just err -> DOOM.text $ "Fetching required wallet context failed: " <> err
  Machine.CreatingTx { errors } -> case errors of
    Nothing -> DOOM.text "Creating transaction."
    Just err -> DOOM.text $ "Creating transaction failed: " <> err
  Machine.SigningTx { errors } -> case errors of
    Nothing -> DOOM.text "Signing transaction."
    Just err -> DOOM.text $ "Signing transaction failed: " <> err
  Machine.SubmittigTx { errors } -> case errors of
    Nothing -> DOOM.text "Submitting transaction."
    Just err -> DOOM.text $ "Submitting transaction failed: " <> err
  Machine.ContractCreated {} -> DOOM.text "Contract created."

three :: BigInt
three = BigInt.fromInt 3
four :: BigInt
four = BigInt.fromInt 4

mkInitialContracts :: Bech32 -> Effect
  { -- brianContract :: V1.Contract
    multiChoiceTest :: V1.Contract
  }
mkInitialContracts bech32 = do
  nowMilliseconds <- unInstant <$> now
  let
    timeout = case instant (nowMilliseconds <> Milliseconds (Int.toNumber $ 20 * 60 * 1000)) of
      Just i -> i
      Nothing -> unsafeCrashWith "Invalid instant"

  pure
    { -- brianContract: brianContract bech32
      multiChoiceTest: mkMultiChoiceTest bech32 timeout
    }

brianContract :: Bech32 -> V1.Contract
brianContract bech32 = do
  let
    address = bech32ToString bech32
    timeout = BigInt.fromString "1684937880000"
    possibleContract = decodeJson $
      encodeJson { "when": [ { "then": { "when": [ { "then": { "when": [ { "then": "close", "case": { "notify_if": true } } ], "timeout_continuation": "close", "timeout": timeout }, "case": { "for_choice": { "choice_owner": { "address": address }, "choice_name": "Release" }, "choose_between": [ { "to": 1, "from": 1 } ] } } ], "timeout_continuation": "close", "timeout": timeout }, "case": { "party": { "address": address }, "of_token": { "token_name": "", "currency_symbol": "" }, "into_account": { "address": address }, "deposits": 10000000 } } ], "timeout_continuation": "close", "timeout": timeout }
  case possibleContract of
    Left err -> unsafeCrashWith $ "Failed to decode contract: " <> show err
    Right contract -> contract

mkMultiChoiceTest :: Bech32 -> Instant -> V1.Contract
mkMultiChoiceTest bech32 timeout = do
  let
    address = bech32ToString bech32
  V1.When
    [ V1.Case
        ( V1.Choice
            ( V1.ChoiceId "Everything is alright"
                (V1.Address address)
            )
            [ (V1.Bound zero zero)
            ]
        )
        V1.Close
    , V1.Case
        ( V1.Choice
            (V1.ChoiceId "Report problem" (V1.Address address))
            [ (V1.Bound one one) ]
        )
        V1.Close
    , V1.Case
        ( V1.Choice
            (V1.ChoiceId "Choice between 1-3" (V1.Address address))
            [ (V1.Bound one three) ]
        )
        V1.Close
    , V1.Case
        ( V1.Choice
            (V1.ChoiceId "Choice between 1-4" (V1.Address address))
            [ (V1.Bound one four) ]
        )
        V1.Close
    ]
    timeout
    V1.Close
