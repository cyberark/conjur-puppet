#!/bin/bash -ex

host_id=puppet/$HOSTNAME
token=$(cat /etc/hostfactory_token.txt)
conjur hostfactory hosts create $token $host_id > /etc/host.json
api_key=$(cat /etc/host.json | jq -r .api_key)

cat <<NETRC > /root/.netrc
machine https://conjur/api/authn
  login host/$host_id
  password $api_key
NETRC
chmod 0600 /root/.netrc

/opt/puppetlabs/bin/puppet agent --verbose --onetime --no-daemonize --summarize
