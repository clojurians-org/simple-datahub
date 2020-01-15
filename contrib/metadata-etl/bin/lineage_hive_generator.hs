#! /usr/bin/env nix-shell
#! nix-shell ../deps.nix -i runghc

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}

import Control.Lens
import Control.Monad
import Control.Arrow
import Data.Proxy (Proxy(..))
import Data.Either
import Data.List


import Data.String.Conversions (cs)
import qualified Data.Text.Lazy as T
import qualified Data.Text.Lazy.IO as T

import qualified Data.Map as M
import qualified Data.Set as S
import qualified Data.HashMap.Strict as HM
import qualified Data.Aeson as J
import qualified Data.Aeson.Encode.Pretty as J

import Data.Conduit (ConduitT, runConduitRes, runConduit, bracketP, (.|))
import qualified Data.Conduit.Combinators as C

import Database.HsSqlPpp.Parse (parseProcSQL, defaultParseFlags, ParseFlags(..))
import Database.HsSqlPpp.Dialect (postgresDialect)

import qualified Database.Sql.Hive.Parser as HIVE
import qualified Database.Sql.Hive.Type as HIVE

import Database.Sql.Type (
    Catalog(..), DatabaseName(..), FullyQualifiedTableName(..)
  , makeDefaultingCatalog, mkNormalSchema
  )

import Database.Sql.Util.Scope (runResolverWarn)
import Database.Sql.Util.Lineage.Table (getTableLineage)

instance J.ToJSON FullyQualifiedTableName
instance J.ToJSONKey FullyQualifiedTableName

catalog :: Catalog
catalog = makeDefaultingCatalog HM.empty
                                [mkNormalSchema "public" ()]
                                (DatabaseName () "defaultDatabase")

main = do 
  contents <- T.getContents <&> T.lines

  runConduit $ C.yieldMany contents
            .| C.iterM print
            .| C.mapM (cs >>> T.readFile)
            .| C.concatMap parseSQL
            .| C.mapM resolveStatement
            .| C.concatMap (getTableLineage >>> M.toList)
            .| C.map mkMCE
            .| C.mapM_ (J.encode >>> cs >>> putStrLn)
  where
    parseSQL sql = do
      let stOrErr = HIVE.parseManyAll sql
      when (isLeft stOrErr) $
        error $ show (fromLeft undefined stOrErr)
      fromRight undefined stOrErr
    resolveStatement st =  do
      let resolvedStOrErr = runResolverWarn (HIVE.resolveHiveStatement st) HIVE.dialectProxy catalog
      when (isLeft . fst $ resolvedStOrErr) $
        error $ show (fromLeft undefined (fst resolvedStOrErr))
      let (Right queryResolved, resolutions) = resolvedStOrErr
      return queryResolved
    mkMCE (output, inputs) = (tableName output, S.map tableName inputs)
    tableName (FullyQualifiedTableName database schema name) = T.intercalate "." [database, schema, name]
    
