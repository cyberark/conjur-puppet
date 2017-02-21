#!/bin/bash -e

NOKILL=${NOKILL:-"0"}

OSES=(
  ubuntu
  centos
  debian
)

finish() {
  if [ "$NOKILL" == "0" ]; then
    docker-compose down -v
  fi
}

trap finish EXIT

main() {
  echo "-----"
  echo "Conjur Puppet Smoke Tests"
  echo "-----"

  setup_conjur

  for os in "${OSES[@]}"; do
    scenario1 $os
    scenario2 $os
    scenario3 $os
  done
}

runInConjur() {
  docker-compose exec -T conjur "$@"
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
  runInConjur conjur policy load --as-group security_admin /src/test/policy.yml
  runInConjur conjur variable values add inventory/db-password D7JGyGmCbDNCKYxgvpzz  # load the secret's value
}

scenario1() {
  local os="$1"

  echo "-----"
  echo "Scenario 1: Fetch a secret given a host name and API key"
  echo "OS: $os"
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
    -e FACTER_SSL_CERTIFICATE="$(cat conjur.pem)" \
    -v $PWD:/src -w /src \
    --link puppet_conjur_1:conjur \
    puppet/puppet-agent-$os \
    apply --modulepath=spec/fixtures/modules test/scenario1.pp
}

scenario2() {
  local os="$1"

  echo "-----"
  echo "Scenario 2: Fetch a secret given a host name and Host Factory token"
  echo "OS: $os"
  echo "-----"
  local node_name='puppet-node02'

  runInConjur bash -c "[ -f hftoken.json ] || conjur hostfactory tokens create inventory 1> hftoken.json"

  local login="host/$node_name"
  local host_factory_token=$(runInConjur jq -r '.[].token' hftoken.json | tr -d '\r')

  docker run --rm \
    -e FACTER_AUTHN_LOGIN="$login" \
    -e FACTER_HOST_FACTORY_TOKEN="$host_factory_token" \
    -e FACTER_APPLIANCE_URL='https://conjur/api' \
    -e FACTER_SSL_CERTIFICATE="$(cat conjur.pem)" \
    -v $PWD:/src -w /src \
    --link puppet_conjur_1:conjur \
    puppet/puppet-agent-$os \
    apply --modulepath=spec/fixtures/modules test/scenario2.pp
}

scenario3() {
  local os="$1"

  echo "-----"
  echo "Scenario 3: Fetch a secret on a node with existing Conjur identity"
  echo "OS: $os"
  echo "-----"

  echo "TODO"
}

main "$@"
