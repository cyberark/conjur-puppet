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
    "5.5.1"
    "latest"
  )
fi
export PUPPET_SERVER_TAG

echo "Using Puppet server '$PUPPET_SERVER_TAG' with agents: '${PUPPET_AGENT_TAGS[@]}'"

OSES=(
  "alpine"
  "ubuntu"
)

export COMPOSE_PROJECT_NAME
NETNAME=${COMPOSE_PROJECT_NAME//-/}_default
EXPECTED_PASSWORD="supersecretpassword"

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

  for os_name in ${OSES[@]}; do
    for agent_tag in ${PUPPET_AGENT_TAGS[@]}; do
      local agent_image="puppet/puppet-agent-$os_name:$agent_tag"

      echo "---"
      echo "Running tests for '$agent_image'..."

      echo
      echo "=> Agent config, API Key <="
      converge_node_agent_apikey "$agent_image"

      echo
      echo "=> Hiera config, API Key <="
      converge_node_hiera_apikey "$agent_image"

      echo
      echo "=> Hiera config, HF Token <="
      converge_node_hiera_hft "$agent_image"

      echo
      echo "=> Manifest config, API Key <="
      converge_node_manifest_apikey "$agent_image"

      echo
      echo "=> Manifest config, HF Token <="
      converge_node_manifest_hft "$agent_image"

      echo "Tests for '$agent_image': OK"
    done
  done

  echo "==="
  echo "ALL TESTS COMPLETED"
}

run_in_conjur() {
  docker-compose exec -T cli "$@"
}

