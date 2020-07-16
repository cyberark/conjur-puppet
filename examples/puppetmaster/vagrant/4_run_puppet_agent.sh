#!/bin/bash

set -eou pipefail

source utils.sh

# The Vagrantfiles in this repo set their VMs' hostnames to the directory
# in which they appear. Conveniently, this is the directory to which the
# VAGRANT_CWD environment variable points.
hostname="$VAGRANT_CWD"

snapshot_name="$(agent_snapshot_name $PUPPET_AGENT_VERSION)"

echo "Restoring snapshot to '$snapshot_name'..."
vagrant snapshot restore "$snapshot_name"

echo "Adding Conjur connection info to Windows registry"
vagrant powershell -e -c "/vagrant/add_conjur_registry.ps1 $(conjur_host_port)"

echo "Rotating Conjur API key for host 'node01'"
conjur_ctl_container=$(docker ps | awk '/cyberark\/conjur-cli/{print $1}')
node_api_key="$(docker exec $conjur_ctl_container conjur host rotate_api_key -h node01)"

echo "Adding rotated Conjur API key to Windows Credentials Manager"
vagrant powershell -e -c "/vagrant/add_conjur_creds.ps1 $node_api_key $(conjur_host_port)"

echo "Ensuring synced time..."
vagrant powershell -e -c "W32tm /resync /force"

echo "Clearing any previous certs generated for \"$hostname\" from Puppet server..."
puppet_master_container=$(docker ps | awk '/puppet\/puppetserver/{print $1}')
# Ignore errors since there might not be any certificates to clear

signed_certs=$(docker exec "$puppet_master_container" ls -A1 /etc/puppetlabs/puppet/ssl/ca/signed/)
signed_cert=$(echo "$signed_certs" | grep "^$hostname" || true)

cert_fqdn="${signed_cert%.pem}"
if [ "$cert_fqdn" != "" ]; then
  echo "Old cert found for '$cert_fqdn'. Trying to revoke/clean..."

  # We try first with Puppet v5 CLI (`puppet cert`)
  docker exec "$puppet_master_container" \
    puppet cert clean "$cert_fqdn" &>/dev/null || true

  # Then we try the Puppet v6 CLI (`puppetserver ca`). Clean is not very predictable so
  # we also do a revoke before it.
  docker exec "$puppet_master_container" \
    puppetserver ca revoke --certname "$cert_fqdn" || true
  docker exec "$puppet_master_container" \
    puppetserver ca clean --certname "$cert_fqdn" || true
fi

# When the Puppet server tries to retrieve the API token for host 'node01'
# from Conjur, it will use the Conjur URL provided by the Puppet agent,
# which will be of the form 'https://conjur:<random-host-port>'. This random
# host port is bound to host IPs only, so create an /etc/hosts entry for
# 'conjur' to point to the Docker Compose gateway on the host.
gateway_ip="$(docker exec $puppet_master_container netstat -rn | grep "0.0.0.0.*UG" | awk '{print $2}')"

echo "Adding/modifying /etc/hosts entry in puppet server: \"$gateway_ip conjur\""
# Make a temporary copy of /etc/hosts to make modifications since `sed` is
# is not able to directly modify /etc/hosts when it is run via 'docker exec'.
docker exec $puppet_master_container bash -c \
    "cp /etc/hosts /tmp/hosts; \
     sed -i $'/\tconjur$/d' /tmp/hosts; \
     echo $'$gateway_ip\tconjur' >> /tmp/hosts; \
     cp /tmp/hosts /etc/hosts"

echo "Setting env variables to customize the Puppet manifest for this node"
vagrant powershell -e -c /vagrant/set_facter_env.ps1

echo "Clearing previous Puppet certificates from VM and running Puppet Agent"
vagrant powershell -e -c "/vagrant/run_puppet_agent.ps1 $(puppet_host_port)"
