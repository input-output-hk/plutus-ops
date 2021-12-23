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
        #portRangeBase: uint
        #hosts: "`\(#domain)`"
        #testnet: bool

        namespace: string

        type: "service"

        group: server: {
                network: {
                        mode: "host"
                        if ! #testnet {
                                port: "marlowe-run": { static: #portRangeBase }
                                port: "pab-node": { static: #portRangeBase + 1 }
                                port: "pab-chain-index": { static: #portRangeBase + 2 }
                                port: "pab-signing-process": { static: #portRangeBase + 3 }
                                port: "pab-wallet": { static: #portRangeBase + 4 }
                        }
                        if #testnet {
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
                        if #testnet {
                          port:     "pab"
                        }
                        if ! #testnet {
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
                                if #testnet {
                                  port:     "pab"
                                }
                                if ! #testnet {
                                  port:     "marlowe-run"
                                }
                                interval: "10s"
                                path:     "/api/healthcheck"
                                timeout:  "2s"
                        }
                }

                if #testnet {
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

		if #testnet {
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
                    #memory: 2048
                    #cpu: 2000
                    #flake: #flakes.wbe
                  }

                  task: "node": tasks.#NodeTask & {
                    #stateVolume: "node"
                    #cpu: 2000
                    #flake: #flakes.node
                  }

                  task: "chain-index": tasks.#ChainIndexTask & {
                    #stateVolume: "index"
                    #cpu: 2000
                    #flake: #flakes.chainIndex
                  }

                  task: "server": tasks.#SimpleTask & {
                    #memory: 2048
                    #cpu: 2000
                    #flake: #flakes.marloweRunServer
                  }

                }

                task: "marlowe-run": tasks.#SimpleTask & {
                        #flake:     #flakes.marloweRun
                        #namespace: namespace
                        #fqdn: #fqdn
                        if #testnet {
                            #memory: 2048
                        }
                        if ! #testnet {
                            #memory: 8129
                        }
                        #domain: #domain
                        #volumeMount: "pab": types.#stanza.volume_mount & {
                          volume: "pab"
                          destination: "/var/lib/pab"
                        }
                        #extraEnv: {
			  if #testnet {
			    PAB_STATE_DIR: "/var/lib/pab"
			  }
			  if ! #testnet {
                            PORT_RANGE_BASE: "\(#portRangeBase)"
		          }
                        }
                }
        }
}
