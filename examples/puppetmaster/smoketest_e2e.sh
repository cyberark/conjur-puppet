#!/bin/bash

set -euo pipefail

# Launches a full Puppet stack and converges a node against it

CLEAN_UP_ON_EXIT=${CLEAN_UP_ON_EXIT:-true}
CONJUR_SERVER_PORT=${CONJUR_SERVER_PORT:-8443}
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-puppetmaster_$(openssl rand -hex 3)}

PUPPET_SERVER_TAG=latest
PUPPET_AGENT_TAGS=( latest )
if [ "${1:-}" = "5" ]; then
  PUPPET_SERVER_TAG="5.3.7"
  PUPPET_AGENT_TAGS=(
    5.5.1
    latest
  )
fi
export PUPPET_SERVER_TAG

echo "Using Puppet server '$PUPPET_SERVER_TAG' with agents: '${PUPPET_AGENT_TAGS[@]}'"

OSES=(
  alpine
  ubuntu
)

export COMPOSE_PROJECT_NAME
NETNAME=${COMPOSE_PROJECT_NAME//-/}_default

cleanup() {
  echo "Ensuring clean state..."
  docker-compose down -v || true
}

main() {
  cleanup
  if [ "$CLEAN_UP_ON_EXIT" = true ]; then
    trap cleanup EXIT
  fi

  start_services
  setup_conjur
  wait_for_puppetmaster
  install_required_module_dependency
  converge_node
}

run_in_conjur() {
  docker-compose exec -T cli "$@"
}

start_services() {
  docker-compose up -d conjur-https puppet
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

install_required_module_dependency() {
  echo "Installing puppetlabs-registry module dep to server..."
  docker-compose exec -T puppet puppet module install puppetlabs-registry
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
  TMPDIR="$PWD/tmp/$(openssl rand -hex 3)"
  mkdir -p $TMPDIR

  local config_file="$TMPDIR/conjur.conf"
  local identity_file="$TMPDIR/conjur.identity"

  # We pre-indent it to fit with the YAML syntax
  local ssh_certificate="$(cat https_config/ca.crt | sed 's/^/  /')"

  echo "
    appliance_url: https://conjur-https:$CONJUR_SERVER_PORT/
    version: 5
    account: cucumber
    cert_file: /etc/ca.crt
  " > $config_file

  echo "
    machine conjur-https
    login $login
    password $api_key
  " > $identity_file

  for os_name in ${OSES[@]}; do
    for agent_tag in ${PUPPET_AGENT_TAGS[@]}; do
      echo "---"
      echo "Running test for $os_name:$agent_tag..."
      set -x
      docker run --rm -t \
        --net $NETNAME \
        -v "$config_file:/etc/conjur.conf:ro" \
        -v "$identity_file:/etc/conjur.identity:ro" \
        -v "$PWD/https_config/ca.crt:/etc/ca.crt:ro" \
        -v "$PWD:/src:ro" \
        -w /src \
        "puppet/puppet-agent-$os_name:$agent_tag"
      set +x
    done
  done

  echo "==="
  echo "DONE"

  rm -rf $TMPDIR
}

main "$@"
