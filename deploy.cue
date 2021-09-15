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
		#plutusRev:     =~"^\(hex){40}$"
		#flakes: [string]: types.#flake

		#flakes: {
			webGhcServer:                =~flakePath | *"github:input-output-hk/plutus?rev=\(#plutusRev)#web-ghc-server-entrypoint"
			"plutus-playground-server":  =~flakePath | *"github:input-output-hk/plutus?rev=\(#plutusRev)#plutus-playground-server-entrypoint"
			"plutus-playground-client":  =~flakePath | *"github:input-output-hk/plutus?rev=\(#plutusRev)#plutus-playground-client-entrypoint"
			"marlowe-playground-server": =~flakePath | *"github:input-output-hk/plutus?rev=\(#plutusRev)#marlowe-playground-server-entrypoint"
			"marlowe-playground-client": =~flakePath | *"github:input-output-hk/plutus?rev=\(#plutusRev)#marlowe-playground-client-entrypoint"
			marloweRun:                  =~flakePath | *"github:input-output-hk/plutus?rev=\(#plutusRev)#marlowe-run-entrypoint"
			marloweWebsite:              =~flakePath | *"github:input-output-hk/plutus?rev=\(#plutusRev)#marlowe-website-entrypoint"
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
	#portBase: uint

	"web-ghc-server": jobDef.#WebGhcServerJob & {
		#domain: "web-ghc-\(#namespace).\(fqdn)"
		#port: #portBase
	}
	"plutus-playground": jobDef.#PlutusPlaygroundJob & {
		#domain:      "plutus-playground-\(#namespace).\(fqdn)"
		#variant:     "plutus"
		#clientPort:  #portBase + 1
		#serverPort:  #portBase + 2
	}
	"marlowe-playground": jobDef.#PlutusPlaygroundJob & {
		#domain:      "marlowe-playground-\(#namespace).\(fqdn)"
		#variant:     "marlowe"
		#clientPort:  #portBase + 3
		#serverPort:  #portBase + 4
	}
	"marlowe-website": jobDef.#MarloweWebsiteJob & {
		#domain:      "marlowe-website-\(#namespace).\(fqdn)"
		#port: #portBase + 5
	}
	"marlowe-run": jobDef.#MarloweRunJob & {
		#domain:      "marlowe-run-\(#namespace).\(fqdn)"
		#portRangeBase:  #portBase + 6
	}
}

#namespaces: Namespace

#namespaces: {
	"production": {
		vars: {
			#plutusRev: revisions["production"]
		}
		jobs: #jobs & {
			#namespace: "prod"
			#portBase: 1776
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
