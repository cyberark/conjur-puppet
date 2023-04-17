#!/bin/bash

set -euo pipefail

# Launches a full Puppet stack and converges nodes against it

source vagrant/utils.sh

# MAIN_HOST_IP is the IP address of the host where the tests are running that should be
# accessible from containers running in the Windows Docker Daemon.
export MAIN_HOST_IP=${MAIN_HOST_IP:-}
# Configuration for the Windows Docker Daemon. If WINDOWS_DOCKER_HOST is not set then the
# Windows tests are skipped.
export WINDOWS_DOCKER_HOST=${WINDOWS_DOCKER_HOST:-}
export WINDOWS_DOCKER_CERT_PATH=${WINDOWS_DOCKER_CERT_PATH:-}
export WINDOWS_DOCKER_TLS_VERIFY=${WINDOWS_DOCKER_TLS_VERIFY:-0}

CLEAN_UP_ON_EXIT=${CLEAN_UP_ON_EXIT:-true}
INSTALL_PACKAGED_MODULE=${INSTALL_PACKAGED_MODULE:-true}
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-puppetmaster_$(openssl rand -hex 3)}

PUPPET_SERVER_TAG=latest
PUPPET_AGENT_TAGS=( latest )
export PUPPET_SERVER_TAG

echo "Using Puppet server '$PUPPET_SERVER_TAG' with agents: '${PUPPET_AGENT_TAGS[@]}'"

OSES=(
  "alpine"
  "ubuntu"
)

