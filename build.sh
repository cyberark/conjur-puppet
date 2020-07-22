#!/bin/bash -e
# Builds this Puppet module

docker build -t puppet-test .

docker run --rm \
  -v $PWD:/conjur -w /conjur \
  puppet-test \
  bash -c 'bundle --quiet && bundle exec rake build'
