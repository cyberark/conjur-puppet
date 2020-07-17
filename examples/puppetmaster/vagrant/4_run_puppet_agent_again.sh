#!/bin/bash

# Clear any artifacts from VM that might have been created from a previous
# run of Puppet Agent.

set -eou pipefail

source utils.sh

echo "Ensuring synced time..."
vagrant powershell -e -c "net start w32time" || true
vagrant powershell -e -c "W32tm /resync /force"

echo "Running agent converge again..."
vagrant powershell -e -c "puppet agent -t --verbose --debug --masterport $(puppet_host_port)"
