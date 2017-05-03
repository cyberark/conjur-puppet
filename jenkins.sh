#!/bin/bash -e

rm -f Gemfile.lock

docker build --build-arg PUPPET_VERSION="${PUPPET_VERSION}" -t puppet-test .

docker run --rm \
  -v $PWD:/conjur \
  puppet-test \
  bash -c 'umask 0000; bundle --quiet && bundle exec rake test'

#
# echo "-----"
# echo "Running smoke tests"
# echo "-----"
# ./smoketest.sh
