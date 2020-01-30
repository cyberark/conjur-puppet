#!/bin/bash -e

# Launches a full Puppet stack and converges a node against it

COMPOSE_PROJECT_NAME=puppet-smoketeste2e

# make sure on Jenkins if something goes wrong the
# build doesn't fail because of leftovers from previous tries
if [ -n "$BUILD_NUMBER" ]; then
   COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME-$BUILD_NUMBER
fi

export COMPOSE_PROJECT_NAME
NETNAME=${COMPOSE_PROJECT_NAME//-/}_default

main() {
  startServices
  setupConjur
  convergeNode
}

runInConjur() {
  docker-compose exec -T cli "$@"
}

startServices() {
  docker-compose up -d
}

wait_for_conjur() {
  docker-compose exec -T conjur bash -c 'while ! curl -sI localhost > /dev/null; do sleep 1; done'
}

setupConjur() {
  wait_for_conjur
  docker-compose exec -T conjur conjurctl account create cucumber || :
  docker-compose exec -T conjur conjurctl policy load cucumber /src/policy.yml
  docker-compose up -d cli
  docker-compose exec -T cli conjur authn login -pADmin123!!!! admin
  runInConjur conjur variable values add inventory/db-password D7JGyGmCbDNCKYxgvpzz  # load the secret's value
}

convergeNode() {
  local node_name='node01'

  local login="host/$node_name"
  local api_key=$(runInConjur conjur host rotate_api_key -h $node_name)

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

  docker run --rm \
    --net $NETNAME \
    -e 'FACTER_CONJUR_SMOKE_TEST=true' \
    -v $config_file:/etc/conjur.conf:ro \
    -v $identity_file:/etc/conjur.identity:ro \
    -v $PWD:/src:ro -w /src \
    puppet/puppet-agent-ubuntu

  rm -rf $TMPDIR

}

main "$@"
