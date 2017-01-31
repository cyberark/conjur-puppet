#!/bin/bash -e

main() {
  echo "-----"
  echo "Conjur Puppet Demo"
  echo "-----"

  setup_conjur

  scenario1
  scenario2
  scenario3
}

runInConjur() {
  docker-compose exec conjur "$@"
}

setup_conjur() {
  echo "Starting Conjur"
  echo "-----"
  docker-compose up -d conjur
  runInConjur /opt/conjur/evoke/bin/wait_for_conjur > /dev/null
  runInConjur cat /opt/conjur/etc/ssl/ca.pem > conjur.pem

  echo "-----"
  echo "Loading Conjur policy"
  echo "-----"
  runInConjur conjur policy load --as-group security_admin /src/examples/policy.yml
  runInConjur conjur variable values add inventory/db-password D7JGyGmCbDNCKYxgvpzz  # load the secret's value
}

scenario1() {
  echo "-----"
  echo "Scenario 1: Fetch a secret given a host name and API key"
  echo "-----"
  local node_name='puppet-node01'

  runInConjur bash -c "[ -f node.json ] || conjur host create --as-group security_admin $node_name 1> node.json 2>/dev/null"
  runInConjur bash -c "conjur layer hosts add inventory $node_name 2>/dev/null"

  local login="host/$node_name"
  local api_key=$(runInConjur jq -r '.api_key' node.json | tr -d '\r')

  docker run --rm \
    -e FACTER_AUTHN_LOGIN="$login" \
    -e FACTER_AUTHN_API_KEY="$api_key" \
    -e FACTER_APPLIANCE_URL='https://conjur/api' \
    -v $PWD:/src -w /src \
    --link puppet_conjur_1:conjur \
    puppet/puppet-agent-ubuntu \
    apply --modulepath=spec/fixtures/modules examples/with_api_key.pp
}

scenario2() {
  echo "-----"
  echo "Scenario 2: Fetch a secret given a host name and Host Factory token"
  echo "-----"
  local node_name='puppet-node02'

  runInConjur bash -c "[ -f hftoken.json ] || conjur hostfactory tokens create inventory 1> hftoken.json"

  local login="host/$node_name"
  local host_factory_token=$(runInConjur jq -r '.[].token' hftoken.json | tr -d '\r')

  docker run --rm \
    -e FACTER_AUTHN_LOGIN="$login" \
    -e FACTER_HOST_FACTORY_TOKEN="$host_factory_token" \
    -e FACTER_APPLIANCE_URL='https://conjur/api' \
    -v $PWD:/src -w /src \
    --link puppet_conjur_1:conjur \
    puppet/puppet-agent-ubuntu \
    apply --modulepath=spec/fixtures/modules examples/with_host_factory_token.pp
}

scenario3() {
  echo "-----"
  echo "Scenario 3: Fetch a secret on a node with existing Conjur identity"
  echo "-----"
  echo "TODO"
}

main "$@"
