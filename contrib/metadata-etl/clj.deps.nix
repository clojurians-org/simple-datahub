with import <nixos-19.09> {} ;
mkShell {
  buildInputs = [ pkgs.clojure ] ;
}
