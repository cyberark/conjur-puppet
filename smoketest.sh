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
    for i in `seq 4`; do
      scenario$i $os
    done
  done

  echo "-----"
  echo "Running Scenario 2 against Puppet agent 4.5"
  echo "This is required because the 'Sensitive' type is only supported in Puppet >= 4.6"
  echo "-----"

  # tag 1.5.2 of the puppet-agent-ubuntu image has Puppet 4.5 installed
  scenario2 ubuntu 1.5.2 scenario2.5.pp
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
  local conjur_container=$(docker-compose ps -q conjur)

  docker run --rm \
    -e FACTER_AUTHN_LOGIN="$login" \
    -e FACTER_AUTHN_API_KEY="$api_key" \
    -e FACTER_APPLIANCE_URL='https://conjur/api' \
    -e FACTER_SSL_CERTIFICATE="$(cat conjur.pem)" \
    -v $PWD:/src -w /src \
    --link $conjur_container:conjur \
    puppet/puppet-agent-$os:latest \
    apply --modulepath=spec/fixtures/modules test/scenario1.pp
}

scenario2() {
  local os="$1"
  local tag=${2:-latest}
  local manifest=${3:-scenario2.pp}

  echo "-----"
  echo "Scenario 2: Fetch a secret given a host name and Host Factory token"
  echo "OS: $os"
  echo "Tag: $tag"
  echo "Manifest: $manifest"
  echo "-----"
  local node_name='puppet-node02'

  runInConjur bash -c "[ -f hftoken.json ] || conjur hostfactory tokens create inventory 1> hftoken.json"

  local login="host/$node_name"
  local host_factory_token=$(runInConjur jq -r '.[].token' hftoken.json | tr -d '\r')
  local conjur_container=$(docker-compose ps -q conjur)

  docker run --rm \
    -e FACTER_AUTHN_LOGIN="$login" \
    -e FACTER_HOST_FACTORY_TOKEN="$host_factory_token" \
    -e FACTER_APPLIANCE_URL='https://conjur/api' \
    -e FACTER_SSL_CERTIFICATE="$(cat conjur.pem)" \
    -v $PWD:/src -w /src \
    --link $conjur_container:conjur \
    puppet/puppet-agent-$os:$tag \
    apply --modulepath=spec/fixtures/modules test/$manifest
}

scenario3() {
  local os="$1"

  echo "-----"
  echo "Scenario 3: Fetch a secret on a node with existing Conjur identity"
  echo "OS: $os"
  echo "-----"

  echo "TODO"
}

scenario4() {
  local os="$1"

  echo "-----"
  echo "Scenario 4: Fetch a secret given a host name and API key,"
  echo "        with preconfigured Conjur identity"
  echo "OS: $os"
  echo "-----"
  local node_name='puppet-node04'

  runInConjur bash -c "[ -f node4.json ] || conjur host create --as-group security_admin $node_name 1> node4.json 2>/dev/null"
  runInConjur bash -c "conjur layer hosts add inventory $node_name 2>/dev/null"

  local login="host/$node_name"
  local api_key=$(runInConjur jq -r '.api_key' node4.json | tr -d '\r')
  local conjur_container=$(docker-compose ps -q conjur)

  local config_file=$(mktemp)
  local identity_file=$(mktemp)

  echo "
    appliance_url: https://conjur/api
    cert_file: /src/conjur.pem
  " > $config_file

  echo "
    machine conjur
    login $login
    password $api_key
  " > $identity_file

  docker run --rm \
    -v $config_file:/etc/conjur.conf:ro \
    -v $identity_file:/etc/conjur.identity:ro \
    -v $PWD:/src:ro -w /src \
    --link $conjur_container:conjur \
    puppet/puppet-agent-$os:latest \
    apply --modulepath=spec/fixtures/modules test/scenario4.pp

  rm -f $config_file $identity_file
}

main "$@"
