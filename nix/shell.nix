{ repoRoot, inputs, pkgs, lib, system }:

cabalProject:

let
  cardano-cli = cabalProject.hsPkgs.cardano-cli.components.exes.cardano-cli;
  cardano-node = cabalProject.hsPkgs.cardano-node.components.exes.cardano-node;
  cardano-submit-api = cabalProject.hsPkgs.cardano-submit-api.components.exes.cardano-submit-api;
in

{
  name = "stablecoin-plutus";

  packages = [
    pkgs.ghcid
    pkgs.haskellPackages.hoogle
  ];

  # env = {
  #   CARDANO_CLI = "${cardano-cli}/bin/cardano-cli";
  #   CARDANO_NODE = "${cardano-node}/bin/cardano-node";
  #   CARDANO_SUBMIT_API = "${cardano-submit-api}/bin/cardano-submit-api";
  # };

  preCommit = {
    cabal-fmt.enable = true;
    stylish-haskell.enable = true;
    nixpkgs-fmt.enable = true;
  };
}
