{
  description = "Bitte for Plutus";

  inputs = {
    utils.url = "github:kreisys/flake-utils";
    bitte.url = "github:input-output-hk/bitte/clients-use-vault-agent";
    #bitte.url = "path:/home/clever/iohk/bitte";
    bitte.inputs.bitte-cli.url = "github:input-output-hk/bitte-cli/v0.3.5";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nixpkgs.follows = "bitte/nixpkgs";
    bitte-ci.url = "github:input-output-hk/bitte-ci";
    bitte-ci-frontend.follows = "bitte-ci/bitte-ci-frontend";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
  };

  outputs = { self, nixpkgs, utils, bitte, ... }@inputs:
    utils.lib.simpleFlake {
      nixpkgs = nixpkgs // {
        lib = nixpkgs.lib // {
          # Needed until https://github.com/NixOS/nixpkgs/pull/135794
          composeManyExtensions = exts: final: prev: nixpkgs.lib.composeManyExtensions exts final prev;
        };
      };
      systems = [ "x86_64-linux" ];

      preOverlays = [ bitte ];
      overlay = import ./overlay.nix inputs;

      extraOutputs = let
        hashiStack = bitte.lib.mkHashiStack {
          flake = self // {
            inputs = self.inputs // { inherit (bitte.inputs) terranix; };
          };
          domain = "plutus.aws.iohkdev.io";
        };
      in {
        inherit self inputs;
        inherit (hashiStack)
          clusters nomadJobs nixosConfigurations consulTemplates;
      };

      # simpleFlake ignores devShell if we don't specify this.
      packages = { checkCue }@pkgs: pkgs;

      devShell = { bitteShellCompat, cue }:
        (bitteShellCompat {
          inherit self;
          extraPackages = [ cue ];
          cluster = "plutus-playground";
          profile = "plutus";
          region = "eu-central-1";
          domain = "plutus.aws.iohkdev.io";
        });
    };
}
