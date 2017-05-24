#!/bin/bash -e
# Releases this Puppet module to the Puppet Forge

docker build -t puppet-test .

summon docker run --rm -it \
  -v $PWD:/conjur -w /conjur \
  --env-file @SUMMONENVFILE \
  puppet-test \
  bash -c 'bundle --quiet && bundle exec rake release'
