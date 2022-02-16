{
  nixConfig.extra-substituters = "s3://plutus-ops/infra/binary-cache/?region=eu-central-1";
  nixConfig.extra-trusted-public-keys = "plutus-playground-0:7YXf8u1WZSqbwbfj7+8UwwItfiv3BeUk6Rbi4RT0QAs=";
  # nixConfig.post-build-hook = ./upload-to-cache.sh;
  nixConfig.allow-import-from-derivation = "true";

  description = "Bitte for Plutus";

  inputs = {
    utils.url = "github:kreisys/flake-utils";
    bitte.url = "github:input-output-hk/bitte/21.12.10";
    nixpkgs.follows = "bitte/nixpkgs";
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
          hydrateModule =
            import ./hydrate.nix { inherit (bitte.lib) terralib; };
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
      legacyPackages.${system} = pkgs;

      devShell.${system} = let name = "plutus-playground"; in
        pkgs.bitteShell {
          inherit self domain;
          profile = name;
          cluster = name;
          namespace = "production";
          extraPackages = [ pkgs.cue ];
        };

      devShellEnv.${system} = pkgs.build-dev-env self.devShell.${system};
    } // bitteStack // {
      hydraJobs = bitteStack.hydraJobs // {
        ${system} = bitteStack.hydraJobs.${system} // {
          devShellEnv = self.devShellEnv.${system};
        };
      };
    };
}
