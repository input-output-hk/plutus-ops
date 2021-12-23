package jobs

import (
  "github.com/input-output-hk/plutus-ops/pkg/schemas/nomad:types"
  "github.com/input-output-hk/plutus-ops/pkg/jobs/tasks:tasks"
)

#NodeJob: types.#stanza.job & {
  #flakes: [string]: types.#flake

  type: "service"

  group: node: {
    network: {
      mode: "host"
      port: "node": {}
      port: "wbe": {}
      port: "index": {}
    }
    count: 1

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
  }
}
