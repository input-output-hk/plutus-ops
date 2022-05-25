package bitte

import (
	"github.com/input-output-hk/plutus-ops/pkg/schemas/nomad:types"
	jobDef "github.com/input-output-hk/plutus-ops/pkg/jobs:jobs"
	"github.com/input-output-hk/plutus-ops/pkg/revisions:revisions"
	"list"
)

let fqdn = "plutus.aws.iohkdev.io"

Namespace: [Name=_]: {
	vars: {
		let hex = "[0-9a-f]"
		let seg = "[-a-zA-Z0-9]"
		let datacenter = "eu-central-1"
		let flakePath = "github:input-output-hk/\(seg)+\\?rev=\(hex){40}#\(seg)"

		datacenters: list.MinItems(1) | [...datacenter] | *[ "eu-central-1"]
		namespace:   Name
		#domain:     string
		#fqdn:       fqdn
		#revs: [string]: =~"^\(hex){40}$"
		#variant:    string
		#testnet: string | *null
		#useTestnet: #testnet != null
		#flakes: [string]: types.#flake

		#flakes: {
			if #variant == "plutus" {
				webGhcServer:                =~flakePath | *"github:input-output-hk/plutus-apps?rev=\(#revs.plutus)#web-ghc-server-entrypoint"
				"plutus-playground-server":  =~flakePath | *"github:input-output-hk/plutus-apps?rev=\(#revs.plutus)#plutus-playground-server-entrypoint"
				"plutus-playground-client":  =~flakePath | *"github:input-output-hk/plutus-apps?rev=\(#revs.plutus)#plutus-playground-client-entrypoint"
			}
			if #variant == "marlowe" {
				webGhcServer:                =~flakePath | *"github:input-output-hk/marlowe-cardano?rev=\(*#revs.marlowePlay | #revs.marlowe)#web-ghc-server-entrypoint"
				"marlowe-playground-server": =~flakePath | *"github:input-output-hk/marlowe-cardano?rev=\(*#revs.marlowePlay | #revs.marlowe)#marlowe-playground-server-entrypoint"
				"marlowe-playground-client": =~flakePath | *"github:input-output-hk/marlowe-cardano?rev=\(*#revs.marlowePlay | #revs.marlowe)#marlowe-playground-client-entrypoint"

				marloweWebsite:              =~flakePath | *"github:input-output-hk/marlowe-website?rev=\(#revs.marloweWebsite)#marlowe-website-entrypoint"
				if #testnet == null {
					marloweRun:          =~flakePath | *"github:input-output-hk/marlowe-cardano?rev=\(#revs.marlowe)#marlowe-run-entrypoint"
				}
				if #testnet != null {
					// Temporary until all testnet branches are updated to use the prefix
					let prefix = {
						if #testnet == "testnet-dev" {
							""
						}
						if #testnet != "testnet-dev" {
							"\(#testnet)."
						}
					}

					marloweRun:          =~flakePath | *"github:input-output-hk/marlowe-cardano?rev=\(#revs.marlowe)#\(prefix)marlowe-run-entrypoint"
					node:                =~flakePath | *"github:input-output-hk/marlowe-cardano?rev=\(#revs.marlowe)#\(prefix)node"
					wbe:                 =~flakePath | *"github:input-output-hk/marlowe-cardano?rev=\(#revs.marlowe)#\(prefix)wbe"
					chainIndex:          =~flakePath | *"github:input-output-hk/marlowe-cardano?rev=\(#revs.marlowe)#\(prefix)chain-index"
					marloweRunServer:    =~flakePath | *"github:input-output-hk/marlowe-cardano?rev=\(#revs.marlowe)#\(prefix)marlowe-run-server-entrypoint"
				}
			}
		}

		#rateLimit: {
			average: uint | *100
			burst:   uint | *250
			period:  types.#duration | *"1m"
		}
	}
	jobs: [string]: types.#stanza.job
}

