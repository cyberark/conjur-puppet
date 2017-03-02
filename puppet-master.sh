#!/bin/bash -e
# Launches a Puppet master stack in Docker Compose

docker-compose -f docker-compose.puppet.yml down
rm -rf puppet puppetdb puppetdb-postgres
docker-compose -f docker-compose.puppet.yml up -d
