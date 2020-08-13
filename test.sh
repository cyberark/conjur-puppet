#!/bin/bash -e

readonly compose_file='docker-compose.test.yml'
export COMPOSE_PROJECT_NAME="conjur-puppet_$(openssl rand -hex 3)"

docker-compose -f "$compose_file" build --pull
docker-compose -f "$compose_file" run --rm test-runner \
  bundle exec rake test
