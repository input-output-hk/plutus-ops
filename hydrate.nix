{ terralib, ... }:

let

  inherit (terralib) var id;
  c = "create";
  r = "read";
  u = "update";
  d = "delete";
  l = "list";
  s = "sudo";

  secretsFolder = "encrypted";
  starttimeSecretsPath = "kv/nomad-cluster";
  runtimeSecretsPath = "runtime";
in
{
  # cluster level
  # --------------
  tf.hydrate.configuration = {
    locals.policies = {
      vault.developer.path."kv/*".capabilities = [ c r u d l ];
      consul.developer = {
        service_prefix."plutus-*" = {
          policy = "write";
          intentions = "write";
        };
      };
      nomad.admin.namespace."*".policy = "write";
      nomad.developer = {
        agent.policy = "read";
        quota.policy = "read";
        node.policy = "read";
        hostVolume."*".policy = "read";
        namespace."*" = {
          policy = "write";
          capabilities = [
            "submit-job"
            "dispatch-job"
            "read-logs"
            "alloc-exec"
            "alloc-node-exec"
            "alloc-lifecycle"
          ];
        };
      };
    };
  };
}
