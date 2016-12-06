#!/bin/bash -ex

docker-compose build

docker-compose up -d conjur
docker-compose exec -T conjur /opt/conjur/evoke/bin/wait_for_conjur > /dev/null
echo Conjur is ready
echo Loading base policies
docker-compose exec -T conjur env CONJUR_AUTHN_LOGIN=admin \
  CONJUR_AUTHN_API_KEY=secret \
  CONJUR_APPLIANCE_URL=http://localhost/api \
  CONJUR_ACCOUNT=cucumber \
  conjur policy load --as-group security_admin /var/lib/possum-example/policy/conjur.yml

echo Loading policy extensions
docker-compose exec -T conjur env CONJUR_AUTHN_LOGIN=admin \
  CONJUR_AUTHN_API_KEY=secret \
  CONJUR_APPLIANCE_URL=http://localhost/api \
  CONJUR_ACCOUNT=cucumber \
  conjur policy load --as-group security_admin /var/puppet-policies/conjur.yml

echo Creating host factory token
docker-compose exec -T conjur env CONJUR_AUTHN_LOGIN=admin \
  CONJUR_AUTHN_API_KEY=secret \
  CONJUR_APPLIANCE_URL=http://localhost/api \
  CONJUR_ACCOUNT=cucumber \
  conjur hostfactory tokens create --duration-days 365 prod/inventory | tee inventory_token.json

cat inventory_token.json | docker-compose run --rm jq -r ".[0].token" > inventory_token.txt

docker-compose exec -T conjur cat /opt/conjur/etc/ssl/ca.pem > conjur.pem

docker-compose up -d puppetdbpostgres puppetdb puppet puppetboard puppetexplorer
