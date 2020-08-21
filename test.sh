#!/bin/bash -e

if [ ! "${SKIP_VALIDATION}" == "true" ]; then
  echo "Running validations..."
  docker run --rm \
    -v $PWD:/root \
    -w /root \
    puppet/pdk validate control-repo,metadata,puppet,ruby,yaml
fi

echo "Running specs..."
mkdir -p ./spec/output
docker run --rm \
  -v $PWD:/root \
  -w /root \
  puppet/pdk test unit --format=junit:./spec/output/rspec.xml --format=text
echo "Tests complete!"
