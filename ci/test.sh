#!/bin/bash -e

# To ensure this script always executes relative to the repo root
cd "$(dirname "$0")/.."

if [ ! "${SKIP_VALIDATION}" == "true" ]; then
  docker run --rm \
    -v $PWD:/root \
    -w /root \
    puppet/pdk:latest \
    "validate control-repo,metadata,puppet,yaml"
fi

mkdir -p ./spec/output
docker run --rm \
  -v $PWD:/root \
  -w /root \
  puppet/pdk:latest \
  "test unit --format=junit:./spec/output/rspec.xml --format=text"
