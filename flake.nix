{
  description = "Bitte for Plutus";

  inputs = {
    utils.url = "github:kreisys/flake-utils";
    bitte.url = "github:input-output-hk/bitte";
    cli.url = "github:input-output-hk/bitte-cli";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nixpkgs.follows = "cli/nixpkgs";
    bitte-ci.url = "github:input-output-hk/bitte-ci";
    bitte-ci-frontend.follows = "bitte-ci/bitte-ci-frontend";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
  };

  outputs = { self, nixpkgs, utils, bitte, cli, ... }@inputs:
    utils.lib.simpleFlake {
      nixpkgs = nixpkgs // {
        lib = nixpkgs.lib // {
          # Needed until https://github.com/NixOS/nixpkgs/pull/135794
          composeManyExtensions = exts: final: prev:
            nixpkgs.lib.composeManyExtensions exts final prev;
        };
      };
      systems = [ "x86_64-linux" ];

      preOverlays = [ bitte cli.overlay ];
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
        hydraJobs.x86_64-linux = self.packages.x86_64-linux
          // (builtins.mapAttrs (_: config: config.config.system.build.toplevel)
            self.nixosConfigurations);
      };

      # simpleFlake ignores devShell if we don't specify this.
      packages = { checkCue, devShellEnv }@pkgs: pkgs;

      devShell = { devShell }: devShell;
    };
}
