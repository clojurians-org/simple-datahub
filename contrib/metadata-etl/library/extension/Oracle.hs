{-# LANGUAGE StandaloneDeriving, DeriveGeneric, DeriveDataTypeable, DeriveTraversable #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase, TupleSections #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TypeFamilies #-}

module Oracle where

import Data.Int
import Data.Char
import Data.Data hiding (DataType)
import Data.List
import Data.Functor
import Data.Foldable
import GHC.Generics
import Control.Applicative
import Control.Arrow
import Control.Monad
import Control.Monad.IO.Class
import Control.Monad.Trans (lift)

import Data.These
import Control.Lens ()

import Data.String.Conversions (cs)
import Data.ByteString.Lazy (ByteString)
import qualified Data.Text.Lazy as T
import qualified Data.Text.Lazy.IO as T
import qualified Data.Text.Lazy.Encoding as T

import qualified Data.Set as S

import qualified Text.Parsec as P
import qualified Text.Parsec.Pos as P
import Control.Monad.Reader (Reader, runReader)
import Control.Monad.State (State, runState, state, gets, put, modify)

import Database.Sql.Position
  (Position(..), Range(..), advance, advanceHorizontal, advanceVertical)
import Database.Sql.Type
  ( RawNames(..), QSchemaName(..), ConstrainSNames(..)
  , mkNormalSchema)

import Data.Conduit (ConduitT, runConduitRes, runConduit, bracketP, (.|))
import qualified Data.Conduit.Combinators as C

data Oracle
deriving instance Data Oracle
dialectProxy :: Proxy Oracle
dialectProxy = Proxy
                                                    
-- https://docs.oracle.com/cd/E11882_01/server.112/e41085/sqlqr01001.htm#SQLQR110
data OracleTotalStatement r a
  = OracleAlterClusterStatement (AlterCluster r a)
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

deriving instance Generic (OracleTotalStatement r a)
deriving instance ConstrainSNames Show r a => Show (OracleTotalStatement r a)

data AlterCluster r a = AlterCluster a deriving (Generic, Show)

data AlterDatabase r a = AlterDatabase a deriving (Generic, Show, Eq)
data AlterDatabaseLink r a = AlterDatabaseLink a deriving (Generic, Show, Eq)
data AlterDimension r a = AlterDimension a deriving (Generic, Show, Eq)
data AlterDiskgroup r a = AlterDiskgroup a deriving (Generic, Show, Eq)
data AlterFlashbackArchive r a = AlterFlashbackArchive a deriving (Generic, Show, Eq)
data AlterFunction r a = AlterFunction a deriving (Generic, Show, Eq)
data AlterIndex r a = AlterIndex a deriving (Generic, Show, Eq)
data AlterIndextype r a = AlterIndextype a deriving (Generic, Show, Eq)
data AlterJava r a = AlterJava a deriving (Generic, Show, Eq)
data AlterLibrary r a = AlterLibrary a deriving (Generic, Show, Eq)
data AlterMaterializedView r a = AlterMaterializedView a deriving (Generic, Show, Eq)
data AlterMaterializedViewLog r a = AlterMaterializedViewLog a deriving (Generic, Show, Eq)
data AlterOperator r a = AlterOperator a deriving (Generic, Show, Eq)
data AlterOutline r a = AlterOutline a deriving (Generic, Show, Eq)
data AlterPackage r a = AlterPackage a deriving (Generic, Show, Eq)
data AlterProcedure r a = AlterProcedure a deriving (Generic, Show, Eq)
data AlterProfile r a = AlterProfile a deriving (Generic, Show, Eq)
data AlterResourceCost r a = AlterResourceCost a deriving (Generic, Show, Eq)
data AlterRole r a = AlterRole a deriving (Generic, Show, Eq)
data AlterRollbackSegment r a = AlterRollbackSegment a deriving (Generic, Show, Eq)
data AlterSequence r a = AlterSequence a deriving (Generic, Show, Eq)
data AlterSession r a = AlterSession a deriving (Generic, Show, Eq)
data AlterSystem r a = AlterSystem a deriving (Generic, Show, Eq)
data AlterTable r a = AlterTable a deriving (Generic, Show, Eq)
data AlterTablespace r a = AlterTablespace a deriving (Generic, Show, Eq)
data AlterTrigger r a = AlterTrigger a deriving (Generic, Show, Eq)
data AlterType r a = AlterType a deriving (Generic, Show, Eq)
data AlterUser r a = AlterUser a deriving (Generic, Show, Eq)
data AlterView r a = AlterView a deriving (Generic, Show, Eq)
data Analyze r a = Analyze a deriving (Generic, Show, Eq)
data AssociateStatistics r a = AssociateStatistics a deriving (Generic, Show, Eq)
data Audit r a = Audit a deriving (Generic, Show, Eq)
data Call r a = Call a deriving (Generic, Show, Eq)
data Comment r a = Comment a deriving (Generic, Show, Eq)
data Commit r a = Commit a deriving (Generic, Show, Eq)
data CreateCluster r a = CreateCluster a deriving (Generic, Show, Eq)
data CreateContext r a = CreateContext a deriving (Generic, Show, Eq)
data CreateControlfile r a = CreateControlfile a deriving (Generic, Show, Eq)
data CreateDatabase r a = CreateDatabase a deriving (Generic, Show, Eq)
data CreateDatabaseLink r a = CreateDatabaseLink a deriving (Generic, Show, Eq)
data CreateDimension r a = CreateDimension a deriving (Generic, Show, Eq)
data CreateDirectory r a = CreateDirectory a deriving (Generic, Show, Eq)
data CreateDiskgroup r a = CreateDiskgroup a deriving (Generic, Show, Eq)
data CreateEdition r a = CreateEdition a deriving (Generic, Show, Eq)
data CreateFlashbackArchive r a = CreateFlashbackArchive a deriving (Generic, Show, Eq)
data CreateFunction r a = CreateFunction a deriving (Generic, Show, Eq)
data CreateIndex r a = CreateIndex a deriving (Generic, Show, Eq)
data CreateIndextype r a = CreateIndextype a deriving (Generic, Show, Eq)
data CreateJava r a = CreateJava a deriving (Generic, Show, Eq)
data CreateLibrary r a = CreateLibrary a deriving (Generic, Show, Eq)
data CreateMaterializedView r a = CreateMaterializedView a deriving (Generic, Show, Eq)
data CreateMaterializedViewLog r a = CreateMaterializedViewLog a deriving (Generic, Show, Eq)
data CreateOperator r a = CreateOperator a deriving (Generic, Show, Eq)
data CreateOutline r a = CreateOutline a deriving (Generic, Show, Eq)
data CreatePackage r a = CreatePackage a deriving (Generic, Show, Eq)
data CreatePackageBody r a = CreatePackageBody a deriving (Generic, Show, Eq)
data CreatePfile r a = CreatePfile a deriving (Generic, Show, Eq)
data CreateProcedure r a = CreateProcedure
  { createProcedureInfo :: a
  , createProcedureOrReplace :: Maybe a
  , createProcedureName :: QProcedureName Maybe a
  , createProcedureParams :: [ParameterDeclaration r a]
  , createProcedureInvokerRights :: Maybe T.Text
  , createProcedureImpl :: CreateProcedureImpl r a
  }
deriving instance Generic (CreateProcedure r a)
deriving instance ConstrainSNames Show r a  => Show (CreateProcedure r a)

data CreateProfile r a = CreateProfile a deriving (Generic, Show, Eq)
data CreateRestorePoint r a = CreateRestorePoint a deriving (Generic, Show, Eq)
data CreateRole r a = CreateRole a deriving (Generic, Show, Eq)
data CreateRollbackSegment r a = CreateRollbackSegment a deriving (Generic, Show, Eq)
data CreateSchema r a = CreateSchema a deriving (Generic, Show, Eq)
data CreateSequence r a = CreateSequence a deriving (Generic, Show, Eq)
data CreateSpfile r a = CreateSpfile a deriving (Generic, Show, Eq)
data CreateSynonym r a = CreateSynonym a deriving (Generic, Show, Eq)
data CreateTable r a = CreateTable a deriving (Generic, Show, Eq)
data CreateTablespace r a = CreateTablespace a deriving (Generic, Show, Eq)
data CreateTrigger r a = CreateTrigger a deriving (Generic, Show, Eq)
data CreateType r a = CreateType a deriving (Generic, Show, Eq)
data CreateTypeBody r a = CreateTypeBody a deriving (Generic, Show, Eq)
data CreateUser r a = CreateUser a deriving (Generic, Show, Eq)
data CreateView r a = CreateView a deriving (Generic, Show, Eq)
data Delete r a = Delete a deriving (Generic, Show, Eq)
data DisassociateStatistics r a = DisassociateStatistics a deriving (Generic, Show, Eq)
data DropCluster r a = DropCluster a deriving (Generic, Show, Eq)
data DropContext r a = DropContext a deriving (Generic, Show, Eq)
data DropDatabase r a = DropDatabase a deriving (Generic, Show, Eq)
data DropDatabaseLink r a = DropDatabaseLink a deriving (Generic, Show, Eq)
data DropDimension r a = DropDimension a deriving (Generic, Show, Eq)
data DropDirectory r a = DropDirectory a deriving (Generic, Show, Eq)
data DropDiskgroup r a = DropDiskgroup a deriving (Generic, Show, Eq)
data DropEdition r a = DropEdition a deriving (Generic, Show, Eq)
data DropFlashbackArchive r a = DropFlashbackArchive a deriving (Generic, Show, Eq)
data DropFunction r a = DropFunction a deriving (Generic, Show)
data DropIndex r a = DropIndex a deriving (Generic, Show)
data DropIndextype r a = DropIndextype a deriving (Generic, Show)
data DropJava r a = DropJava a deriving (Generic, Show)
data DropLibrary r a = DropLibrary a deriving (Generic, Show)
data DropMaterializedView r a = DropMaterializedView a deriving (Generic, Show)
data DropMaterializedViewLog r a = DropMaterializedViewLog a deriving (Generic, Show)
data DropOperator r a = DropOperator a deriving (Generic, Show)
data DropOutline r a = DropOutline a deriving (Generic, Show)
data DropPackage r a = DropPackage a deriving (Generic, Show)
data DropProcedure r a = DropProcedure a deriving (Generic, Show)
data DropProfile r a = DropProfile a deriving (Generic, Show)
data DropRestorePoint r a = DropRestorePoint a deriving (Generic, Show)
data DropRole r a = DropRole a deriving (Generic, Show)
data DropRollbackSegment r a = DropRollbackSegment a deriving (Generic, Show)
data DropSequence r a = DropSequence a deriving (Generic, Show)
data DropSynonym r a = DropSynonym a deriving (Generic, Show)
data DropTable r a = DropTable a deriving (Generic, Show)
data DropTablespace r a = DropTablespace a deriving (Generic, Show)
data DropTrigger r a = DropTrigger a deriving (Generic, Show)
data DropType r a = DropType a deriving (Generic, Show)
data DropTypeBody r a = DropTypeBody a deriving (Generic, Show)
data DropUser r a = DropUser a deriving (Generic, Show)
data DropView r a = DropView a deriving (Generic, Show)
data ExplainPlan r a = ExplainPlan a deriving (Generic, Show)
data FlashbackDatabase r a = FlashbackDatabase a deriving (Generic, Show)
data FlashbackTable r a = FlashbackTable a deriving (Generic, Show)
data Grant r a = Grant a deriving (Generic, Show)
data Insert r a = Insert a deriving (Generic, Show)
data LockTable r a = LockTable a deriving (Generic, Show)
data Merge r a = Merge a deriving (Generic, Show)
data Noaudit r a = Noaudit a deriving (Generic, Show)
data Purge r a = Purge a deriving (Generic, Show)
data Rename r a = Rename a deriving (Generic, Show)
data Revoke r a = Revoke a deriving (Generic, Show)
data Rollback r a = Rollback a deriving (Generic, Show)
data Savepoint r a = Savepoint a deriving (Generic, Show)
data Select r a = Select a deriving (Generic, Show)
data SetConstraint r a = SetConstraint a deriving (Generic, Show)
data SetRole r a = SetRole a  deriving (Generic, Show)
data SetTransaction r a = SetTransaction a deriving (Generic, Show)
data TruncateCluster r a = TruncateCluster a deriving (Generic, Show)
data TruncateTable r a = TruncateTable a deriving (Generic, Show)
data Update r a = Update a deriving (Generic, Show)

data QProcedureName f a = QProcedureName
  { procedureNameInfo :: a
  , procedureNameSchema :: f (QSchemaName f a)
  , procedureNameName :: T.Text
  }
deriving instance Generic (QProcedureName f a)
deriving instance (Show a, Show (f (QSchemaName f a))) => Show (QProcedureName f a)

data Parameter a = Parameter T.Text a
  deriving (Generic, Show)
data BaseList b s = b :/ [s]
    deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

data ParameterDeclaration r a = ParameterDeclaration (Parameter a) (Maybe (ParameterBody r a))
deriving instance Generic (ParameterDeclaration r a)
deriving instance ConstrainSNames Show r a => Show (ParameterDeclaration r a)

data ParameterBody r a
  = ParameterBodyIn (DataType r a) (Maybe (Expression r a))
  | ParameterBodyInOut (Maybe Bool) (DataType r a)
deriving instance Generic (ParameterBody r a)
deriving instance ConstrainSNames Show r a => Show (ParameterBody r a)

data DataType r a
  = DataTypeColection a (CollectionType r a)
  | DataTypeObject a (ObjectType r a)
  | DataTypeRecord a (RecordType r a)
  | DataTypeCursor a (CursorType r a)
  | DataTypeRow a (RowType r a)
  | DataTypeScalar a ScalarType
  | DataTypeAttribute a (TypeAttribute r a)
deriving instance Generic (DataType r a)
deriving instance ConstrainSNames Show r a => Show (DataType r a)

data CollectionType r a = CollectionType a deriving (Generic, Show)
data ObjectType r a = ObjectType a deriving (Generic, Show)
data RecordType r a = RecordType a deriving (Generic, Show)
data CursorType r a = CursorType a deriving (Generic, Show)
data RowType r a = RowType a deriving (Generic, Show)
data TypeAttribute r a = TypeAttribute a deriving (Generic, Show)

-- https://docs.oracle.com/cd/B28359_01/appdev.111/b28370/datatypes.htm#i43252
data ScalarType
  = PLS_INTEGER
  | BINARY_INTEGER
  | BINARY_FLOAT
  | BINARY_DOUBLE
  | NUMBER
  | CHAR
  | VARCHAR2
  | RAW
  | NCHAR
  | NVARCHAR2
  | LONG
  | LONG_RAW
  | ROWID
  | UROWID
  | CLOB
  | NCLOB
  deriving (Generic, Show)

data CreateProcedureImpl r a
    = ProcedureDeclareImpl a (ProcedureDeclareSection r a) (ProcedureBody r a)
    | ProcedureLanguageImpl a
    | ProcedureExternalImpl a
deriving instance Generic (CreateProcedureImpl r a)
deriving instance ConstrainSNames Show r a => Show (CreateProcedureImpl r a)


data ProcedureDeclareSection r a = These (BaseList (ProcedureItemList1Base r a) (ProcedureItemList1More r a))
                                         (BaseList (ProcedureItemList2Base r a) (ProcedureItemList2More r a))
    deriving (Generic, Data, Eq, Ord, Show)
instance Functor (ProcedureDeclareSection r) where
  fmap = undefined
instance Foldable (ProcedureDeclareSection r) where
  foldMap = undefined
instance Traversable (ProcedureDeclareSection r) where
  traverse = undefined

data ProcedureItemList1Base r a
    = ItemList1BaseTypeDefinition a (TypeDefinition r a)
    | ItemList1BaseCursorDeclaration a (CursorDeclaration r a)
    | ItemList1BaseItemDeclaration a (ItemDeclaration r a)
    | ItemList1BaseFunctionDeclaration a (FunctionDeclaration r a)
    | ItemList1BaseProcedureDeclaration a (ProcedureDeclaration r a)
    deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data ProcedureItemList1More r a
    = ItemList1MoreTypeDefinition a (TypeDefinition r a)
    | ItemList1MoreCursorDeclaration a (CursorDeclaration r a)
    | ItemList1MoreItemDeclaration a (ItemDeclaration r a)
    | ItemList1MoreFunctionDeclaration (FunctionDeclaration r a)
    | ItemList1MoreProcedureDeclaration (ProcedureDeclaration r a)
    | ItemList1MorePragma (Pragma r a)
    deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data ProcedureItemList2Base r a
    = ItemList2BaseCursorDeclaration a (CursorDeclaration r a)
    | ItemList2BaseCursorDefinition a (CursorDefinition r a)
    | ItemList2BaseFunctionDeclaration a (FunctionDeclaration r a)
    | ItemList2BaseFunctionDefinition a (FunctionDefinition r a)
    | ItemList2BaseProcedureDeclaration a (ProcedureDeclaration r a)
    | ItemList2BaseProcedureDefinition a (ProcedureDefinition r a)
    deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data ProcedureItemList2More r a
    = ItemList2MoreCursorDeclaration a (CursorDeclaration r a)
    | ItemList2MoreCursorDefinition a (CursorDefinition r a)
    | ItemList2MoreFunctionDeclaration a (FunctionDeclaration r a)
    | ItemList2MoreFunctionDefinition a (FunctionDefinition r a)
    | ItemList2MoreProcedureDeclaration a (ProcedureDeclaration r a)
    | ItemList2MoreProcedureDefinition a (ProcedureDefinition r a)
    | ItemList2MorePragma a (Pragma r a)
    deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

data ProcedureBody r a = ProcedureBody
  { procedureBodyInfo :: a
  , procedureBodyStatements :: BaseList (ProcedureStatement r a) (ProcedureBodyStatement r a)
  , procedureExceptions :: [ProcedureExceptionHandler r a]
  } deriving (Generic, Data, Eq, Ord, Show)
instance Functor (ProcedureBody r) where
  fmap = undefined
instance Foldable (ProcedureBody r) where
  foldMap = undefined
instance Traversable (ProcedureBody r) where
  traverse = undefined

data ProcedureBodyStatement r a
    = ProcedureBodyStatement01 a (ProcedureStatement r a)
    | ProcedureBodyStatement02 a (ProcedureInlinePragma r a)
    deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

data Label a = Label T.Text
    deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data ProcedureStatement r a
    = ProcedureStatement [Label a] (ProcedureStatementBase r a)
    deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data ProcedureExceptionHandler r a = ProcedureExceptionHandler a
    deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data ProcedureInlinePragma r a = ProcedureInlinePragma a
    deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
  
data Pragma r a = Pragma a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

data TypeDefinition r a = TypeDefinition a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data ItemDeclaration r a = ItemDeclaration a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

data CursorDeclaration r a = CursorDeclaration a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data CursorDefinition r a = CursorDefinition a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data FunctionDeclaration r a = FunctionDeclaration a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data FunctionDefinition r a = FunctionDefinition a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data ProcedureDeclaration r a = ProcedureDeclaration a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data ProcedureDefinition r a = ProcedureDefinition a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

data ProcedureStatementBase r a
  = ProcedureStatementBase01 (AssignmentStatement r a)
{--
  | ProcedureStatementBase02 (BasicLoopStatement r a)
  | CaseStatement r a
  | CloseStatement r a
  | CollectionMethodCall2 r a
  | ContinueStatement r a
  | CursorForLoopStatement r a
  | ExecuteImmediateStatement r a
  | ExitStatement r a
  | FetchStatement r a
  | ForLoopStatement r a
  | ForallStatement r a
  | GotoStatement r a
  | IfStatement r a
  | NullStatement r a
  | OpenStatement r a
  | OpenForStatement r a
  | PipeRowStatement r a
  | PlsqlBlock r a
  | ProcedureCall r a
  | RaiseStatement r a
  | ReturnStatement r a
  | SelectIntoStatement r a
  | SqlStatement r a
  | WhileLoopStatement r a
--}
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
    
data SqlStatement r a
  = CommitStatement r a
  | CollectionMethodCall r a
  | DeleteStatement r a
  | InsertStatement r a
  | LockTableStatement r a
  | MergeStatement r a
  | RollbackStatement r a
  | SavepointStatement r a
  | SetTransactionStatement r a
  | UpdateStatement r a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

data AssignmentStatement r a
  = AssignmentStatement a (AssignStatementTarget r a) (Expression r a)
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

data AssignStatementTarget r a = AssignStatementTarget a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

data Expression r a
  = Expression01 a (BooleanExpression r a)
  | Expression02 a (CharacterExpression r a)
  | Expression03 a (CollectionConstructor r a)
  | Expression04 a (DateExpression r a)
  | Expression05 a (NumericExpression r a)
  | Expression06 a (SearchedCaseExpression r a)
  | Expression07 a (SimpleCaseExpression r a)
  | Expression08 a (Expression r a)
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

data BooleanExpression r a = BooleanExpression a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data CharacterExpression r a = CharacterExpression a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data CollectionConstructor r a = CollectionConstructor a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data DateExpression r a = DateExpression a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data NumericExpression r a = NumericExpression a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data SearchedCaseExpression r a = SearchedCaseExpression a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)
data SimpleCaseExpression r a = SimpleCaseExpression a
  deriving (Generic, Data, Eq, Ord, Show, Functor, Foldable, Traversable)

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
  , ":", ":="
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