run_in_puppet() {
  docker-compose exec -T puppet "$@"
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

get_host_key() {
  local hostname="$1"
  run_in_conjur conjur host rotate_api_key -h "$hostname"
}

get_hf_token() {
  run_in_conjur conjur hostfactory tokens create --duration-hours 1 inventory | jq -r ".[].token"
}

install_required_module_dependency() {
  echo "Installing puppetlabs-registry module dep to server..."
  docker-compose exec -T puppet puppet module install puppetlabs-registry
}

setup_conjur() {
  wait_for_conjur
  docker-compose exec -T conjur conjurctl account create cucumber || :
  local api_key=$(docker-compose exec -T conjur conjurctl role retrieve-key cucumber:user:admin | tr -d '\r')

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
  run_in_conjur conjur variable values add inventory/db-password $EXPECTED_PASSWORD  # load the secret's value
}

revoke_cert_for() {
  local cert_fqdn="$1"
  echo "Ensuring clean cert state for $cert_fqdn..."

  # Puppet v5 and v6 CLIs aren't 1:1 compatible so we have to chose the format based
  # on the server version
  if [ "${PUPPET_SERVER_TAG:0:1}" == 5 ]; then
    run_in_puppet puppet cert clean "$cert_fqdn" &>/dev/null || true
    return
  fi

  run_in_puppet puppetserver ca revoke --certname "$cert_fqdn" &>/dev/null || true
  run_in_puppet puppetserver ca clean --certname "$cert_fqdn" &>/dev/null || true
}

converge_node_agent_apikey() {
  local agent_image="$1"
  local node_name="agent-apikey-node"
  local hostname="${node_name}_$(openssl rand -hex 3)"

  local login="host/$node_name"
  local api_key=$(get_host_key $node_name)
  echo "API key for $node_name: $api_key"

  # write the conjurize files to a tempdir so they can be mounted
  TMPDIR="$PWD/tmp/$(openssl rand -hex 3)"
  mkdir -p $TMPDIR

  local config_file="$TMPDIR/conjur.conf"
  local identity_file="$TMPDIR/conjur.identity"

  echo "
    appliance_url: https://conjur-https:$CONJUR_SERVER_PORT/
    version: 5
    account: cucumber
    cert_file: /etc/ca.crt
  " > $config_file
  chmod 600 $config_file

  echo "
    machine conjur-https
    login $login
    password $api_key
  " > $identity_file
  chmod 600 $identity_file

  revoke_cert_for "$hostname"

  set -x
  docker run --rm -t \
    --net $NETNAME \
    -v "$config_file:/etc/conjur.conf:ro" \
    -v "$identity_file:/etc/conjur.identity:ro" \
    -v "$PWD/https_config/ca.crt:/etc/ca.crt:ro" \
    --hostname "$hostname" \
    "$agent_image" \
      agent --verbose \
            --onetime \
            --no-daemonize \
            --summarize \
            --certname "$hostname"
  set +x

  rm -rf $TMPDIR
}

converge_node_hiera_apikey() {
  local agent_image="$1"
  local node_name="hiera-apikey-node"
  local hostname="${node_name}_$(openssl rand -hex 3)"

  local login="host/$node_name"
  local api_key=$(get_host_key $node_name)
  echo "API key for $node_name: $api_key"

  local hiera_config_file="./code/data/nodes/$hostname.yaml"

  local ssl_certificate="$(cat https_config/ca.crt | sed 's/^/  /')"
  echo "---
lookup_options:
  '^conjur::authn_api_key':
    convert_to: 'Sensitive'

conjur::account: 'cucumber'
conjur::appliance_url: 'https://conjur-https:$CONJUR_SERVER_PORT'
conjur::authn_login: 'host/$node_name'
conjur::authn_api_key: '$api_key'
conjur::ssl_certificate: |
$ssl_certificate
  " > $hiera_config_file

  revoke_cert_for "$hostname"

  set -x
  docker run --rm -t \
    --net $NETNAME \
    --hostname "$hostname" \
    "$agent_image" \
      agent --verbose \
            --onetime \
            --no-daemonize \
            --summarize \
            --certname "$hostname"
  set +x

  rm -rf "$hiera_config_file"
}

converge_node_hiera_hft() {
  local agent_image="$1"
  local node_name="hiera-hft-node"
  local hostname="${node_name}_$(openssl rand -hex 3)"

  local login="host/$node_name"
  local hf_token=$(get_hf_token)
  echo "HF token for $node_name: $hf_token"

  local hiera_config_file="./code/data/nodes/$hostname.yaml"

  local ssl_certificate="$(cat https_config/ca.crt | sed 's/^/  /')"
  echo "---
lookup_options:
  '^conjur::host_factory_token':
    convert_to: 'Sensitive'

conjur::account: 'cucumber'
conjur::appliance_url: 'https://conjur-https:$CONJUR_SERVER_PORT'
conjur::authn_login: 'host/$node_name'
conjur::host_factory_token: '$hf_token'
conjur::ssl_certificate: |
$ssl_certificate
  " > $hiera_config_file

  revoke_cert_for "$hostname"

  set -x
  docker run --rm -t \
    --net $NETNAME \
    --hostname "$hostname" \
    "$agent_image" \
      agent --verbose \
            --onetime \
            --no-daemonize \
            --summarize \
            --certname "$hostname"
  set +x

  rm -rf "$hiera_config_file"
}

converge_node_manifest_apikey() {
  local agent_image="$1"
  local node_name="manifest-apikey-node"
  local hostname="${node_name}_$(openssl rand -hex 3)"

  local login="host/$node_name"
  local api_key=$(get_host_key $node_name)
  echo "API key for $node_name: $api_key"

  local manifest_config_file="./code/environments/production/manifests/00_$hostname.pp"

  local ssl_certificate="$(cat https_config/ca.crt)"
  echo "
    node '$hostname' {
      \$sslcert = @("EOT")
$ssl_certificate
      |-EOT

      class { 'conjur':
        appliance_url      => 'https://conjur-https:$CONJUR_SERVER_PORT',
        account            => 'cucumber',
        authn_login        => 'host/$node_name',
        authn_api_key      => Sensitive('$api_key'),
        ssl_certificate    => \$sslcert
      }

      include conjur
      \$pem_file  = '/tmp/test.pem'
      \$secret = conjur::secret('inventory/db-password')
      notify { \"Writing secret '\${secret.unwrap}' to \$pem_file...\": }
      file { \$pem_file:
        ensure  => file,
        content => conjur::secret('inventory/db-password'),
      }
    }
  " > $manifest_config_file

  revoke_cert_for "$hostname"

  set -x
  docker run --rm -t \
    --net $NETNAME \
    --hostname "$hostname" \
    "$agent_image" \
      agent --verbose \
            --onetime \
            --no-daemonize \
            --summarize \
            --certname "$hostname"
  set +x

  rm -rf "$manifest_config_file"
}

converge_node_manifest_hft() {
  local agent_image="$1"
  local node_name="manifest-hft-node"
  local hostname="${node_name}_$(openssl rand -hex 3)"

  local login="host/$node_name"
  local hf_token=$(get_hf_token)
  echo "HF token for $node_name: $hf_token"

  local manifest_config_file="./code/environments/production/manifests/00_$hostname.pp"

  local ssl_certificate="$(cat https_config/ca.crt)"
  echo "
    node '$hostname' {
      \$sslcert = @("EOT")
$ssl_certificate
      |-EOT

      class { 'conjur':
        appliance_url      => 'https://conjur-https:$CONJUR_SERVER_PORT',
        account            => 'cucumber',
        authn_login        => 'host/$node_name',
        host_factory_token => Sensitive('$hf_token'),
        ssl_certificate => \$sslcert
      }

      include conjur
      \$pem_file  = '/tmp/test.pem'
      \$secret = conjur::secret('inventory/db-password')
      notify { \"Writing secret '\${secret.unwrap}' to \$pem_file...\": }
      file { \$pem_file:
        ensure  => file,
        content => conjur::secret('inventory/db-password'),
      }
    }
  " > $manifest_config_file

  revoke_cert_for "$hostname"

  set -x
  docker run --rm -t \
    --net $NETNAME \
    --hostname "$hostname" \
    "$agent_image" \
      agent --verbose \
            --onetime \
            --no-daemonize \
            --summarize \
            --certname "$hostname"
  set +x

  rm -rf "$manifest_config_file"
}

main "$@"
