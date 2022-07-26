package jobs

import (
        "github.com/input-output-hk/plutus-ops/pkg/schemas/nomad:types"
        "github.com/input-output-hk/plutus-ops/pkg/jobs/tasks:tasks"
)

#CiNodeJob: types.#stanza.job & {
	#domain:         string
	#flakes: [string]: types.#flake
	#hosts:          string
	#hosts: "`\(#domain)`"

	namespace: string

	type: "service"

	constraints: [{
		attribute: "${node.class}",
		value: "client"
	}]

	group: "ci-node": {
		network: {
			mode: "host"
			port: {
				"node": {},
				"node_socat": {}
			}
		}
		count: 1

		service: "\(namespace)-ci-node": {
			address_mode: "host"
			port:         "node_socat"

			tags: [
				namespace,
				"ingress",
				"traefik.enable=true",
				"traefik.tcp.routers.\(namespace)-ci-node.rule=HostSNI(\(#hosts))",
				"traefik.tcp.routers.\(namespace)-ci-node.entrypoints=https",
				"traefik.tcp.routers.\(namespace)-ci-node.tls.passthrough=true",
			]
		}

		volume: "node": types.#stanza.volume & {
			type: "host"
			source: "node"
			read_only: false
		}

		task: "node": tasks.#NodeTask & {
			#stateVolume: "node"
			#cpu: 2000
			#flake: #flakes.node
			#namespace: namespace
		}

		task: "node_socat": tasks.#SimpleTask & {
			#flake: #flakes.nodeSocat
			#namespace: namespace
			#memory: 32
			#domain: #domain
			#extraEnv: {
				SOCAT_SERVER_CERT: "secrets/server.pem"
				SOCAT_CLIENT_CERT: "secrets/client.crt"
			}
			template: "secrets/server.pem": {
				data: """
				{{with secret "kv/nomad-cluster/\(#namespace)/server"}}
				{{.Data.data.pem}}
				{{end}}
				"""
				change_mode: "restart"
			}
			template: "secrets/client.crt": {
				data: """
				{{with secret "kv/nomad-cluster/\(#namespace)/client"}}
				{{.Data.data.cert}}
				{{end}}
				"""
				change_mode: "restart"
			}
		}
	}
}
