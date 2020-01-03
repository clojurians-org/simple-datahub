#! /usr/bin/env nix-shell
#! nix-shell deps.nix -i runghc

import Control.Lens
main = do
  putStrLn $ ("hello","world")^._2

