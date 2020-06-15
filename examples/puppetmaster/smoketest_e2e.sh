#!/bin/bash

set -euo pipefail

# Launches a full Puppet stack and converges a node against it

COMPOSE_PROJECT_NAME=puppetmaster

# make sure on Jenkins if something goes wrong the
# build doesn't fail because of leftovers from previous tries
if [ -n "${BUILD_NUMBER:-}" ]; then
   COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME-$BUILD_NUMBER
fi

export COMPOSE_PROJECT_NAME
NETNAME=${COMPOSE_PROJECT_NAME//-/}_default

cleanup() {
  echo "Ensuring clean state..."
  docker-compose down -v || true
}

main() {
  cleanup
  trap cleanup  EXIT

  start_services
  setup_conjur
  wait_for_puppetmaster
  converge_node
}

run_in_conjur() {
  docker-compose exec -T cli "$@"
}

start_services() {
  docker-compose up -d
}

wait_for_conjur() {
  docker-compose exec -T conjur conjurctl wait
}

wait_for_puppetmaster() {
  echo -n "Waiting on puppetmaster to be ready..."
  while ! docker-compose exec -T conjur curl -ks https://puppet:8140 >/dev/null; do
    echo -n "."
    sleep 2
  done
  echo "OK"
}

setup_conjur() {
  wait_for_conjur
  docker-compose exec -T conjur conjurctl account create cucumber || :
  api_key=$(docker-compose exec -T conjur conjurctl role retrieve-key cucumber:user:admin | tr -d '\r')

  echo "-----"
  echo "Starting CLI"
  echo "-----"

  docker-compose up -d cli

  echo "-----"
  echo "Logging into the CLI"
  echo "-----"
  run_in_conjur conjur authn login -u admin -p "${api_key}"

  echo "-----"
  echo "Loading Conjur initial policy"
  echo "-----"
  run_in_conjur conjur policy load root /src/policy.yml
  run_in_conjur conjur variable values add inventory/db-password D7JGyGmCbDNCKYxgvpzz  # load the secret's value
}

converge_node() {
  local node_name='node01'

  local login="host/$node_name"
  local api_key=$(run_in_conjur conjur host rotate_api_key -h $node_name)

  # write the conjurize files to a tempdir so they can be mounted
  TMPDIR="$PWD/tmp"
  mkdir -p $TMPDIR

  local config_file="$TMPDIR/conjur.conf"
  local identity_file="$TMPDIR/conjur.identity"

  echo "
    appliance_url: http://conjur/
    version: 5
    account: cucumber
  " > $config_file

  echo "
    machine conjur
    login $login
    password $api_key
  " > $identity_file

  docker run --rm -t \
    --net $NETNAME \
    -e 'FACTER_CONJUR_SMOKE_TEST=true' \
    -v $config_file:/etc/conjur.conf:ro \
    -v $identity_file:/etc/conjur.identity:ro \
    -v $PWD:/src:ro -w /src \
    puppet/puppet-agent-ubuntu:5.5.1

  rm -rf $TMPDIR
}

main "$@"
