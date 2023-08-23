#!/bin/bash -e
# Releases this Puppet module to the Puppet Forge

# To ensure this script always executes relative to the repo root
cd "$(dirname "$0")/.."

docker build -t puppet-pdk -f ./ci/Dockerfile.pdk .

summon -f ./ci/secrets.yml \
  docker run \
    --rm -t \
    -v $PWD:/conjur \
    -w /conjur \
    --env-file @SUMMONENVFILE \
    puppet-pdk \
    bash -ec """
      PDK_DISABLE_ANALYTICS=true pdk release --skip-documentation \
                                             --skip-changelog \
                                             --skip-validation \
                                             --forge-token="\$PDK_FORGE_TOKEN" \
                                             --force
    """
