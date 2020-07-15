#!/bin/bash -e

readonly compose_file='docker-compose.test.yml'
readonly v5_puppet_gem="~> 5.5.21"
readonly v5_output_xml="spec/output/rspec_puppet5.xml"

if [ "$#" -gt 0 ] && [ "$1" =  "5" ]; then
  echo "Using Puppet v5 ('$v5_puppet_gem') gem for testing"
  export PUPPET_VERSION=$v5_puppet_gem
  export CI_SPEC_OPTIONS="-f RspecJunitFormatter -o '$v5_output_xml' -f progress"
fi

export COMPOSE_PROJECT_NAME="conjur-puppet_$(openssl rand -hex 3)"

docker-compose -f "$compose_file" build --pull
docker-compose -f "$compose_file" run --rm test-runner \
  bundle exec rake test
