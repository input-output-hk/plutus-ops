{ mkNomadJob, dockerImages }:
let namespace = "plutus-dev";
in {
  "${namespace}-playground" = mkNomadJob "plutus" {
    datacenters = [ "eu-central-1" "us-east-2" ];
    type = "service";
    inherit namespace;

    update = {
      maxParallel = 1;
      healthCheck = "checks";
      minHealthyTime = "1m";
      healthyDeadline = "5m";
      progressDeadline = "10m";
      autoRevert = true;
      autoPromote = true;
      canary = 1;
      stagger = "1m";
    };

    taskGroups = {
      plutus = {
        count = 2;

        networks = [{
          mode = "bridge";
          ports = { web.to = 8080; };
        }];

        services."${namespace}-ghc" = {
          addressMode = "host";
          portLabel = "web";
          task = "ghc";
          tags = [ "ingress" namespace ];
          meta = {
            ingressMode = "http";
            ingressBind = "*:443";
            ingressServer = "_${namespace}-ghc._tcp.service.consul";
            ingressHost = "ghc.playground.plutus.iohkdev.io";
          };
        };

        tasks.ghc = {
          driver = "docker";

          restartPolicy = {
            interval = "15m";
            attempts = 5;
            delay = "1m";
            mode = "delay";
          };

          resources = {
            cpu = 100; # mhz
            memoryMB = 256;
          };

          config = {
            image = dockerImages.web-ghc.id;
            ports = [ "web" ];
            labels = [{
              inherit namespace;
              name = "ghc";
              imageTag = dockerImages.web-ghc.image.imageTag;
            }];

            logging = {
              type = "journald";
              config = [{
                tag = "${namespace}-ghc";
                labels = "name,namespace,imageTag";
              }];
            };
          };
        };
      };
    };
  };
}
