#!/bin/bash -e

readonly compose_file='docker-compose.test.yml'
readonly v5_output_xml="spec/output/rspec_puppet5.xml"

readonly v6_puppet_gem="~>6.17.0"

if [ "$#" -gt 0 ] && [ "$1" =  "6" ]; then
  echo "Using Puppet v6 ('$v6_puppet_gem') gem for testing"
  export PUPPET_VERSION=$v6_puppet_gem
else
  echo "Using default Puppet v5 gem for testing"
  export CI_SPEC_OPTIONS="-f RspecJunitFormatter -o '$v5_output_xml' -f progress"
fi

export COMPOSE_PROJECT_NAME="conjur-puppet_$(openssl rand -hex 3)"

docker-compose -f "$compose_file" build --pull
docker-compose -f "$compose_file" run --rm test-runner \
  bundle exec rake test
