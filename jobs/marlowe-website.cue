package jobs

import (
	"github.com/input-output-hk/plutus-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/plutus-ops/pkg/jobs/tasks:tasks"
)

#MarloweWebsiteJob: types.#stanza.job & {
	#domain:         string
	#fqdn:           string
	#flakes: [string]: types.#flake
	#hosts:          string
	#rateLimit: {
		average: uint
		burst:   uint
		period:  types.#duration
	}
        #hosts: "`\(#domain)`"
        #port: *null | uint

	namespace: string

	type: "service"

	constraints: [{
		attribute: "${node.class}",
		value: "client"
	}]

	group: server: {
		network: {
			mode: "host"
			port: "marlowe-website": {
				if #port != null {
					static: #port
				}
			}
		}
		count: 1

		service: "\(namespace)-marlowe-website": {
			address_mode: "host"
			port:         "marlowe-website"

			tags: [
				namespace,
				"ingress",
				"traefik.enable=true",
				"traefik.http.routers.\(namespace)-marlowe-website.rule=Host(\(#hosts))",
				"traefik.http.routers.\(namespace)-marlowe-website.entrypoints=https",
				"traefik.http.routers.\(namespace)-marlowe-website.tls=true",
				"traefik.http.routers.\(namespace)-marlowe-website.middlewares=\(namespace)-marlowe-website-ratelimit@consulcatalog",
				"traefik.http.middlewares.\(namespace)-marlowe-website-ratelimit.ratelimit.average=\(#rateLimit.average)",
				"traefik.http.middlewares.\(namespace)-marlowe-website-ratelimit.ratelimit.burst=\(#rateLimit.burst)",
				"traefik.http.middlewares.\(namespace)-marlowe-website-ratelimit.ratelimit.period=\(#rateLimit.period)",
			]

			check: "health": {
				type:     "http"
				port:     "marlowe-website"
				interval: "10s"
				path:     "/index.html"
				timeout:  "2s"
			}
		}

		task: "marlowe-website": tasks.#SimpleTask & {
			#flake:     #flakes.marloweWebsite
			#namespace: namespace
			#fqdn: #fqdn
			#memory: 32
			#domain: #domain
			if #port != null {
				#extraEnv: {
					PORT: "\(#port)"
				}
			}
		}
	}
}
