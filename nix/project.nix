{ repoRoot, inputs, pkgs, lib, system }:

let

  sha256map = {
    # This section is to handlejgit repositores in projects, needs to align with cabal.project
    # for details see https://input-output-hk.github.io/haskell.nix/tutorials/source-repository-hashes.html
  };


  modules = [
    ({ config, ... }: {
      packages = {
        # The lines `export CARDANO_NODE=...` and `export CARDANO_CLI=...`
        # is necessary to prevent the error
        # `../dist-newstyle/cache/plan.json: openBinaryFile: does not exist (No such file or directory)`.
        # See https://github.com/input-output-hk/cardano-node/issues/4194.
        #
        # The line 'export CARDANO_NODE_SRC=...' is used to specify the
        # root folder used to fetch the `configuration.yaml` file (in
        # marconi, it's currently in the
        # `configuration/defaults/byron-mainnet` directory.
        # Else, we'll get the error
        # `/nix/store/ls0ky8x6zi3fkxrv7n4vs4x9czcqh1pb-marconi/marconi/test/configuration.yaml: openFile: does not exist (No such file or directory)`
        convex-devnet.preCheck = "
      export CARDANO_CLI=${inputs.cardano-node.legacyPackages.cardano-cli}/bin/cardano-cli${pkgs.stdenv.hostPlatform.extensions.executable}
      export CARDANO_NODE=${inputs.cardano-node.legacyPackages.cardano-node}/bin/cardano-node${pkgs.stdenv.hostPlatform.extensions.executable}
      export CARDANO_NODE_SRC=${../.}
        ";
        convex-devnet.ghcOptions = [ "-Werror" ];
        convex-base.ghcOptions = [ "-Werror" ];
        convex-coin-selection.ghcOptions = [ "-Werror" ];
        convex-mockchain.ghcOptions = [ "-Werror" ];
        convex-node-client.ghcOptions = [ "-Werror" ];
        convex-wallet.ghcOptions = [ "-Werror" ];
        un-ada.ghcOptions = [ "-Werror" ];
      };
    })
  ];


  cabalProject = pkgs.haskell-nix.cabalProject' {
    inherit modules sha256map;
    src = ../.;
    name = "sc-tools";
    compiler-nix-name = "ghc928";
    inputMap = { "https://input-output-hk.github.io/cardano-haskell-packages" = inputs.CHaP; };
    shell.withHoogle = false;
  };


  project = lib.iogx.mkHaskellProject {
    inherit cabalProject;
    shellArgs = repoRoot.nix.shell;
  };

in

project
