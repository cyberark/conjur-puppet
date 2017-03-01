#!/bin/bash -e
# Releases this Puppet module to the Puppet Forge

IMAGE_NAME='puppet-test'

docker build -t $IMAGE_NAME .

summon docker run --env-file @SUMMONENVFILE --rm -i $IMAGE_NAME bundle exec rake release
