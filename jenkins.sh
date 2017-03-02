#!/bin/bash -e

IMAGE_NAME='puppet-test'

runInDocker() {
  cleanUp
  LAST_CONTAINER=`docker run -d $IMAGE_NAME "$@"`
  docker logs -f "$LAST_CONTAINER"
  waitForContainer
}

waitForContainer() {
  return `docker wait $LAST_CONTAINER`
}

cleanUp() {
  if [ -n "$LAST_CONTAINER" ]; then
    docker rm $LAST_CONTAINER > /dev/null
    unset LAST_CONTAINER
  fi
}

copyOut() {
  for f in "$@"; do
    docker cp $LAST_CONTAINER:"/src/$f" "$f"
  done
}

rm -f Gemfile.lock  # can screw up ruby env in container

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
copyOut rspec.xml

cleanUp

echo "-----"
echo "Running smoke tests"
echo "-----"
./smoketest.sh
