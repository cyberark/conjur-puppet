#!/bin/bash -e

# To ensure this script always executes relative to the repo root
cd "$(dirname "$0")/.."

docker build -t puppet-pdk -f ./ci/Dockerfile.pdk .

if [ ! "${SKIP_VALIDATION}" == "true" ]; then
  echo "Running validations..."
  docker run --rm \
    -v $PWD:/root \
    -w /root \
    puppet-pdk \
    bash -ec "
      pdk validate control-repo,metadata,puppet,ruby,yaml
    "
fi

echo "Running specs..."
mkdir -p ./spec/output
docker run --rm \
  -v $PWD:/root \
  -w /root \
  puppet-pdk \
  bash -ec "
    pdk test unit --format=junit:./spec/output/rspec.xml --format=text
  "

echo "Tests complete!"
