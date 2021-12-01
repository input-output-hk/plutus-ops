inputs: final: prev:
let
  inherit (final) lib;
in {
  checkCue = final.writeShellScriptBin "check_cue.sh" ''
    export PATH="$PATH:${lib.makeBinPath (with final; [ cue ])}"
    cue vet -c
  '';
}
