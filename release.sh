#!/bin/bash -e
# Releases this Puppet module to the Puppet Forge

docker build -t puppet-pdk -f Dockerfile.pdk .

summon docker run --rm -t \
  -v $PWD:/conjur \
  -w /conjur \
  --env-file @SUMMONENVFILE \
  puppet-pdk \
  bash -ec """
    pdk release --skip-documentation --skip-changelog --force
  """
