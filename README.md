# Plutus deployment details

The Plutus deployment consists of several environments containing various combinations of Plutus components

## Components

- web-ghc: An HTTP frontend to the GHC compiler with appropriate modules for compiling code from the playgrounds. Shouldn't be publicly accessible, but currently is
- plutus-playground: Web app to write, compile, and simulate simple Plutus programs. Uses web-ghc for compilation.
- marlowe-playground: Web app to write, compile, and simulate Marlowe contracts. Uses web-ghc for compilation.
- marlowe-run: Web frontend to run and interact with Marlowe contracts. Currently includes a mock node, wallet server, etc. in the backend.
- marlowe-website: Static homepage for Marlowe

## Variants

There are two general variants of the system contained in different envrionments:

- plutus: Includes plutus-playground and web-ghc with Plutus modules
- marlowe: Includes marlowe-website, marlowe-run, marlowe-playground, and web-ghc with Plutus and Marlowe modules.

## Environments

There are 4 permanent environments currently deployed:

- production: Marlowe variant. marlowe-website pulled from https://github.com/input-output-hk/marlowe-website/tree/production , other components pulled from https://github.com/input-output-hk/marlowe-cardano/tree/production

  - [Marlowe website](https://marlowe-finance.io)
  - [Marlowe run](https://run.marlowe-finance.io)
  - [Marlowe playground](https://play.marlowe-finance.io)

- staging: Marlowe variant. marlowe-website pulled from https://github.com/input-output-hk/marlowe-website/tree/master , other components pulled from https://github.com/input-output-hk/marlowe-cardano/tree/main

  - [Marlowe website](https://marlowe-website-staging.plutus.aws.iohkdev.io/)
  - [Marlowe run](https://marlowe-run-staging.plutus.aws.iohkdev.io)
  - [Marlowe playground](https://marlowe-playground-staging.plutus.aws.iohkdev.io)

- plutus-production. Plutus variant. Components pulled from the latest tag in the format `vYYYY-MM-DD` from https://github.com/input-output-hk/plutus-apps/

  - [Plutus playground](https://playground.plutus.iohkdev.io/)

- plutus-staging. Plutus variant. Components pulled from https://github.com/input-output-hk/plutus-apps/tree/main

  - [Plutus playground](https://plutus-playground-plutus-apps-staging.plutus.aws.iohkdev.io/)

### Ad hoc environments

The process to create a new environment for ad hoc testing is currently somewhat involved. You'll probably need help from @shlevy or @input-output-hk/devops for now.

First, create a PR against this repo:

1. Create a new directory under `revisions`, copied from `staging` if this is a Marlowe environment or `plutusStaging` if it's a Plutus environment, named for your environment
2. Update the cue file(s) in your new directory with the appropriate revisions of the relevant repositories
3. Update the cue file(s) in your new directory, changing the package name to your new directory name
4. Add an entry in `revisions/combined.cue` for your environment
5. Add a new entry to the `#namespaces` definition in `deploy.cue`, copied either from the `staging` entry or the `plutus-staging` entry, updating the following fields:

   - `#revs`: Use your own environment name
   - `#namespace`: Use a unique namespace name, which will become part of the URL for your deployment

     Plutus playground: https://plutus-playground-NAMESPACE.plutus.aws.iohkdev.io/
     Marlowe playground: https://marlowe-playground-NAMESPACE.plutus.aws.iohkdev.io/
     Marlowe website: https://marlowe-website-NAMESPACE.plutus.aws.iohkdev.io/
     Marlowe run: https://marlowe-run-NAMESPACE.plutus.aws.iohkdev.io/

   - `#portBase`: This should be 11 higher than the number in the previous entry

6. Add a new entry and description under `services.nomad.namespaces` in `clusters/plutus/playground/default.nix`

If you're OK with waiting for PRs to update your environment, you can simply update the `revisions` files you've added in a PR. Otherwise, you can update autodeployment in the relevant repo(s) (marlowe-cardano, marlowe-website, plutus-apps):

1. In `.github/workflows/deploy.yml`, add a branch under `on:`→`push:`→`branches:`
2. In `scripts/deploy-bitte`, search for `ref_env_mapping` and add a mapping from your branch name to the environment name

# Automated deployment

This section describes how the basic bitte deployment was modified to support automated deployments. This should be improved and included in bitte proper.

- Multiple environments in a single deployment were supported by having multiple namespaces use the `#jobs` entry in `deploy.cue`, allowing port numbers to be shifted (to maximize utilization) and modifying subdomains per-namespace
- For each environment, created a directory under `revisions` with the git revisions of the relevant upstream flakes
- Added `.github/workflows/deploy.yml` to redeploy changed jobs (and, in principle, infra and systems) upon each commit to master.

In each upstream repo (e.g. https://github.com/input-output-hk/marlowe-cardano ), set up automation to update the appropriate revisions files at the appropriate times:

- Added `.github/workflows/deploy.yml` to call `deploy-bitte` with the appropriate environment upon push to the right branches
- Added `scripts/deploy-bitte` script to find the environment corresponding to the pushed branch and push a commit to `plutus-ops` updating the relevant `revisions` file.

# Bootstrapping a Bitte Cluster

## Resource Preparation

- Determine whether the root AWS account, an existing organization under the root account, or a new organization will be used to host the new cluster infrastructure (3 or 5 core nodes plus a monitoring node). Create a new organization if needed. Switch to the desired AWS account or organization before continuing.

- Choose a target region which the infrastructure will be deployed to. This selected region should be used for KMS, S3 and AMI resource preparation

### IAM Preparation

- Ensure users who will be admins have IAM accounts created and are assigned a group with the admin policy and programmatic access

### KMS Preparation

- If a suitable KMS key does not already exist in the selected region, create a new one:
  - Create a customer managed symmetric KMS key (no advanced options or tags required)
- Add the IAM admins and organization role to the KMS key and KMS key usage permissions
- Make note of the full KMS key ARN (`arn:aws:kms:$REGION:$ORG_ID:key/$KEY_ID`)

### S3 Preparation

- If a suitable S3 bucket does not already exist in the selected region, create a new bucket for the cluster
- Ensure that the bucket has public access BLOCKED (NO public access)

### Route53 Domain and DNS Preparation

- Select an existing domain to host the new infra or create a new one.
- To create a new one, one approach if using an organization under a parent organization or the root account which hosts the main DNS zone:
  - Create a new hosted zone in the selected organization which is a sub-domain of a parent organization or root account hosted zone
  - Create an NS record in the parent account pointing to the selected organizations new hosted zone sub-domain NS records

### AMI preparation

- Ensure that a bitte AMI image is available in the selected region
  - If not, copy an available bitte AMI image from another region to the selected region using the EC2 dashboard
  - Switch to the owner account/org of the existing AMI image, if needed, to perform the copy operation
  - The owner of the existing AMI from an originating region can be found by looking at the 12 digits of the backing snapshot
  - Those 12 digits can be used to filter organizations from the "My Organizations" page to locate the AMI owner organization
  - By switching to the owner organization, the AMI can then be copied to a target region without permission errors
  - TODO: document creation of a new AMI image from ops-lib
- Make note of the AMI ID in the selected region

## Standing up the cluster:

### Cluster setup

- Ensure that s3 credentials are set up in `~/.aws/credentials` file for the cluster

  - For systems with nix-daemon, a `/root/.aws/credentials` file may also be required for builds with s3 cache access
  - Optional: Add the cluster s3 bucket to the nix cache
    - A parameter of profile can be appended to the cache string to specify the AWS credentials profile to use (`&profile=$PROFILE`)

- Create a new terraform cloud organization for the cluster

  - Invite other members for the cluster
  - Default settings for the organization are ok are we don't manage source in the cloud

- Create a new repo (ex: infra-ops)
- Copy over skeleton files from a skeleton dir or existing bitte job repo

  - The `encrypted/` and `jobs/` folders should be deleted from any copied skeleton setup as they will be recreated

- In the `clusters/` dir, move the two sub-directories to appropriate names for the new repo, example:

  - `clusters/infra/production/`

- Update the `default.nix` file in the clusters sub-directory, `clusters/infra/production/default.nix` in this example:

  - Add additional `amis` region attributes for auto-scaling instances if needed
  - Update the `kms` key with the full ARN path
  - Update the `domain` with the domain for the new cluster
  - Update the `s3Bucket` name with the s3 bucket for the new cluster
  - Update the `adminNames` with admins that exist for the new cluster
  - Update the `terraformOrganization` to the new organization for the cluster
  - Update the `autoscalingGroups` with new regions and desired capacities as needed
    - Note: regions with less than 3 AZs are not yet supported

- Make the initial encrypted `nix-public-key-file`, `secrets/` and `encrypted/` dirs for the repo with:

```
make secrets/nix-public-key-file
```

- Add all new files (locally) to the git repo. This is required for nix flakes to recognize files

  - Following files and directories do not need to be added:
    - `.direnv/`
    - `cert.config`
    - `config.tf.json`

- Initialize the network config for the new cluster which will create a new `config.tf.json` file:

```
nix run .#clusters.infra-production.tf.network.config
```

- Deploy the terraform network with:

```
bitte terraform network
```

- Deploy the terraform core nodes with:

```
bitte terraform core
```

- Generate the certs for the new cluster with:

```
bitte certs --domain $DOMAIN
```

- Deploy the terraform clients with:

```
bitte terraform clients
```

- Troubleshooting:
  - If nix fails due to missing files, check if new files were generated that need to be added for nix flakes to recognize them
  - If consul services, such as nomad, fail on the new core nodes, try restarting the failed services

## Cluster Jobs:

- Nomad job definitions exist in the `jobs/` folder
- Other Bitte cluster repos and their job definitions can be used as templates for new jobs
