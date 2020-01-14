#! /usr/bin/env nix-shell
#! nix-shell ../deps.nix -i runghc

import qualified Data.Text.Lazy.IO as T
import Database.HsSqlPpp.Parse (parseProcSQL, defaultParseFlags, ParseFlags(..))
import Database.HsSqlPpp.Dialect (postgresDialect)
import Control.Lens
main = do 
  content <-  T.readFile "./metadata_sample/pg_procedure.sql"
  let ast = parseProcSQL (ParseFlags {pfDialect = postgresDialect}) "-" Nothing content
  print $ ast

