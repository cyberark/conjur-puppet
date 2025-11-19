#!/bin/bash -e
# Releases this Puppet module to the Puppet Forge

# To ensure this script always executes relative to the repo root
cd "$(dirname "$0")/.."

summon -f ./ci/secrets.yml -- sh -c '
    docker run \
      --rm -t \
      -v "$PWD":/conjur \
      -w /conjur \
      --env PDK_DISABLE_ANALYTICS=true \
      --env PDK_FORGE_TOKEN="$PDK_FORGE_TOKEN" \
      puppet/pdk:latest \
        release --skip-documentation \
                --skip-changelog \
                --skip-validation \
                --forge-token="$PDK_FORGE_TOKEN" \
                --force
  '
