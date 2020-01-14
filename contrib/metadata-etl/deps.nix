with import <nixos-19.09> {} ;
let 
  haskellPackages = pkgs.haskellPackages.override {
    overrides = self: super: with pkgs.haskell.lib; {
      queryparser = doJailbreak(self.callCabal2nix "queryparser" (fetchFromGitHub {
        owner = "uber" ;
        repo = "queryparser" ;
        rev = "6015e8f273f4498326fec0315ac5580d7036f8a4" ;
        sha256 = "05pnifm5awyqxi6330v791b1cvw26xbcn2r20pqakvl8d3xyaxa4" ;
      }) {}) ;

    } ;
  };
in 
mkShell {
  buildInputs = [
    (haskellPackages.ghcWithPackages ( p: 
      #[ p.text p.lens p.hssqlppp p.queryparser ]
      [ p.text p.lens p.hssqlppp ]
    ))
  ];
}
