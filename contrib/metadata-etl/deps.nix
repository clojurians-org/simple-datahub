with import <nixos-19.09> {} ;
let 
  haskellPackages = pkgs.haskellPackages.override {
    overrides = self: super: with pkgs.haskell.lib; {
      queryparser = doJailbreak(self.callCabal2nix "queryparser"
        # (fetchFromGitHub {
        #   owner = "uber" ;
        #   repo = "queryparser" ;
        #   rev = "6015e8f273f4498326fec0315ac5580d7036f8a4" ;
        #   sha256 = "05pnifm5awyqxi6330v791b1cvw26xbcn2r20pqakvl9d3xyaxa4" ;
        # }) 
        ./library/queryparser
      {}) ;
      queryparser-hive = doJailbreak(self.callCabal2nix "queryparser-hive" ./library/queryparser/dialects/hive {}) ;
    } ;
  };
in 
mkShell {
  buildInputs = [
    (haskellPackages.ghcWithPackages ( p: 
      [ p.bytestring p.text p.string-conversions
        p.aeson p.aeson-pretty p.lens
        p.hssqlppp p.queryparser p.queryparser-hive ]
    ))
  ];
}
