#!/bin/bash -e
# Builds this Puppet module

# To ensure this script always executes relative to the repo root
cd "$(dirname "$0")/.."

mkdir -p "./pkg"

docker build -t puppet-pdk -f ./ci/Dockerfile.pdk .

docker run --rm \
  -v $PWD:/conjur -w /conjur \
  puppet-pdk \
  bash -ec "
    pdk build --force
    # Ensure there's a generically named copy of the packaged module. This will allow the
    # packaged module to be more easily referenced in any automation scripts e.g. integration
    # tests.
    cp ./pkg/cyberark-conjur-*.tar.gz ./pkg/cyberark-conjur.tar.gz;
    ls -l pkg/
  "

# Copy the package from the Docker container to the host machine
container_id=$(docker ps -alq)
mkdir -p ./pkg
docker cp "$container_id":/conjur/pkg/cyberark-conjur.tar.gz ./pkg/cyberark-conjur.tar.gz

