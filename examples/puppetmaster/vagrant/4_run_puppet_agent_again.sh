#!/bin/bash

# Clear any artifacts from VM that might have been created from a previous
# run of Puppet Agent.

set -eou pipefail

source utils.sh

echo "Ensuring synced time..."
vagrant powershell -e -c "net start w32time" &>/dev/null || true
vagrant powershell -e -c "W32tm /resync /force" &>/dev/null

echo "Running agent converge again..."
vagrant powershell -e -c "puppet agent --onetime \
                                       --no-daemonize \
                                       --no-usecacheonfailure \
                                       --no-splay \
                                       --masterport '$(puppet_host_port)'"
