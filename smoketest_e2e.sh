#!/bin/bash -e

# Launches a full Puppet stack and converges a node against it

COMPOSE_FILE='docker-compose.puppet.yml'

main() {
  startServices
  setupConjur
  convergeNode
}

runInConjur() {
  docker-compose -f $COMPOSE_FILE exec -T conjur "$@"
}

startServices() {
  docker-compose -f $COMPOSE_FILE up -d
}

setupConjur() {
  runInConjur /opt/conjur/evoke/bin/wait_for_conjur > /dev/null
  runInConjur cat /opt/conjur/etc/ssl/ca.pem > conjur.pem

  runInConjur conjur policy load --as-group security_admin /src/test/policy.yml
  runInConjur conjur variable values add inventory/db-password D7JGyGmCbDNCKYxgvpzz  # load the secret's value
}

convergeNode() {
  local node_name='node01'

  runInConjur bash -c "[ -f node.json ] || conjur host create --as-group security_admin $node_name 1> node.json 2>/dev/null"
  runInConjur bash -c "conjur layer hosts add inventory $node_name 2>/dev/null"

  local login="host/$node_name"
  local api_key=$(runInConjur jq -r '.api_key' node.json | tr -d '\r')

  # write the conjurize files to a tempdir so they can be mounted
  TMPDIR="$PWD/tmp"
  mkdir -p $TMPDIR

  local config_file="$TMPDIR/conjur.conf"
  local identity_file="$TMPDIR/conjur.identity"

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
    --net puppet_default \
    -e 'FACTER_CONJUR_SMOKE_TEST=true' \
    -v $config_file:/etc/conjur.conf:ro \
    -v $identity_file:/etc/conjur.identity:ro \
    -v $PWD:/src:ro -w /src \
    puppet/puppet-agent-ubuntu

  rm -rf $TMPDIR

}

main "$@"
