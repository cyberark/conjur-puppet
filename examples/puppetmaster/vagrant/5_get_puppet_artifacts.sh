#!/bin/bash

# Retrieve artifacts that were created on the VM by Puppet Agent.

set -eou pipefail

echo 'Getting C:\tmp\creds1.txt from Windows VM'
vagrant powershell -c 'cat \tmp\creds1.txt'

echo 'Getting C:\tmp\creds2.txt from Windows VM'
vagrant powershell -c 'cat \tmp\creds2.txt'
