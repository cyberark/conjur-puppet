#!/bin/bash -e
# Builds this Puppet module

docker build -t puppet-pdk -f Dockerfile.pdk .

docker run --rm \
  -v $PWD:/conjur -w /conjur \
  puppet-pdk \
  bash -ec 'pdk build --force'
