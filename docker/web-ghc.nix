{ debugUtils, writeShellScript, buildLayeredImage, web-ghc }: let
  entrypoint = writeShellScript "web-ghc" ''
    set -exuo pipefail

    exec web-ghc-server webserver -b 0.0.0.0 -p $NOMAD_PORT_web
  '';
in
  {
  web-ghc = buildLayeredImage {
    name = "docker.playground.plutus.iohkdev.io/web-ghc";
    contents = debugUtils ++ [ web-ghc ];
    config.Entrypoint = [ entrypoint ];
  };
}
