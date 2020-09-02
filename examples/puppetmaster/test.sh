#!/bin/bash

set -euo pipefail

# Launches a full Puppet stack and converges nodes against it

source vagrant/utils.sh

CLEAN_UP_ON_EXIT=${CLEAN_UP_ON_EXIT:-true}
INSTALL_PACKAGED_MODULE=${INSTALL_PACKAGED_MODULE:-true}
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-puppetmaster_$(openssl rand -hex 3)}
PACKAGED_MODULE_PATH='pkg/cyberark-conjur.tar.gz'

PUPPET_SERVER_TAG=latest
PUPPET_AGENT_TAGS=( latest )
export PUPPET_SERVER_TAG

echo "Using Puppet server '$PUPPET_SERVER_TAG' with agents: '${PUPPET_AGENT_TAGS[@]}'"

# Sanity check
if [[ "$INSTALL_PACKAGED_MODULE" == 'true' ]] && \
  [[ ! -e "../../$PACKAGED_MODULE_PATH" ]]; then

  echo 'INSTALL_PACKAGED_MODULE is true but module was not found at '../../$PACKAGED_MODULE_PATH'!'
  exit 1
fi

OSES=(
  "alpine"
#  "ubuntu"
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
  if [[ "${CLEAN_UP_ON_EXIT}" = true ]]; then
    trap cleanup EXIT
  fi

  start_services
  setup_conjur
  wait_for_puppetmaster

  if [[ "${INSTALL_PACKAGED_MODULE}" = true ]]; then
    # This branch is generally exercised for testing production builds. It installs the
    # packaged module from the mounted onto directory '/conjur/pkg'.

    install_conjur_module
  else
    # This brach is generally exercised during development. It symlinks the source from
    # mounted onto directory '/conjur' to
    # '/etc/puppetlabs/code/environments/production/modules/conjur', and installs any
    # module dependencies.

    symlink_conjur_module
    install_required_module_dependency
  fi

  get_docker_gateway_ip
  add_puppetmaster_etc_hosts

  for os_name in ${OSES[@]}; do
    for agent_tag in ${PUPPET_AGENT_TAGS[@]}; do
      local agent_image="puppet/puppet-agent-$os_name:$agent_tag"

      echo "---"
      echo "Running tests for '$agent_image'..."

      echo
      echo "=> Agent config, API Key <="
      converge_node_agent_apikey "$agent_image"

      echo
      echo "=> Hiera manifest config, API Key <="
#      converge_node_hiera_manifest_apikey "$agent_image"

      echo "Tests for '$agent_image': OK"
    done
  done

  echo "==="
  echo "ALL TESTS COMPLETED"
}

run_in_conjur() {
  docker-compose exec -T conjur "$@"
}

run_in_conjur_cli() {
  docker-compose exec -T cli "$@"
}

run_in_puppet() {
  docker-compose exec -T puppet "$@"
}

start_services() {
  docker-compose up -d conjur-https \
                       puppet \
                       puppet-compiler1
}

wait_for_conjur() {
  docker-compose exec -T conjur conjurctl wait
}

wait_for_puppetmaster() {
  echo "Waiting on Puppet to be ready..."
  for server in puppet puppet-compiler1; do
    echo -n "Waiting for puppet server '$server'..."
    while ! run_in_conjur curl -ks https://$server:8140 >/dev/null; do
      echo -n "."
      sleep 2
    done
    echo "OK"
  done
}

get_host_key() {
  local hostname="$1"
  run_in_conjur_cli conjur host rotate_api_key -h "$hostname"
}

get_hf_token() {
  run_in_conjur_cli conjur hostfactory tokens create --duration-hours 1 inventory | jq -r ".[].token"
}

symlink_conjur_module() {
  echo "Creating a symlink of cyberark-conjur module source on server..."
  run_in_puppet bash -c "
    rm -rf /etc/puppetlabs/code/environments/production/modules/conjur
    ln -fs /conjur /etc/puppetlabs/code/environments/production/modules/conjur
  "
}

install_conjur_module() {
  echo "Installing packaged cyberark-conjur module to server..."
  run_in_puppet bash -c "
    puppet module install /conjur/$PACKAGED_MODULE_PATH --force;
  "
}

install_required_module_dependency() {
  echo "Installing puppetlabs-registry module dep to server..."
  run_in_puppet puppet module install puppetlabs-registry
}

get_docker_gateway_ip() {
  # Get the IP address of the Docker compose network's gateway.
  DOCKER_GATEWAY_IP="$(docker inspect $(docker-compose ps -q puppet)| \
    jq .[0].NetworkSettings.Networks[].Gateway | tr -d '"')"
}

