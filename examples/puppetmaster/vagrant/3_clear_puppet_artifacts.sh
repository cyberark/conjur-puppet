#!/bin/bash

# Clear any artifacts from VM that might have been created from a previous
# run of Puppet Agent.

set -eou pipefail

echo "Deleting C:\tmp\test.pem from Windows VM"
vagrant powershell -c "rm /tmp/test.pem"
