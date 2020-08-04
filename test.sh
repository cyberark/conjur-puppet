#!/bin/bash -e

readonly compose_file='docker-compose.test.yml'
readonly v6_puppet_gem="~>6.17.0"

echo "Using Puppet v6 ('$v6_puppet_gem') gem for testing"
export PUPPET_VERSION=$v6_puppet_gem
export COMPOSE_PROJECT_NAME="conjur-puppet_$(openssl rand -hex 3)"

docker-compose -f "$compose_file" build --pull
docker-compose -f "$compose_file" run --rm test-runner \
  bundle exec rake test
