with import <nixos-19.09> {} ;
mkShell {
  buildInputs = [
    (haskellPackages.ghcWithPackages ( p: with p ;
      [ lens hssqlppp ]
    ))
  ];
}
