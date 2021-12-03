#!/bin/sh

export NIX_KEY=secrets/nix-secret-key-file

[[ $DIRENV_IN_ENVRC == 1 ]] && exit
[[ $NO_CACHE_UPLOAD == 1 ]] && exit
[[ ! -f $NIX_KEY ]] && exit

set -eux
set -f # disable globbing
export IFS=' '

export AWS_ACCESS_KEY_ID=$(<.direnv/bitte/plutus-playground/tokens/aws.key)
export AWS_SECRET_ACCESS_KEY=$(<./direnv/bitte/plutus-playground/tokens/aws.secret)
# conflicts with the above
unset AWS_PROFILE

echo "Signing paths" $OUT_PATHS
nix store sign --key-file "$NIX_KEY" $OUT_PATHS
echo "Uploading paths" $OUT_PATHS
exec nix copy --to "s3://plutus-ops/infra/binary-cache/?region=eu-central-1" $OUT_PATHS
