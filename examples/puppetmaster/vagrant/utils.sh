export BASE_SNAPSHOT_NAME="base-install"

# Return major version (first digit) for a semantic version string
function semver_major_version() {
  digits=( ${1//./ } )
  echo "${digits[0]}"
}

# Return the host port for the Conjur server. This requires that the
# COMPOSE_PROJECT_NAME environment variable be set appropriately.
function conjur_host_port() {
  echo "$(docker-compose port conjur 80 | awk -F ':' '{print $2}')"
}

# Return the host port for the Puppet server. This requires that the
# COMPOSE_PROJECT_NAME environment variable be set appropriately.
function puppet_host_port() {
  echo "$(docker-compose port puppet 8140 | awk -F ':' '{print $2}')"
}

# Return the name of a matching snapshot when provided with a puppet
# agent version as a parameter.
function agent_snapshot_name() {
  agent_version="$1"
  echo "puppet-agent-${agent_version}-installed"
}
