#!/bin/bash

# Retrieve artifacts that were created on the VM by Puppet Agent.

set -eou pipefail

echo "Getting C:\tmp\test.pem from Windows VM"
vagrant powershell -c "cat \tmp\test.pem"
