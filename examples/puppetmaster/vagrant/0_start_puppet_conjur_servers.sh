#!/bin/bash

# Start up a Puppet server and a Conjur Server

set -eou pipefail

source utils.sh

major_version="$(semver_major_version $PUPPET_AGENT_VERSION)"

echo "Starting up Puppet and Conjur servers"
export CLEAN_UP_ON_EXIT=false
cd ..
./smoketest_e2e.sh $major_version
