#!/bin/bash -e

readonly compose_file='docker-compose.test.yml'

docker-compose -f "$compose_file" build --pull
docker-compose -f "$compose_file" run --rm test-runner \
  bundle exec rake test
