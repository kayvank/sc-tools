{ repoRoot, inputs, pkgs, lib, system }:

cabalProject:

let
  cardano-cli = inputs.cardano-node.legacyPackages.cardano-cli;
  cardano-node = inputs.cardano-node.legacyPackages.cardano-node;
  cardano-submit-api = inputs.cardano-node.legacyPackages.cardano-submit-api;
in

{
  name = "sc-tools";

  packages = [
    cardano-cli
    cardano-node
    cardano-submit-api
    pkgs.ghcid
    pkgs.haskellPackages.hoogle
  ];

  env = {
    CARDANO_CLI = "${cardano-cli}/bin/cardano-cli";
    CARDANO_NODE = "${cardano-node}/bin/cardano-node";
    CARDANO_SUBMIT_API = "${cardano-submit-api}/bin/cardano-submit-api";
  };

  preCommit = {
    cabal-fmt.enable = true;
    stylish-haskell.enable = true;
    nixpkgs-fmt.enable = true;
  };
  shellHook = ''
'';

}
