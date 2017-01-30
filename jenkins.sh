#!/bin/bash -e

IMAGE_NAME='puppet-test'

runInDocker() {
  docker run --rm -v $PWD:/src $IMAGE_NAME "$@"
}

echo "Building Docker image for testing"
echo "-----"
docker build -t $IMAGE_NAME .

echo "-----"
echo "Validating syntax"
echo "-----"
runInDocker bundle exec rake validate

echo "-----"
echo "Linting module"
echo "-----"
runInDocker bundle exec rake lint

echo "-----"
echo "Testing module"
echo "-----"
runInDocker bundle exec rake spec
