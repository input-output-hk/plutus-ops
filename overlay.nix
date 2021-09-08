inputs: final: prev:
let
  inherit (final) lib;
in {
  checkCue = final.writeShellScriptBin "check_cue.sh" ''
    export PATH="$PATH:${lib.makeBinPath (with final; [ cue ])}"
    cue vet -c
  '';

  build-dev-env = final.callPackage ({ nix, runCommandNoCC }: let
    getEnvSh = runCommandNoCC "get-env.sh" { inherit (nix) src; } ''
      unpackFile $src
      install -m644 */src/nix/get-env.sh $out
    '';
  in drv: derivation (drv.drvAttrs // {
    name = "${drv.drvAttrs.name}-env";
    args = [ getEnvSh ];
  })) {
    nix = final.nixFlakes;
  };

  devShell = final.bitteShellCompat {
    inherit (inputs) self;
    extraPackages = [ final.cue ];
    cluster = "plutus-playground";
    profile = "plutus";
    region = "eu-central-1";
    domain = "plutus.aws.iohkdev.io";
  };

  devShellEnv = final.build-dev-env final.devShell;
}
