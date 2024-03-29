package jobs

import (
        "github.com/input-output-hk/plutus-ops/pkg/schemas/nomad:types"
        "github.com/input-output-hk/plutus-ops/pkg/jobs/tasks:tasks"
)

#MarloweRunJob: types.#stanza.job & {
        #domain:         string
        #fqdn:           string
        #flakes: [string]: types.#flake
        #hosts:          string
        #rateLimit: {
                average: uint
                burst:   uint
                period:  types.#duration
        }
        #portRangeBase: *null | uint
        #hosts: "`\(#domain)`"
        #useTestnet: bool

        namespace: string

        type: "service"

        constraints: [{
                attribute: "${node.class}",
                if ! #useTestnet {
                        value: "client"
                }
                if #useTestnet {
                        value: "client_highmem"
                }
        }]

        group: server: {
                network: {
                        mode: "host"
                        if ! #useTestnet {
                                port: "marlowe-run": { static: #portRangeBase }
                                port: "pab-node": { static: #portRangeBase + 1 }
                                port: "pab-chain-index": { static: #portRangeBase + 2 }
                                port: "pab-signing-process": { static: #portRangeBase + 3 }
                                port: "pab-wallet": { static: #portRangeBase + 4 }
                        }
                        if #useTestnet {
                                port: "pab": {}
                                port: "node": {}
                                port: "wbe": {}
                                port: "index": {}
                                port: "run": {}
                        }
                }
                count: 1

                service: "\(namespace)-marlowe-run": {
                        address_mode: "host"
                        if #useTestnet {
                          port:     "pab"
                        }
                        if ! #useTestnet {
                          port:     "marlowe-run"
                        }

                        tags: [
                                namespace,
                                "ingress",
                                "traefik.enable=true",
                                "traefik.http.routers.\(namespace)-marlowe-run.rule=Host(\(#hosts))",
                                "traefik.http.routers.\(namespace)-marlowe-run.entrypoints=https",
                                "traefik.http.routers.\(namespace)-marlowe-run.tls=true",
                                "traefik.http.routers.\(namespace)-marlowe-run.middlewares=\(namespace)-marlowe-run-ratelimit@consulcatalog",
                                "traefik.http.middlewares.\(namespace)-marlowe-run-ratelimit.ratelimit.average=\(#rateLimit.average)",
                                "traefik.http.middlewares.\(namespace)-marlowe-run-ratelimit.ratelimit.burst=\(#rateLimit.burst)",
                                "traefik.http.middlewares.\(namespace)-marlowe-run-ratelimit.ratelimit.period=\(#rateLimit.period)",
                                "traefik.http.routers.\(namespace)-marlowe-run.middlewares=\(namespace)-marlowe-run-stripprefix@consulcatalog",
                                "traefik.http.middlewares.\(namespace)-marlowe-run-stripprefix.stripprefix.prefixes=/pab"
                        ]

                        check: "health": {
                                type:     "http"
                                if #useTestnet {
                                  port:     "pab"
                                }
                                if ! #useTestnet {
                                  port:     "marlowe-run"
                                }
                                interval: "1m"
                                path:     "/api/healthcheck"
                                timeout:  "20s"
                        }
                }

                if #useTestnet {
                  service: "\(namespace)-marlowe-run-server": {
                        address_mode: "host"
                        port:  "run"

                        tags: [
                                namespace,
                                "ingress",
                                "traefik.enable=true",
                                "traefik.http.routers.\(namespace)-marlowe-run-server.rule=Host(\(#hosts)) && PathPrefix(`/api`)",
                                "traefik.http.routers.\(namespace)-marlowe-run-server.entrypoints=https",
                                "traefik.http.routers.\(namespace)-marlowe-run-server.tls=true",
                                "traefik.http.routers.\(namespace)-marlowe-run-server.middlewares=\(namespace)-marlowe-run-server-ratelimit@consulcatalog",
                                "traefik.http.middlewares.\(namespace)-marlowe-run-server-ratelimit.ratelimit.average=\(#rateLimit.average)",
                                "traefik.http.middlewares.\(namespace)-marlowe-run-server-ratelimit.ratelimit.burst=\(#rateLimit.burst)",
                                "traefik.http.middlewares.\(namespace)-marlowe-run-server-ratelimit.ratelimit.period=\(#rateLimit.period)",
                          ]
                  }
                }

                volume: "pab": types.#stanza.volume & {
                  type:       "host"
                  source:     "pab"
                  read_only:  false
                }

                if #useTestnet {
                  volume: "node": types.#stanza.volume & {
                    type: "host"
                    source: "node"
                    read_only: false
                  }

                  volume: "index": types.#stanza.volume & {
                    type: "host"
                    source: "index"
                    read_only: false
                  }

                  task: "wbe": tasks.#SimpleTask & {
                    #memory: 2000
                    #cpu: 2000
                    #flake: #flakes.wbe
                  }

                  task: "node": tasks.#NodeTask & {
                    #stateVolume: "node"
                    #cpu: 2000
                    #flake: #flakes.node
                    #namespace: namespace
                  }

                  task: "chain-index": tasks.#ChainIndexTask & {
                    #stateVolume: "index"
                    #cpu: 2000
                    #flake: #flakes.chainIndex
                    #namespace: namespace
                  }

                  task: "server": tasks.#SimpleTask & {
                    #memory: 1000
                    #cpu: 2000
                    #flake: #flakes.marloweRunServer
                  }

                }

                task: promtail: tasks.#Promtail

                task: "marlowe-run": tasks.#SimpleTask & {
                        #flake:     #flakes.marloweRun
                        #namespace: namespace
                        #fqdn: #fqdn
                        if ! #useTestnet {
                          #memory: 4096
                        }
                        if #useTestnet {
                          #memory: 24000
                        }
                        #domain: #domain
                        #volumeMount: "pab": types.#stanza.volume_mount & {
                          volume: "pab"
                          destination: "/var/lib/pab"
                        }
                        #extraEnv: {
                          PAB_STATE_DIR: "/var/lib/pab/\(#namespace)"
                          if ! #useTestnet {
                            PORT_RANGE_BASE: "\(#portRangeBase)"
                          }
                        }
                }
        }
}
