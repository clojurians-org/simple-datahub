{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE OverloadedStrings #-}

module Oracle where

import Data.Int
import Data.Char
import Data.Data
import GHC.Generics
import Control.Applicative

import Control.Lens ()

import Data.ByteString.Lazy (ByteString)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as T
import qualified Data.Set as S
import qualified Text.Parsec as P
import Control.Monad.Reader (Reader)

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
data CreateProcedure r a
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

data Position = Position
  { positionLine :: Int64
  , positionColumn :: Int64
  , positionOffset :: Int64
  } deriving (Generic, Data, Show, Eq, Ord)


data Token = TokWord !Bool !Text
           | TokString !ByteString
           | TokNumber !Text
           | TokSymbol !Text
           | TokVariable !Text VariableName
           | TokError !String
           deriving (Show, Eq)

data VariableName = StaticName !Text
                  | DynamicName Token
                  deriving (Show, Eq)

type ScopeTableRef = Text
data ParserScope = ParserScope
    { selectTableAliases :: Maybe (S.Set ScopeTableRef) }
    deriving (Eq, Ord, Show)

type Parser = P.ParsecT [(Token, Position, Position)] Integer (Reader ParserScope)

advanceHorizontal :: Int64 -> Position -> Position
advanceHorizontal n p = p
  { positionColumn = positionColumn p + n
  , positionOffset = positionOffset p + n
  }
advanceVertical :: Int64 -> Position -> Position
advanceVertical n p = p
  { positionLine = positionLine p + n
  , positionColumn = if n > 0 then 0 else positionColumn p
  , positionOffset = positionOffset p + n
  }
tokenize :: Text -> [(Token, Position, Position)]
tokenize = go (Position 1 0 0)
  where
    go :: Position -> Text -> [(Token, Position, Position)]
    go _ "" = []
    go p t = case T.head t of
      c | isAlpha c ->
          case tokUnquotedWord p t of
            (name, rest, p') -> (TokWord False name, p, p') : go p' rest
      c | isDigit c -> undefined

      c -> undefined
    -- go p t = 

parseNumber :: Text -> ((Token, Int64), Text)
parseNumber = undefined

tokUnquotedWord :: Position -> T.Text -> (T.Text, T.Text, Position)
tokUnquotedWord pos input =
  case T.span (liftA2 (||) isAlphaNum (== '_')) input of
    (word, rest) -> (T.toLower word, rest, advanceHorizontal (T.length word) pos)

-- statementParser :: Parser ()
-- statementParser = undefined
