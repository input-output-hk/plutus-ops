package tasks

import (
  "github.com/input-output-hk/plutus-ops/pkg/schemas/nomad:types"
)

#NodeTask: #SimpleTask & {
  #stateVolume: string

  #memory: 2048

  #namespace: string

  let stateDir = "/var/lib/cardano-node"

  #volumeMount: "node": types.#stanza.volume_mount & {
    volume: #stateVolume
    destination: stateDir
  }

  #extraEnv: {
    NODE_STATE_DIR: "\(stateDir)/\(#namespace)"
  }

}
