{ lib, ... }:
let
  volumes = [ "pab" "node" "index" ];
in
{
  services.nomad.client.host_volume = map
    (vol: {
      "${vol}" = {
        path = "/var/lib/nomad-volumes/${vol}";
        read_only = false;
      };
    })
    volumes;

  system.activationScripts.nomad-host-volumes = lib.pipe volumes [
    (map (vol: ''
      mkdir -p /var/lib/nomad-volumes/${vol}
      chown nobody:nogroup /var/lib/nomad-volumes/${vol}
    ''))
    (builtins.concatStringsSep "\n")
  ];
}
