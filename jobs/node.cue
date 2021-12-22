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
    }
    count: 1

    volume: "node": types.#stanza.volume & {
      type: "host"
      source: "node"
      read_only: false
    }

    task: "node": tasks.#NodeTask & {
      #stateVolume: "node"
      #flake: #flakes.node
    }
  }
}
