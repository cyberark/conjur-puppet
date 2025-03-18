#!/bin/bash -e

# To ensure this script always executes relative to the repo root
cd "$(dirname "$0")/.."

docker build -t puppet-pdk -f ./ci/Dockerfile.pdk .

if [ ! "${SKIP_VALIDATION}" == "true" ]; then
  docker run --rm \
    -v $PWD:/root \
    -w /root \
    puppet-pdk \
    bash -ec "
      pdk validate control-repo,metadata,puppet,yaml
    "
fi

mkdir -p ./spec/output
docker run --rm \
  -v $PWD:/root \
  -w /root \
  puppet-pdk \
  bash -ec "
    pdk test unit --format=junit:./spec/output/rspec.xml --format=text
  "
