#!/bin/bash -e

NOKILL=${NOKILL:-"0"}
# FAIL_FAST=yes # to quit on first error

OSES=(
  ubuntu
  centos
  debian
)

COMPOSE_PROJECT_NAME=puppet-smoketest

# make sure on Jenkins if something goes wrong the
# build doesn't fail because of leftovers from previous tries
if [ -n "$BUILD_NUMBER" ]; then
   COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME-$BUILD_NUMBER
fi

export COMPOSE_PROJECT_NAME
NETNAME=${COMPOSE_PROJECT_NAME//-/}_default

ALL_OK=1

finish() {
  if [ "$NOKILL" == "0" ]; then
    rm -f conjur.pem node*.json hftoken.json
    docker-compose down -v
  fi
  test $ALL_OK -eq 1 || exit 1
}

if [ -z "$FAIL_FAST" ]; then
  try() {
    if ! ("$@"); then
      echo "\"$*\" failed"
      ALL_OK=0
    fi
  }
else
  try() {
    "$@"
  }
fi

trap finish EXIT

main() {
  echo "-----"
  echo "Conjur Puppet Smoke Tests"
  echo "-----"

  setup_conjur

  for os in "${OSES[@]}"; do
    for i in $(seq 4); do
      try scenario$i $os
    done
  done

  echo "-----"
  echo "Running Scenario 2 against Puppet agent 4.5"
  echo "This is required because the 'Sensitive' type is only supported in Puppet >= 4.6"
  echo "-----"

  # tag 1.5.2 of the puppet-agent-ubuntu image has Puppet 4.5 installed
  try scenario2 ubuntu 1.5.2 scenario2.5.pp
}

runInConjur() {
  docker-compose exec -T cli "$@"
}

wait_for_conjur() {
  docker-compose exec -T conjur bash -c 'while ! curl -sI localhost > /dev/null; do sleep 1; done'
}

init_conjur() {
  docker-compose exec -T conjur conjurctl account create cucumber || :
  docker-compose exec -T conjur conjurctl policy load cucumber /src/policy.yml
  docker-compose up -d cli
  docker-compose exec -T cli conjur authn login -psecret admin
}

setup_conjur() {
  echo "Starting Conjur"
  echo "-----"
  docker-compose up -d conjur

  echo "-----"
  echo "Loading Conjur policy"
  echo "-----"

  wait_for_conjur
  init_conjur
  runInConjur conjur variable values add inventory/db-password D7JGyGmCbDNCKYxgvpzz  # load the secret's value
}

scenario1() {
  local os="$1"

  echo "-----"
  echo "Scenario 1: Fetch a secret given a host name and API key"
  echo "OS: $os"
  echo "-----"
  local node_name='puppet-node01'

  local login="host/$node_name"
  local api_key=$(runInConjur conjur host rotate_api_key -h $node_name)

  docker run --rm \
    --network $NETNAME \
    -e FACTER_AUTHN_LOGIN="$login" \
    -e FACTER_CONJUR_VERSION=5 \
    -e FACTER_AUTHN_API_KEY="$api_key" \
    -e FACTER_APPLIANCE_URL='http://conjur/' \
    -v "$PWD/../:/src/conjur" -w /src/conjur \
    puppet/puppet-agent-$os:latest \
    apply --modulepath=/src examples/scenario1.pp
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

  docker run --rm \
    --network $NETNAME \
    -e FACTER_AUTHN_LOGIN="$login" \
    -e FACTER_CONJUR_VERSION=5 \
    -e FACTER_HOST_FACTORY_TOKEN="$host_factory_token" \
    -e FACTER_APPLIANCE_URL='http://conjur/' \
    -v "$PWD/../:/src/conjur" -w /src/conjur \
    puppet/puppet-agent-$os:$tag \
    apply --modulepath=/src examples/$manifest
}

scenario3() {
  local os="$1"

  echo "-----"
  echo "Scenario 3: Fetch a secret on a node with existing Conjur identity"
  echo "OS: $os"
  echo "-----"
  local node_name='puppet-node03'

  local login="host/$node_name"
  local api_key=$(runInConjur conjur host rotate_api_key -h $node_name)

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

  docker run --rm \
    --network $NETNAME \
    -v $config_file:/etc/conjur.conf:ro \
    -v $identity_file:/etc/conjur.identity:ro \
    -v "$PWD/../:/src/conjur" -w /src/conjur \
    puppet/puppet-agent-$os:latest \
    apply --modulepath=/src examples/scenario3.pp

  rm -rf $TMPDIR
}

scenario4() {
  local os="$1"
  local tag=${2:-latest}

  echo "-----"
  echo "Scenario 4: Fetch a secret given a host name and Host Factory token, then use that identity"
  echo "OS: $os"
  echo "Tag: $tag"
  echo "Manifest: $manifest"
  echo "-----"
  local node_name='puppet-node04'

  runInConjur bash -c "[ -f hftoken.json ] || conjur hostfactory tokens create inventory 1> hftoken.json"

  local login="host/$node_name"
  local host_factory_token=$(runInConjur jq -r '.[].token' hftoken.json | tr -d '\r')

  docker run --rm -i \
    --network $NETNAME \
    -v "$PWD/../:/src/conjur" -w /src/conjur \
    --entrypoint sh \
    -e FACTER_AUTHN_LOGIN="$login" \
    -e FACTER_CONJUR_VERSION=5 \
    -e FACTER_HOST_FACTORY_TOKEN="$host_factory_token" \
    -e FACTER_APPLIANCE_URL='http://conjur/' \
    puppet/puppet-agent-$os:$tag <<< \
    "
      puppet apply --modulepath=/src examples/scenario2.pp &&
      puppet apply --modulepath=/src examples/scenario3.pp
    "
}

main "$@"