export COMPOSE_PROJECT_NAME
NETNAME=${COMPOSE_PROJECT_NAME//-/}_default
EXPECTED_PASSWORD="supersecretpassword"
EXPECTED_COMPLEX_ID_PASSWORD="complexidpassword"

cleanup() {
  echo "Ensuring clean state..."
  docker-compose down -v || true
}

build_windows_puppet_image() {
  cat ./windows-agent.Dockerfile | run_with_docker_windows docker build -t puppet-agent -
}

prepare_windows() {
  if [[ -z "${WINDOWS_DOCKER_HOST}" ]]; then
    echo "---";
    echo "Windows Daemon not available. Skipping tests for 'Windows'";

    return
  fi

  echo "---"
  echo "Windows Daemon available. Preparing test environment for 'Windows'"

  if [[ -z "${MAIN_HOST_IP}" ]]; then
    echo "MAIN_HOST_IP envvar must be set to accompany WINDOWS_DOCKER_HOST";
    exit 1;
  fi

  echo
  echo "=> Building puppet agent image for 'Windows' <="
  build_windows_puppet_image
}

main() {
  cleanup
  if [[ "${CLEAN_UP_ON_EXIT}" = true ]]; then
    trap cleanup EXIT
  fi

  prepare_windows

  start_services
  setup_conjur
  wait_for_puppet "puppet"
  wait_for_puppet "puppet-compiler"

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
      converge_node_hiera_manifest_apikey "$agent_image"

      echo "Tests for '$agent_image': OK"
    done
  done

  run_windows_tests

  echo "==="
  echo "ALL TESTS COMPLETED"
}

run_windows_tests() {
  # Run tests on Windows if there's a Windows Daemon
  if [[ -z "${WINDOWS_DOCKER_HOST}" ]]; then
    echo "---"

    echo "Tests for 'Windows': Skipped"
    return;
  fi

  echo "---"
  echo "Running tests for 'Windows'..."

  echo
  echo "=> Agent config, API Key <="
  converge_windows_node_agent_apikey

  echo
  echo "=> Hiera manifest config, API Key <="
  converge_windows_node_hiera_manifest_apikey

  echo "Tests for 'Windows': OK"
}

run_with_docker_windows() {
  local DOCKER_HOST=${WINDOWS_DOCKER_HOST}
  local DOCKER_CERT_PATH=${WINDOWS_DOCKER_CERT_PATH}
  local DOCKER_TLS_VERIFY=${WINDOWS_DOCKER_TLS_VERIFY}
  export DOCKER_HOST;
  export DOCKER_CERT_PATH;
  export DOCKER_TLS_VERIFY;
  export DOCKER_BUILDKIT=0

  "$@"
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
  echo "Starting services..."
  docker-compose up -d conjur-https puppet puppet-compiler
}

wait_for_conjur() {
  echo "Waiting for Conjur..."
  docker-compose exec -T conjur conjurctl wait
}

wait_for_puppet() {
  local server_name="$1"
  echo -n "Waiting on ${server_name} to be ready..."
  while ! run_in_conjur curl -ks https://${server_name}:8140 >/dev/null; do
    echo -n "."
    sleep 2
  done
  echo "OK"
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
  local modules_dir="/etc/puppetlabs/code/environments/production/modules"
  local target="$modules_dir/conjur"
  run_in_puppet bash -c "
    rm -rf "$target"; \
    mkdir -p "$modules_dir"; \
    ln -fs /conjur "$target"
  "
}

install_conjur_module() {
  echo "Installing packaged cyberark-conjur module to server..."
  run_in_puppet bash -c "
    puppet module install /conjur/pkg/cyberark-conjur.tar.gz --force;
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

  echo "-----"
  echo "Setting variable values"
  echo "-----"
  run_in_conjur_cli conjur variable values add \
    'inventory/db-password' "$EXPECTED_PASSWORD"
  run_in_conjur_cli conjur variable values add \
    'inventory/funky/special @#$%^&*(){}[].,+/variable' "$EXPECTED_COMPLEX_ID_PASSWORD"
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
  local hostname="${node_name}-$(openssl rand -hex 3)"

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
            --summarize \
            --certname "$hostname" \
            --ca_server puppet \
            --server puppet-compiler
  set +x

  rm -rf $TMPDIR
}

converge_node_hiera_manifest_apikey() {
  local agent_image="$1"
  local node_name="hiera-manifest-apikey-node"
  local hostname="${node_name}-$(openssl rand -hex 3)"

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
      \$output_file1  = '/tmp/creds1.txt'
      \$output_file2  = '/tmp/creds2.txt'
      \$secret = Sensitive(Deferred(conjur::secret, ['inventory/db-password', {
          appliance_url => lookup('conjur::appliance_url'),
          account => lookup('conjur::account'),
          authn_login => lookup('conjur::authn_login'),
          authn_api_key => lookup('conjur::authn_api_key'),
          ssl_certificate => lookup('conjur::ssl_certificate')
      }]))

      \$funky_secret = Sensitive(Deferred(conjur::secret, ['inventory/funky/special @#$%^&*(){}[].,+/variable', {
          appliance_url => lookup('conjur::appliance_url'),
          account => lookup('conjur::account'),
          authn_login => lookup('conjur::authn_login'),
          authn_api_key => lookup('conjur::authn_api_key'),
          ssl_certificate => lookup('conjur::ssl_certificate')
      }]))

      notify { \"Writing secret to \${output_file1}...\": }
      file { \$output_file1:
        ensure  => file,
        content => \$secret,
      }

      notify { \"Writing funky secret to \${output_file2}...\": }
      file { \$output_file2:
        ensure  => file,
        content => \$funky_secret,
      }

      exec { \"cat \${output_file1}\":
        path      => '/usr/bin:/usr/sbin:/bin',
        provider  => shell,
        logoutput => true,
      }

      exec { \"cat \${output_file2}\":
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
            --certname "$hostname" \
            --ca_server puppet \
            --server puppet-compiler
  set +x

  rm -rf "$manifest_config_file" "$hiera_config_file"
}

converge_windows_node_agent_apikey() {
  local node_name="agent-apikey-node"
  local hostname="${node_name}-$(openssl rand -hex 3)"

  local login="host/$node_name"
  local api_key=$(get_host_key $node_name)
  echo "API key for $node_name: $api_key"

  revoke_cert_for "$hostname"

  set -x
  run_with_docker_windows docker run --rm -t \
    --hostname "${hostname}" \
    puppet-agent \
      powershell -Command "
        # Allow resolution of the hostnames for conjur and puppet
        Add-Content -Path 'c:\Windows\System32\Drivers\etc\hosts' -Value '${MAIN_HOST_IP} conjur.cyberark.com'
        Add-Content -Path 'c:\Windows\System32\Drivers\etc\hosts' -Value '${MAIN_HOST_IP} puppet'
        Add-Content -Path 'c:\Windows\System32\Drivers\etc\hosts' -Value '${MAIN_HOST_IP} puppet-compiler'
        Add-Content -Path 'c:\conjur-ca.crt' -Value '$(cat $PWD/https_config/ca.crt)'


        # Set conjur.conf equivalent with connection details
        reg ADD HKLM\Software\CyberArk\Conjur /v ApplianceUrl /t REG_SZ /d https://conjur.cyberark.com:$(conjur_host_port)/
        reg ADD HKLM\Software\CyberArk\Conjur /v Version /t REG_DWORD /d 5
        reg ADD HKLM\Software\CyberArk\Conjur /v Account /t REG_SZ /d cucumber
        reg ADD HKLM\Software\CyberArk\Conjur /v CertFile /t REG_SZ /d c:\conjur-ca.crt

        # Set conjur.identity equivalent with auth details
        cmdkey /generic:conjur.cyberark.com /user:${login} /pass:${api_key}

        puppet agent --verbose --onetime --no-daemonize --summarize --masterport $(puppet_host_port) --certname \$(hostname) --ca_server puppet --server puppet-compiler
      "
  set +x
}

converge_windows_node_hiera_manifest_apikey() {
  local node_name="hiera-manifest-apikey-node"
  local hostname="${node_name}-$(openssl rand -hex 3)"

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
      \$pem_file  = 'c:\tmp\test.pem'
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

      exec { \"Read secret from \${pem_file}...\":
        command => \"C:\Windows\System32\cmd.exe /c type \${pem_file}\",
        logoutput => true,
      }
    }" > $manifest_config_file

  revoke_cert_for "$hostname"

  set -x
  run_with_docker_windows \
    docker run --rm -t \
      --hostname "${hostname}" \
      puppet-agent \
        powershell -Command "
          # Allow resolution of the hostnames for conjur and puppet
          Add-Content -Path 'c:\Windows\System32\Drivers\etc\hosts' -Value '${MAIN_HOST_IP} conjur.cyberark.com'
          Add-Content -Path 'c:\Windows\System32\Drivers\etc\hosts' -Value '${MAIN_HOST_IP} puppet'
          Add-Content -Path 'c:\Windows\System32\Drivers\etc\hosts' -Value '${MAIN_HOST_IP} puppet-compiler'

          puppet agent --verbose --onetime --no-daemonize --summarize --masterport $(puppet_host_port) --certname \$(hostname) --ca_server puppet --server puppet-compiler
        "
  set +x

  rm -rf "$manifest_config_file" "$hiera_config_file"
}

main "$@"
