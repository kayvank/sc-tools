{ repoRoot, inputs, pkgs, lib, system }:

let

  sha256map = {
    "https://github.com/etiennejf/plutus-apps"."517157a10a8aac25272ac6293b5c92acc422e49c" = "sha256-U5/FIcp6b/8I6LzdUfLH19jqOMFaOwHqssCD5h5cnWw=";
    "https://github.com/input-output-hk/cardano-wallet"."18a931648550246695c790578d4a55ee2f10463e" = "0i40hp1mdbljjcj4pn3n6zahblkb2jmpm8l4wnb36bya1pzf66fx";
    "https://github.com/input-output-hk/purescript-bridge"."47a1f11825a0f9445e0f98792f79172efef66c00" = "sha256-/SbnmXrB9Y2rrPd6E79Iu5RDaKAKozIl685HQ4XdQTU=";
    "https://github.com/input-output-hk/servant-purescript"."44e7cacf109f84984cd99cd3faf185d161826963" = "sha256-DH9ISydu5gxvN4xBuoXVv1OhYCaqGOtzWlACdJ0H64I=";
    "https://github.com/input-output-hk/cardano-addresses"."b7273a5d3c21f1a003595ebf1e1f79c28cd72513" = "sha256-91F9+ckA3lBCE4dAVLDnMSpwRLa7zRUEEBYEHv0sOYk=";
    "https://github.com/input-output-hk/cardano-ledger"."c7c63dabdb215ebdaed8b63274965966f2bf408f" = "sha256-zTQbMOGPD1Oodv6VUsfF6NUiXkbN8SWI98W3Atv4wbI=";
    "https://github.com/j-mueller/sc-tools.git"."078221f07950c1a08ef47d0ff11a849610f3c59d" = "1z5pr6ca387pmc2q2j3sjiwarn3g8jm2dwx9yv0yi7acfwma53jl";
    "https://github.com/input-output-hk/quickcheck-dynamic"."42b4f551e8508894121cc4a67612d4a593e9b83b" = "0xj64ygkibwpf99wqr95xlxb8cdgs22la8aa7x8z3mf5rl348rvm";
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
        djed-test.preCheck = "
        export CARDANO_CLI=${config.hsPkgs.cardano-cli.components.exes.cardano-cli}/bin/cardano-cli${pkgs.stdenv.hostPlatform.extensions.executable}
        export CARDANO_NODE=${config.hsPkgs.cardano-node.components.exes.cardano-node}/bin/cardano-node${pkgs.stdenv.hostPlatform.extensions.executable}
        export CARDANO_SUBMIT_API=${config.hsPkgs.cardano-submit-api.components.exes.cardano-submit-api}/bin/cardano-submit-api${pkgs.stdenv.hostPlatform.extensions.executable}
        export CARDANO_NODE_SRC=${../.}
      ";

        djed-onchain.ghcOptions = [ "-Werror" ];
        djed-offchain.ghcOptions = [ "-Werror" ];
        djed-offchain-v2.ghcOptions = [ "-Werror" ];
        djed-pab.ghcOptions = [ "-Werror" ];
        djed-test.ghcOptions = [ "-Werror" ];
        djed-client.ghcOptions = [ "-Werror" ];
        financial-model.ghcOptions = [ "-Werror" ];
        djed-client-types.ghcOptions = [ "-Werror" ];
      };
    })
  ];


  cabalProject = pkgs.haskell-nix.cabalProject' {
    inherit modules sha256map;
    src = ../.;
    name = "stablecoin-plutus";
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