add_puppetmaster_etc_hosts() {
  # Make an /etc/hosts entry in the Puppet server container for the DNS name
  # 'conjur.cyberark.com'. This is used by the Puppet server to access the
  echo "Adding /etc/hosts entry in puppet server: \"$DOCKER_GATEWAY_IP conjur.cyberark.com\""
  # Make a temporary copy of /etc/hosts to modify since `sed` is not able to
  # directly modify /etc/hosts when it is run via 'docker exec'.
  run_in_puppet bash -c \
    "cp /etc/hosts /tmp/hosts; \
    /bin/sed -i $'/\tconjur.cyberark.com$/d' /tmp/hosts; \
    echo $'$DOCKER_GATEWAY_IP\tconjur.cyberark.com' >> /tmp/hosts; \
    cp /tmp/hosts /etc/hosts"
}

setup_conjur() {
  wait_for_conjur
  run_in_conjur conjurctl account create cucumber || :
  local api_key=$(run_in_conjur conjurctl role retrieve-key cucumber:user:admin | tr -d '\r')

  echo "-----"
  echo "Starting CLI"
  echo "-----"

  docker-compose up -d cli

  echo "-----"
  echo "Logging into the CLI"
  echo "-----"
  run_in_conjur_cli conjur authn login -u admin -p "${api_key}"

  echo "-----"
  echo "Loading Conjur initial policy"
  echo "-----"
  run_in_conjur_cli conjur policy load root /src/policy.yml
  run_in_conjur_cli conjur variable values add inventory/db-password $EXPECTED_PASSWORD  # load the secret's value
}

revoke_cert_for() {
  local cert_fqdn="$1"
  echo "Ensuring clean cert state for $cert_fqdn..."

  # Puppet v5 and v6 CLIs aren't 1:1 compatible so we have to choose the format based
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
    appliance_url: https://conjur.cyberark.com:$(conjur_host_port)/
    version: 5
    account: cucumber
    cert_file: /etc/ca.crt
  " > $config_file
  chmod 600 $config_file

  echo "
    machine conjur.cyberark.com
    login $login
    password $api_key
  " > $identity_file
  chmod 600 $identity_file

  revoke_cert_for "$hostname"

  set -x
  docker run --rm -t \
    --net $NETNAME \
    --add-host "conjur.cyberark.com:$DOCKER_GATEWAY_IP" \
    -v "$config_file:/etc/conjur.conf:ro" \
    -v "$identity_file:/etc/conjur.identity:ro" \
    -v "$PWD/https_config/ca.crt:/etc/ca.crt:ro" \
    --hostname "$hostname" \
    "$agent_image" \
      agent --verbose \
            --onetime \
            --no-daemonize \
            --ca-server 'puppet' \
            --server 'puppet-compiler1' \
            --certname "$hostname" \
            --summarize
  set +x

  rm -rf $TMPDIR
}

converge_node_hiera_manifest_apikey() {
  local agent_image="$1"
  local node_name="hiera-manifest-apikey-node"
  local hostname="${node_name}_$(openssl rand -hex 3)"

  local login="host/$node_name"
  local api_key=$(get_host_key $node_name)
  echo "API key for $node_name: $api_key"

  local hiera_config_file="./code/data/nodes/$hostname.yaml"
  local manifest_config_file="./code/environments/production/manifests/00_$hostname.pp"

  local ssl_certificate="$(cat https_config/ca.crt | sed 's/^/  /')"

  echo "---
lookup_options:
  '^conjur::authn_api_key':
    convert_to: 'Sensitive'

conjur::account: 'cucumber'
conjur::appliance_url: 'https://conjur.cyberark.com:$(conjur_host_port)'
conjur::authn_login: 'host/$node_name'
conjur::authn_api_key: '$api_key'
conjur::ssl_certificate: |
$ssl_certificate
  " > $hiera_config_file

  echo "
    node '$hostname' {
      \$pem_file  = '/tmp/test.pem'
      \$secret = Sensitive(Deferred(conjur::secret, ['inventory/db-password', {
          appliance_url => lookup('conjur::appliance_url'),
          account => lookup('conjur::account'),
          authn_login => lookup('conjur::authn_login'),
          authn_api_key => lookup('conjur::authn_api_key'),
          ssl_certificate => lookup('conjur::ssl_certificate')
      }]))

      notify { \"Writing secret to \${pem_file}...\": }
      file { \$pem_file:
        ensure  => file,
        content => \$secret,
      }

      exec { \"cat \${pem_file}\":
        path      => '/usr/bin:/usr/sbin:/bin',
        provider  => shell,
        logoutput => true,
      }
    }" > $manifest_config_file

  revoke_cert_for "$hostname"

  set -x
  docker run --rm -t \
    --net $NETNAME \
    --add-host "conjur.cyberark.com:$DOCKER_GATEWAY_IP" \
    --hostname "$hostname" \
    "$agent_image" \
      agent --verbose \
            --onetime \
            --no-daemonize \
            --summarize \
            --certname "$hostname"
  set +x

  rm -rf "$manifest_config_file" "$hiera_config_file"
}

main "$@"
