inputs: final: prev:
let
  lib = final.lib;
  # Little convenience function helping us to containing the bash
  # madness: forcing our bash scripts to be shellChecked.
  writeBashChecked = final.writers.makeScriptWriter {
    interpreter = "${final.bash}/bin/bash";
    check = final.writers.writeBash "shellcheck-check" ''
      ${final.shellcheck}/bin/shellcheck -x "$1"
    '';
  };
  writeBashBinChecked = name: writeBashChecked "/bin/${name}";
in {
  inherit writeBashChecked writeBashBinChecked;

  checkCue = final.writeShellScriptBin "check_cue.sh" ''
    export PATH="$PATH:${lib.makeBinPath (with final; [ cue ])}"
    cue vet -c
  '';

  devShell = let
    cluster = "plutus-playground";
    domain = final.clusters.${cluster}.proto.config.cluster.domain;
  in final.mkShell {
    # for bitte-cli
    LOG_LEVEL = "debug";

    BITTE_CLUSTER = cluster;
    AWS_PROFILE = "plutus";
    AWS_DEFAULT_REGION = final.clusters.${cluster}.proto.config.cluster.region;
    NOMAD_NAMESPACE = "plutus-playground";

    VAULT_ADDR = "https://vault.${domain}";
    NOMAD_ADDR = "https://nomad.${domain}";
    CONSUL_HTTP_ADDR = "https://consul.${domain}";

    buildInputs = with final; [
      bitte
      scaler-guard
      terraform-with-plugins
      sops
      vault-bin
      openssl
      cfssl
      ripgrep
      nixfmt
      awscli
      nomad
      consul
      consul-template
      direnv
      jq
      fd
      cue
    ];
  };

  # Used for caching
  devShellPath = final.symlinkJoin {
    paths = final.devShell.buildInputs;
    name = "devShell";
  };

  debugUtils = with final; [
    bashInteractive
    coreutils
    curl
    dnsutils
    fd
    gawk
    gnugrep
    iproute
    jq
    lsof
    netcat
    nettools
    procps
    tree
  ];
}