nameP :: (T.Text -> Bool) -> Parser (T.Text, Range)
nameP pred = P.tokenPrim showTok posFromTok testTok
  where
    testTok (tok, s, e) = case tok of
      TokWord True name -> Just (name, Range s e)
      TokWord False name -> Just (name, Range s e)

symbolP :: T.Text -> Parser Range
symbolP t =  P.tokenPrim showTok posFromTok testTok
  where
    testTok (tok, s, e) = case tok of
      TokSymbol t' | t == t' -> Just (Range s e)
      _ -> Nothing

createProcedureP :: Parser (CreateProcedure RawNames Range)
createProcedureP = do
  kCreate <- keywordP "create"
  orReplace <- P.optionMaybe $ (<>) <$> (keywordP "or") <*> (keywordP "replace")
  keywordP "procedure"
  procedureName <- procedureNameP
  pure $ CreateProcedure
      { createProcedureInfo = undefined
      , createProcedureOrReplace = orReplace
      , createProcedureName = procedureName
      , createProcedureParams = []
      , createProcedureInvokerRights = Nothing
      , createProcedureImpl = undefined
      }

procedureNameP :: Parser (QProcedureName Maybe Range)
procedureNameP = P.choice
  [ P.try $ do
      (s, r) <- nameP (const True)
      symbolP "."
      (t, r') <- nameP (const True)
      return $ QProcedureName (r <> r') (Just (mkNormalSchema s r )) t
  , do
      (t, r)  <- nameP (const True)
      return $ QProcedureName r Nothing t
  ]

parameterDeclarationP :: Parser (ParameterDeclaration RawNames Range)
parameterDeclarationP = do
  undefined

statementParser :: Parser (OracleTotalStatement RawNames Range)
statementParser = P.choice
  [ OracleCreateProcedureStatement <$> createProcedureP
  ]

emptyParserScope :: ParserScope
emptyParserScope = ParserScope { selectTableAliases = Nothing }

parse :: T.Text -> Either P.ParseError (OracleTotalStatement RawNames Range)
parse = flip runReader emptyParserScope . P.runParserT statementParser 0 "-" . tokenize

main :: IO ()
main = do
  putStrLn "hello world"
  runConduit
     $ (liftIO (T.getContents <&> T.lines) >>= C.yieldMany)
    .| C.iterM print
    .| C.mapM (cs >>> T.readFile)
--    .| (C.map tokenize .| C.concatMap id)
    .| C.map parse
    .| C.mapM print
    .| C.sinkNull
