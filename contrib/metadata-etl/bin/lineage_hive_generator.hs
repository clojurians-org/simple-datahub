#! /usr/bin/env nix-shell
#! nix-shell ../deps.nix -i runghc

{-# LANGUAGE OverloadedStrings #-}


import Control.Lens
import Data.Proxy (Proxy(..))
import Data.Either (isLeft, fromRight, fromLeft)
import Control.Monad (when)

import Data.String.Conversions (cs)
import qualified Data.Text.Lazy.IO as T
import qualified Data.HashMap.Strict as M
import qualified Data.Aeson as J
import qualified Data.Aeson.Encode.Pretty as J

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
catalog = makeDefaultingCatalog M.empty
                                [mkNormalSchema "public" ()]
                                (DatabaseName () "defaultDatabase")


main = do 
  content <- T.getContents
  let stOrErr = HIVE.parse content
  when (isLeft stOrErr) $
    error $ show (fromLeft undefined stOrErr)
  let Right st = stOrErr
  let resolvedStOrErr = runResolverWarn (HIVE.resolveHiveStatement st) HIVE.dialectProxy catalog
  when (isLeft . fst $ resolvedStOrErr) $
    error $ show (fromLeft undefined (fst resolvedStOrErr))
  let (Right queryResolved, resolutions) = resolvedStOrErr
  putStrLn $ cs . J.encodePretty $ getTableLineage queryResolved

