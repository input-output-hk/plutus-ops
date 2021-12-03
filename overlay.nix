inputs: final: prev:
let
  inherit (final) lib;
in
{
  checkCue = final.writeShellScriptBin "check_cue.sh" ''
    export PATH="$PATH:${lib.makeBinPath (with final; [ cue ])}"
    cue vet -c
  '';

  build-dev-env = final.callPackage
    ({ nix, runCommandNoCC }:
      let
        getEnvSh = runCommandNoCC "get-env.sh" { inherit (nix) src; } ''
          unpackFile $src
          install -m644 */src/nix/get-env.sh $out
        '';
      in
      drv: derivation (drv.drvAttrs // {
        name = "${drv.drvAttrs.name}-env";
        args = [ getEnvSh ];
      }))
    {
      nix = final.nixFlakes;
    };
}