#jobs: {
	#namespace: string
	#portBase: *null | uint
	#variant: string

	"web-ghc-server": jobDef.#WebGhcServerJob & {
		#domain: "web-ghc-\(#namespace).\(fqdn)"
		if #portBase != null {
			#port: #portBase
		}
	}
	if #variant == "plutus" {
		"plutus-playground": jobDef.#PlutusPlaygroundJob & {
			if #namespace == "plutus-apps-prod" {
				#domain:      "playground.plutus.iohkdev.io"
			}
			if #namespace != "plutus-apps-prod" {
				#domain:      "plutus-playground-\(#namespace).\(fqdn)"
			}
			#domainNS:    #namespace
			#variant:     "plutus"
			if #portBase != null {
				#clientPort:  #portBase + 1
				#serverPort:  #portBase + 2
			}
		}
	}
	if #variant == "marlowe" {
		"marlowe-playground": jobDef.#PlutusPlaygroundJob & {
			if #namespace == "prod" {
				#domain:      "play.marlowe-finance.io"
			}
			if #namespace != "prod" {
				#domain:      "marlowe-playground-\(#namespace).\(fqdn)"
			}
			#domainNS:    #namespace
			#variant:     "marlowe"
			if #portBase != null {
				#clientPort:  #portBase + 3
				#serverPort:  #portBase + 4
			}
		}
		"marlowe-website": jobDef.#MarloweWebsiteJob & {
			if #namespace == "prod" {
				#domain:      "marlowe-finance.io"
			}
			if #namespace != "prod" {
				#domain:      "marlowe-website-\(#namespace).\(fqdn)"
			}
			if #portBase != null {
				#port: #portBase + 5
			}
		}
		"marlowe-run": jobDef.#MarloweRunJob & {
			if #namespace == "prod" {
				#domain:      "run.marlowe-finance.io"
			}
			if #namespace != "prod" {
				#domain:      "marlowe-run-\(#namespace).\(fqdn)"
			}
			if #portBase != null {
				#portRangeBase:  #portBase + 6
			}
		}
	}
}

#namespaces: Namespace

#namespaces: {
	"production": {
		vars: {
			#revs: revisions["production"]
			#variant: "marlowe"
		}
		jobs: #jobs & {
			#namespace: "prod"
			#portBase: 1776
			#variant: "marlowe"
		}

	}
	"staging": {
		vars: {
			#revs: revisions["staging"]
			#variant: "marlowe"
			#testnet: "testnet-dev"
		}
		jobs: #jobs & {
			#namespace: "staging"
			#variant: "marlowe"
		}
	}

	"currentSprintMarlowe": {
		vars: {
			#revs: revisions["currentSprintMarlowe"]
			#variant: "marlowe"
			#testnet: "testnet-dev"
		}
		jobs: #jobs & {
			#namespace: "currentSprintMarlowe"
			#variant: "marlowe"
		}
	}

	"marlowe-pioneers": {
		vars: {
			#revs: revisions["marlowePioneers"]
			#variant: "marlowe"
			#testnet: "testnet-pioneers"
		}
		jobs: #jobs & {
			#namespace: "marlowe-pioneers"
			#variant: "marlowe"
		}
	}

	"plutus-production": {
		vars: {
			#revs: revisions["plutusProduction"]
			#variant: "plutus"
		}
		jobs: #jobs & {
			#namespace: "plutus-apps-prod"
			#portBase: 1798
			#variant: "plutus"
		}

	}
	"plutus-staging": {
		vars: {
			#revs: revisions["plutusStaging"]
			#variant: "plutus"
		}
		jobs: #jobs & {
			#namespace: "plutus-apps-staging"
			#variant: "plutus"
		}

	}

	"hernan": {
		vars: {
			#revs: revisions["hernan"]
			#variant: "marlowe"
			#testnet: "testnet-dev"
		}
		jobs: #jobs & {
			#namespace: "hernan"
			#variant: "marlowe"
		}
	}

	"pablo": {
		vars: {
			#revs: revisions["pablo"]
			#variant: "marlowe"
		}
		jobs: #jobs & {
			#namespace: "pablo"
			#portBase: 1831
			#variant: "marlowe"
		}

	}
}

for nsName, nsValue in #namespaces {
	rendered: "\(nsName)": {
		for jName, jValue in nsValue.jobs {
			"\(jName)": Job: types.#toJson & {
				#jobName: jName
				#job:     jValue & nsValue.vars
			}
		}
	}
}

for nsName, nsValue in #namespaces {
	// output is alphabetical, so better errors show at the end.
	zchecks: "\(nsName)": {
		for jName, jValue in nsValue.jobs {
			"\(jName)": jValue & nsValue.vars
		}
	}
}
