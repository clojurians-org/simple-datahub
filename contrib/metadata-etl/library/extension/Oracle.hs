{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TupleSections #-}

module Oracle where

import Data.Int
import Data.Char
import Data.Data
import Data.List
import Data.Functor
import Data.Foldable
import GHC.Generics
import Control.Applicative
import Control.Arrow
import Control.Monad
import Control.Monad.IO.Class
import Control.Monad.Trans (lift)


import Control.Lens ()

import Data.String.Conversions (cs)
import Data.ByteString.Lazy (ByteString)
import qualified Data.Text.Lazy as T
import qualified Data.Text.Lazy.IO as T
import qualified Data.Text.Lazy.Encoding as T

import qualified Data.Set as S
import qualified Text.Parsec as P
import qualified Text.Parsec.Pos as P
import Control.Monad.Reader (Reader)
import Control.Monad.State (runState, State, state, gets, put, modify)

import Database.Sql.Position
  (Position(..), Range(..), advance, advanceHorizontal, advanceVertical)
import Database.Sql.Type.Scope
  (RawNames(..))
import Database.Sql.Type.Names
  (QSchemaName(..))

import Data.Conduit (ConduitT, runConduitRes, runConduit, bracketP, (.|))
import qualified Data.Conduit.Combinators as C

data Oracle
deriving instance Data Oracle
dialectProxy :: Proxy Oracle
dialectProxy = Proxy

-- https://docs.oracle.com/cd/E11882_01/server.112/e41085/sqlqr01001.htm#SQLQR110
data OraclePlSqlStatement r a = OracleAlterClusterStatement (AlterCluster r a)
                              | OracleAlterDatabaseStatement (AlterDatabase r a)
                              | OracleAlterDatabaseLinkStatement (AlterDatabaseLink r a)
                              | OracleAlterDimensionStatement (AlterDimension r a)
                              | OracleAlterDiskgroupStatement (AlterDiskgroup r a)
                              | OracleAlterFlashbackArchiveStatement (AlterFlashbackArchive r a)
                              | OracleAlterFunctionStatement (AlterFunction r a)
                              | OracleAlterIndexStatement (AlterIndex r a)
                              | OracleAlterIndextypeStatement (AlterIndextype r a)
                              | OracleAlterJavaStatement (AlterJava r a)
                              | OracleAlterLibraryStatement (AlterLibrary r a)
                              | OracleAlterMaterializedViewStatement (AlterMaterializedView r a)
                              | OracleAlterMaterializedViewLogStatement (AlterMaterializedViewLog r a)
                              | OracleAlterOperatorStatement (AlterOperator r a)
                              | OracleAlterOutlineStatement (AlterOutline r a)
                              | OracleAlterPackageStatement (AlterPackage r a)
                              | OracleAlterProcedureStatement (AlterProcedure r a)
                              | OracleAlterProfileStatement (AlterProfile r a)
                              | OracleAlterResourceCostStatement (AlterResourceCost r a)
                              | OracleAlterRoleStatement (AlterRole r a)
                              | OracleAlterRollbackSegmentStatement (AlterRollbackSegment r a)
                              | OracleAlterSequenceStatement (AlterSequence r a)
                              | OracleAlterSessionStatement (AlterSession r a)
                              | OracleAlterSystemStatement (AlterSystem r a)
                              | OracleAlterTableStatement (AlterTable r a)
                              | OracleAlterTablespaceStatement (AlterTablespace r a)
                              | OracleAlterTriggerStatement (AlterTrigger r a)
                              | OracleAlterTypeStatement (AlterType r a)
                              | OracleAlterUserStatement (AlterUser r a)
                              | OracleAlterViewStatement (AlterView r a)
                              | OracleAnalyzeStatement (Analyze r a)
                              | OracleAssociateStatisticsStatement (AssociateStatistics r a)
                              | OracleAuditStatement (Audit r a)
                              | OracleCallStatement (Call r a)
                              | OracleCommentStatement (Comment r a)
                              | OracleCommitStatement (Commit r a)
                              | OracleCreateClusterStatement (CreateCluster r a)
                              | OracleCreateContextStatement (CreateContext r a)
                              | OracleCreateControlfileStatement (CreateControlfile r a)
                              | OracleCreateDatabaseStatement (CreateDatabase r a)
                              | OracleCreateDatabaseLinkStatement (CreateDatabaseLink r a)
                              | OracleCreateDimensionStatement (CreateDimension r a)
                              | OracleCreateDirectoryStatement (CreateDirectory r a)
                              | OracleCreateDiskgroupStatement (CreateDiskgroup r a)
                              | OracleCreateEditionStatement (CreateEdition r a)
                              | OracleCreateFlashbackArchiveStatement (CreateFlashbackArchive r a)
                              | OracleCreateFunctionStatement (CreateFunction r a)
                              | OracleCreateIndexStatement (CreateIndex r a)
                              | OracleCreateIndextypeStatement (CreateIndextype r a)
                              | OracleCreateJavaStatement (CreateJava r a)
                              | OracleCreateLibraryStatement (CreateLibrary r a)
                              | OracleCreateMaterializedViewStatement (CreateMaterializedView r a)
                              | OracleCreateMaterializedViewLogStatement (CreateMaterializedViewLog r a)
                              | OracleCreateOperatorStatement (CreateOperator r a)
                              | OracleCreateOutlineStatement (CreateOutline r a)
                              | OracleCreatePackageStatement (CreatePackage r a)
                              | OracleCreatePackageBodyStatement (CreatePackageBody r a)
                              | OracleCreatePfileStatement (CreatePfile r a)
                              | OracleCreateProcedureStatement (CreateProcedure r a)
                              | OracleCreateProfileStatement (CreateProfile r a)
                              | OracleCreateRestorePointStatement (CreateRestorePoint r a)
                              | OracleCreateRoleStatement (CreateRole r a)
                              | OracleCreateRollbackSegmentStatement (CreateRollbackSegment r a)
                              | OracleCreateSchemaStatement (CreateSchema r a)
                              | OracleCreateSequenceStatement (CreateSequence r a)
                              | OracleCreateSpfileStatement (CreateSpfile r a)
                              | OracleCreateSynonymStatement (CreateSynonym r a)
                              | OracleCreateTableStatement (CreateTable r a)
                              | OracleCreateTablespaceStatement (CreateTablespace r a)
                              | OracleCreateTriggerStatement (CreateTrigger r a)
                              | OracleCreateTypeStatement (CreateType r a)
                              | OracleCreateTypeBodyStatement (CreateTypeBody r a)
                              | OracleCreateUserStatement (CreateUser r a)
                              | OracleCreateViewStatement (CreateView r a)
                              | OracleDeleteStatement (Delete r a)
                              | OracleDisassociateStatisticsStatement (DisassociateStatistics r a)
                              | OracleDropClusterStatement (DropCluster r a)
                              | OracleDropContextStatement (DropContext r a)
                              | OracleDropDatabaseStatement (DropDatabase r a)
                              | OracleDropDatabaseLinkStatement (DropDatabaseLink r a)
                              | OracleDropDimensionStatement (DropDimension r a)
                              | OracleDropDirectoryStatement (DropDirectory r a)
                              | OracleDropDiskgroupStatement (DropDiskgroup r a)
                              | OracleDropEditionStatement (DropEdition r a)
                              | OracleDropFlashbackArchiveStatement (DropFlashbackArchive r a)
                              | OracleDropFunctionStatement (DropFunction r a)
                              | OracleDropIndexStatement (DropIndex r a)
                              | OracleDropIndextypeStatement (DropIndextype r a)
                              | OracleDropJavaStatement (DropJava r a)
                              | OracleDropLibraryStatement (DropLibrary r a)
                              | OracleDropMaterializedViewStatement (DropMaterializedView r a)
                              | OracleDropMaterializedViewLogStatement (DropMaterializedViewLog r a)
                              | OracleDropOperatorStatement (DropOperator r a)
                              | OracleDropOutlineStatement (DropOutline r a)
                              | OracleDropPackageStatement (DropPackage r a)
                              | OracleDropProcedureStatement (DropProcedure r a)
                              | OracleDropProfileStatement (DropProfile r a)
                              | OracleDropRestorePointStatement (DropRestorePoint r a)
                              | OracleDropRoleStatement (DropRole r a)
                              | OracleDropRollbackSegmentStatement (DropRollbackSegment r a)
                              | OracleDropSequenceStatement (DropSequence r a)
                              | OracleDropSynonymStatement (DropSynonym r a)
                              | OracleDropTableStatement (DropTable r a)
                              | OracleDropTablespaceStatement (DropTablespace r a)
                              | OracleDropTriggerStatement (DropTrigger r a)
                              | OracleDropTypeStatement (DropType r a)
                              | OracleDropTypeBodyStatement (DropTypeBody r a)
                              | OracleDropUserStatement (DropUser r a)
                              | OracleDropViewStatement (DropView r a)
                              | OracleExplainPlanStatement (ExplainPlan r a)
                              | OracleFlashbackDatabaseStatement (FlashbackDatabase r a)
                              | OracleFlashbackTableStatement (FlashbackTable r a)
                              | OracleGrantStatement (Grant r a)
                              | OracleInsertStatement (Insert r a)
                              | OracleLockTableStatement (LockTable r a)
                              | OracleMergeStatement (Merge r a)
                              | OracleNoauditStatement (Noaudit r a)
                              | OraclePurgeStatement (Purge r a)
                              | OracleRenameStatement (Rename r a)
                              | OracleRevokeStatement (Revoke r a)
                              | OracleRollbackStatement (Rollback r a)
                              | OracleSavepointStatement (Savepoint r a)
                              | OracleSelectStatement (Select r a)
                              | OracleSetConstraintStatement (SetConstraint r a)
                              | OracleSetRoleStatement (SetRole r a)
                              | OracleSetTransactionStatement (SetTransaction r a)
                              | OracleTruncateClusterStatement (TruncateCluster r a)
                              | OracleTruncateTableStatement (TruncateTable r a)
                              | OracleUpdateStatement (Update r a)
                              | OracleUnhandledStatement a

data AlterCluster r a
data AlterDatabase r a
data AlterDatabaseLink r a
data AlterDimension r a
data AlterDiskgroup r a
data AlterFlashbackArchive r a
data AlterFunction r a
data AlterIndex r a
data AlterIndextype r a
data AlterJava r a
data AlterLibrary r a
data AlterMaterializedView r a
data AlterMaterializedViewLog r a
data AlterOperator r a
data AlterOutline r a
data AlterPackage r a
data AlterProcedure r a
data AlterProfile r a
data AlterResourceCost r a
data AlterRole r a
data AlterRollbackSegment r a
data AlterSequence r a
data AlterSession r a
data AlterSystem r a
data AlterTable r a
data AlterTablespace r a
data AlterTrigger r a
data AlterType r a
data AlterUser r a
data AlterView r a
data Analyze r a
data AssociateStatistics r a
data Audit r a
data Call r a
data Comment r a
data Commit r a
data CreateCluster r a
data CreateContext r a
data CreateControlfile r a
data CreateDatabase r a
data CreateDatabaseLink r a
data CreateDimension r a
data CreateDirectory r a
data CreateDiskgroup r a
data CreateEdition r a
data CreateFlashbackArchive r a
data CreateFunction r a
data CreateIndex r a
data CreateIndextype r a
data CreateJava r a
data CreateLibrary r a
data CreateMaterializedView r a
data CreateMaterializedViewLog r a
data CreateOperator r a
data CreateOutline r a
data CreatePackage r a
data CreatePackageBody r a
data CreatePfile r a
data CreateProcedure r a = CreateProcedure
  { createProcedureInfo :: a
  , createProcedureOrReplace :: Maybe a
--   , createProcedureName :: QProcedureName 
  }
data CreateProfile r a
data CreateRestorePoint r a
data CreateRole r a
data CreateRollbackSegment r a
data CreateSchema r a
data CreateSequence r a
data CreateSpfile r a
data CreateSynonym r a
data CreateTable r a
data CreateTablespace r a
data CreateTrigger r a
data CreateType r a
data CreateTypeBody r a
data CreateUser r a
data CreateView r a
data Delete r a
data DisassociateStatistics r a
data DropCluster r a
data DropContext r a
data DropDatabase r a
data DropDatabaseLink r a
data DropDimension r a
data DropDirectory r a
data DropDiskgroup r a
data DropEdition r a
data DropFlashbackArchive r a
data DropFunction r a
data DropIndex r a
data DropIndextype r a
data DropJava r a
data DropLibrary r a
data DropMaterializedView r a
data DropMaterializedViewLog r a
data DropOperator r a
data DropOutline r a
data DropPackage r a
data DropProcedure r a
data DropProfile r a
data DropRestorePoint r a
data DropRole r a
data DropRollbackSegment r a
data DropSequence r a
data DropSynonym r a
data DropTable r a
data DropTablespace r a
data DropTrigger r a
data DropType r a
data DropTypeBody r a
data DropUser r a
data DropView r a
data ExplainPlan r a
data FlashbackDatabase r a
data FlashbackTable r a
data Grant r a
data Insert r a
data LockTable r a
data Merge r a
data Noaudit r a
data Purge r a
data Rename r a
data Revoke r a
data Rollback r a
data Savepoint r a
data Select r a
data SetConstraint r a
data SetRole r a
data SetTransaction r a
data TruncateCluster r a
data TruncateTable r a
data Update r a

data QProcedureName f a = QProcedureName
  { procedureNameInfo :: a
  , procedureNameSchema :: f (QSchemaName f a)
  , procedureNameName :: T.Text
  } deriving (Generic, Functor, Foldable, Traversable)
  
data Token = TokWord !Bool !T.Text
           | TokString !ByteString
           | TokNumber !T.Text
           | TokSymbol !T.Text
           | TokVariable !T.Text VariableName
           | TokError !String
           deriving (Show, Eq)

data VariableName = StaticName !T.Text
                  | DynamicName Token
                  deriving (Show, Eq)

type ScopeTableRef = T.Text
data ParserScope = ParserScope
    { selectTableAliases :: Maybe (S.Set ScopeTableRef) }
    deriving (Eq, Ord, Show)

type Parser = P.ParsecT [(Token, Position, Position)] Integer (Reader ParserScope)

tokenize :: T.Text -> [(Token, Position, Position)]
tokenize = go (Position 1 0 0)
  where
    go :: Position -> T.Text -> [(Token, Position, Position)]
    go _ "" = []
    go p t = case T.head t of
      c | isAlpha c || c == '_' || c == '"' ->
          case tokName p t of
            Left token -> [token]
            Right (name, quoted, rest, p') -> (TokWord quoted name, p, p') : go p' rest
      c | isDigit c ->
          let ((token, len), rest) = parseNumber t
              p' = advanceHorizontal len p
            in (token, p, p') : go p' rest
      '$' | "${" `T.isPrefixOf` t ->
          let ((token, len), rest) = parseVariable t
              p' = advanceHorizontal len p
            in (token, p, p') : go p' rest
      '`' ->
        case tokQuotedWord p t of
          Left p' -> [(TokError "end of input inside name", p, p')]
          Right (name, rest, p') -> (TokWord True name, p, p') : go p' rest
      c | (== '\n') c -> let (newlines, rest) = T.span (== '\n') t
                             p' = advanceVertical (T.length newlines) p
                             in go p' rest
      c | (liftA2 (&&) isSpace (/= '\n')) c ->
            let (spaces, rest) = T.span (liftA2 (&&) isSpace (/= '\n')) t
                p' = advanceHorizontal (T.length spaces) p
             in go p' rest
      '-' | "--" `T.isPrefixOf` t ->
          let (comment, rest) = T.span (/= '\n') t
              p' = advanceVertical 1 (advanceHorizontal (T.length comment) p)
           in go p' (T.drop 1 rest)
      '/' | "/*" `T.isPrefixOf` t ->
          case T.breakOn "*/" t of
              (comment, "") ->
                let p' = advance comment p
                 in [(TokError "unterminated join hint", p, p')]
              (comment, rest) ->
                let p' = advance (T.append comment "*/") p
                 in go p' $ T.drop 2 rest
      c | c == '\'' ->
          case tokExtString c p t of
            Left (tok, p') -> [(tok, p, p')]
            Right (string, rest, p') -> (TokString string, p, p') : go p' rest
      '.' ->
          let p' = advanceHorizontal 1 p
           in (TokSymbol ".", p, p') : go p' (T.tail t)
      c | isOperator c -> case readOperator t of
          Just (sym, rest) -> let p' = advanceHorizontal (T.length sym) p
                               in (TokSymbol sym, p, p') : go p' rest
          Nothing ->
              let opchars = T.take 5 t
                  p' = advance opchars p
                  message = unwords
                      [ "unrecognized operator starting with"
                      , show opchars
                      ]
               in [(TokError message, p, p')]
      c ->
          let message = unwords
                  [ "unmatched character ('" ++ show c ++ "') at position"
                  , show p
                  ]
           in [(TokError message, p, advanceHorizontal 1 p)]

isWordBody :: Char -> Bool
isWordBody = liftA3 (\x y z -> x || y || z) isAlphaNum (== '_') (== '$')

operators :: [T.Text]
operators = sortBy (flip compare)
  [ "+", "-", "*", "/", "%"
  , "||"
  , "&", "|", "^", "~"
  , "!"
  , ":"
  , "!=", "<>", ">", "<", ">=", "<=", "<=>", "=", "=="
  , "(", ")", "[", "]", ",", ";"
  ]
isOperator :: Char -> Bool
isOperator c = elem c $ map T.head operators

readOperator t = asum $ map (\ op -> (op,) <$> T.stripPrefix op t) operators

tokName :: Position -> T.Text -> Either (Token, Position, Position) (T.Text, Bool, T.Text, Position)
tokName pos = go pos [] False
  where
    go :: Position -> [T.Text] -> Bool -> T.Text -> Either (Token, Position, Position) (T.Text, Bool, T.Text, Position)
    go p [] _ "" = error $ "parse error at " ++ show p
    go p ts seen_quotes "" = Right (T.concat $ reverse ts, seen_quotes, "", p)
    go p ts seen_quotes input = case T.head input of
      c | isWordBody c ->
        let (word, rest) = T.span isWordBody input
            p' = advanceHorizontal (T.length word) p
         in go p' (T.toLower word:ts) seen_quotes rest
      c | c == '"' ->
        case tokString p '"' input of
            Left p' -> Left (TokError "end of input inside string", p, p')
            Right (quoted, rest, p') -> Right (quoted, True, rest, p')
      _ -> case ts of
        [] -> error "empty token"
        _ -> Right (T.concat $ reverse ts, seen_quotes, input, p)

parseVariable :: T.Text -> ((Token, Int64), T.Text)
parseVariable = runState $ do
  let endOfInput = "end of input inside variable substitution"
      missingNamespaceOrName = "variable substitutions must have a namespace and a name"
  modify $ T.drop 2
  namespace <- state (T.break (== ':'))

  gets (T.take 1) >>= \case
    "" ->
      let varLen = 2 + T.length namespace
       in if (not $ T.null namespace) && (T.last namespace == '}')
           then pure (TokError missingNamespaceOrName, varLen)
           else pure (TokError endOfInput, varLen)
    _ -> do
      modify $ T.drop 1
      gets (T.take 2) >>= \case
        "${" -> do
          ((subName, subLen), rest) <- gets parseVariable
          _ <- put rest
          gets (T.take 1) >>= \case
              "}" -> do
                modify $ T.drop 1
                let varLen = 2 + T.length namespace + 1 + subLen + 1
                    varName = TokVariable namespace $ DynamicName subName
                pure $ liftInnerErrors $ enforceNamespaces $ (varName, varLen)
              _ -> do
                let varLen = 2 + T.length namespace + 1 + subLen
                pure (TokError endOfInput, varLen)
                
        _ -> do
             name <- state (T.break (== '}'))
             gets (T.take 1) >>= \case
               "" ->
                 let varLen = 2 + T.length namespace + 1 + T.length name
                   in pure (TokError endOfInput, varLen)
               _ -> do
                 modify $ T.drop 1
                 let varLen = 2 + T.length namespace + 1 + T.length name + 1
                 if T.null name
                 then pure (TokError missingNamespaceOrName, varLen)
                 else pure (TokError endOfInput, varLen)
  where
    enforceNamespaces tok@(TokVariable ns _, len) =
      let allowedNamespaces = ["hiveconf", "system", "env", "define", "hivevar"]
          permitted = (`elem` allowedNamespaces)
       in if permitted ns
          then tok
          else (TokError $ "bad namespace in variable substitution: " ++ show ns, len)
    enforceNamespaces x = x
    liftInnerErrors (TokVariable _ (DynamicName (TokError msg)), len) = (TokError msg, len)
    liftInnerErrors x = x

parseNumber :: T.Text -> ((Token, Int64), T.Text)
parseNumber = runState $ do
  ipart <- state $ T.span isDigit
  gets (T.take 1) >>= \case
    "" -> pure (TokNumber ipart, T.length ipart)
    "." -> do
      modify $ T.drop 1
      fpart <- state $ T.span isDigit
      gets (T.take 1) >>= \case
        "e" -> do
          modify $ T.drop 1
          sign <- gets (T.take 1) >>= \case
            s | elem s ["+", "-"] -> modify (T.drop 1) >> pure s
            _ -> pure ""
          state (T.span isDigit) >>= \ epart ->
            let number = T.concat [ipart, ".", fpart, "e", sign, epart]
              in pure (TokNumber number, T.length number)
        _ ->
          let number = T.concat [ipart, ".", fpart]
            in pure (TokNumber number, T.length number)
    "e" -> do
      modify $ T.drop 1
      sign <- gets (T.take 1) >>= \case
        s | elem s ["+", "-"] -> modify (T.drop 1) >> pure s
        _ -> pure ""
      epart <- state $ T.span isDigit
      gets (T.take 1) >>= \case
        c | liftA2 (&&) (not . T.null) (isWordBody . T.head) c || T.null epart -> do
              rest <- state $ T.span isWordBody
              let word = T.concat [ipart, "e", sign, epart, rest]
              pure (TokWord False word, T.length word)
          | otherwise ->
            let number = T.concat [ipart, "e", sign, epart]
             in pure (TokNumber number, T.length number)
    c | liftA2 (||) isAlpha (== '_') (T.head c) -> do
          rest <- state $ T.span (liftA2 (||) isAlpha (== '_'))
          let word = T.concat [ipart, rest]
          pure (TokWord False word, T.length word)
    _ -> pure (TokNumber ipart, T.length ipart)

tokUnquotedWord :: Position -> T.Text -> (T.Text, T.Text, Position)
tokUnquotedWord pos input =
  case T.span (liftA2 (||) isAlphaNum (== '_')) input of
    (word, rest) -> (T.toLower word, rest, advanceHorizontal (T.length word) pos)

tokQuotedWord :: Position -> T.Text -> Either Position (T.Text, T.Text, Position)
tokQuotedWord pos = go (advanceHorizontal 1 pos) [] . T.tail
  where
    go p _ "" = Left p
    go p ts input = case T.head input of
      c | c == '`' ->
        let (quotes, rest) = T.span (== '`') input
            len = T.length quotes
         in if len `mod` 2 == 0
             then go (advanceHorizontal len p)
                     (T.take (len `div` 2) quotes : ts)
                     rest
             else Right (T.concat $ reverse (T.take (len `div` 2) quotes : ts)
                        , rest
                        , advanceHorizontal len p)
      _ -> let (t, rest) = T.span (/= '`') input
            in go (advance t p) (t:ts) rest

halve txt = T.take (T.length txt `div` 2) txt

tokString :: Position -> Char -> T.Text -> Either Position (T.Text, T.Text, Position)
tokString pos d = go (advanceHorizontal 1 pos) [] . T.tail
  where
    go p _ "" = Left p
    go p ts input = case T.head input of
        c | c == d ->
            let (quotes, rest) = T.span (== d) input
                len = T.length quotes
                t = T.take (len `div` 2) quotes
             in if len `mod` 2 == 0
                 then go (advanceHorizontal len p) (t:ts) rest
                 else let str = T.concat $ reverse $ t:ts
                          p' = advanceHorizontal len p
                       in Right (str, rest, p')
        _ -> let (t, rest) = T.span (/= d) input
              in go (advance t p) (t:ts) rest

tokExtString :: Char -> Position -> T.Text -> Either (Token, Position) (ByteString, T.Text, Position)
tokExtString quote pos = go (advanceHorizontal 1 pos) [] . T.drop 1
  where
    go p ts input = case T.span (not . (`elem` [quote, '\\']))  input of
      (cs, "") -> Left (TokError "end of input inside string", advance cs p)
      ("", rest) -> handleSlashes p ts rest
      (cs, rest) -> handleSlashes (advance cs p) (cs:ts) rest
    handleSlashes p ts input = case T.span (== '\\') input of
      (cs, "") -> Left (TokError "end of input inside string", advance cs p)
      ("", _) -> handleQuote p ts input
      (slashes, rest) ->
        let len = T.length slashes
         in if len `mod` 2 == 0
             then go (advanceHorizontal len p) (halve slashes:ts) rest
             else case T.splitAt 1 rest of
               (c, rest')
                 | c == "a" -> go (advanceHorizontal (len + 1) p) ("\a": halve slashes :ts) rest'
                 | c == "b" -> go (advanceHorizontal (len + 1) p) ("\BS": halve slashes :ts) rest'
                 | c == "f" -> go (advanceHorizontal (len + 1) p) ("\FF": halve slashes :ts) rest'
                 | c == "n" -> go (advanceHorizontal (len + 1) p) ("\n": halve slashes :ts) rest'
                 | c == "r" -> go (advanceHorizontal (len + 1) p) ("\r": halve slashes :ts) rest'
                 | c == "t" -> go (advanceHorizontal (len + 1) p) ("\t": halve slashes :ts) rest'
                 | c == "v" -> go (advanceHorizontal (len + 1) p) ("\v": halve slashes :ts) rest'
                 | c == "'" -> go (advanceHorizontal (len + 1) p) ("'": halve slashes :ts) rest'
                 | c == "\"" -> go (advanceHorizontal (len + 1) p) ("\"": halve slashes :ts) rest'
                 | otherwise -> go (advanceHorizontal (len + 1) p) (c:"\\":halve slashes :ts) rest'

    handleQuote p ts input = case T.splitAt 1 input of
      (c, rest) | c == T.singleton quote ->
        Right ( T.encodeUtf8 $ T.concat $ reverse ts
              , rest
              , advanceHorizontal 1 p
              )
      x -> error $ "this shouldn't happend: handleQuote splitInput got " ++ show x


showTok :: (Token, Position, Position) -> String
showTok (t, _, _) = show t

posFromTok :: P.SourcePos -> (Token, Position, Position) -> [(Token, Position, pOSITION)] -> P.SourcePos
posFromTok _ (_, pos, _) _ = flip P.setSourceLine (fromEnum $ positionLine pos)
                           $ flip P.setSourceColumn (fromEnum $ positionColumn pos)
                           $ P.initialPos "-"

keywordP :: T.Text -> Parser Range
keywordP keyword = P.tokenPrim showTok posFromTok testTok
  where
    testTok (tok, s, e) = case tok of
        TokWord False name | name == keyword -> Just (Range s e)
        _ -> Nothing

createProcedureP :: Parser (CreateProcedure RawNames Range)
createProcedureP = do
  s <- keywordP "create"
  orReplace <- P.optionMaybe $ (<>) <$> (keywordP "or") <*> (keywordP "replace")
  _ <- keywordP "procedure"
  undefined

orReplaceP :: Parser (Maybe Range)
orReplaceP = P.optionMaybe $ do
  s' <- keywordP "or"
  e' <- keywordP "replace"
  pure $ s' <> e'


-- statementParser :: Parser ()
-- statementParser = undefined



main :: IO ()
main = do
  putStrLn "hello world"
  runConduit
     $ (liftIO (T.getContents <&> T.lines) >>= C.yieldMany)
    .| C.iterM print
    .| C.mapM (cs >>> T.readFile)
    .| C.map tokenize
    .| C.concatMap id
    .| C.mapM print
    .| C.sinkNull
