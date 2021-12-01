{
  description = "Bitte for Plutus";

  inputs = {
    utils.url = "github:kreisys/flake-utils";
    bitte.url = "github:input-output-hk/bitte/fix-all-the-bootstrapping";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nixpkgs.follows = "bitte/nixpkgs";
    bitte-ci.url = "github:input-output-hk/bitte-ci";
    bitte-ci-frontend.follows = "bitte-ci/bitte-ci-frontend";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
  };

  outputs = { self, nixpkgs, utils, bitte, ... }@inputs:
    let

      system = "x86_64-linux";

      overlay = final: prev: (nixpkgs.lib.composeManyExtensions overlays) final prev;
      overlays = [ (import ./overlay.nix inputs) bitte.overlay ];

      domain = "plutus.aws.iohkdev.io";

      bitteStack =
        let stack = bitte.lib.mkBitteStack {
          inherit domain self inputs pkgs;
          clusters = "${self}/clusters";
          deploySshKey = "./secrets/ssh-plutus-playground";
          hydrateModule = { };
        };
        in
        stack // {
          deploy = stack.deploy // { autoRollback = false; };
        };

      pkgs = import nixpkgs {
        inherit overlays system;
        config.allowUnfree = true;
      };

    in
    {
      inherit overlays;
      legacyPackages.${system} = pkgs;

      devShell.${system} = let name = "plutus-playground"; in
        pkgs.bitteShell {
          inherit self domain;
          profile = name;
          cluster = name;
          namespace = "production";
          extraPackages = [ pkgs.cue ];
          nixConfig = ''
            extra-substituters = s3://plutus-ops/infra/binary-cache/?region=eu-central-1
            extra-trusted-public-keys = plutus-playground-0:7YXf8u1WZSqbwbfj7+8UwwItfiv3BeUk6Rbi4RT0QAs=
          '';
        };

    } // bitteStack;
}
