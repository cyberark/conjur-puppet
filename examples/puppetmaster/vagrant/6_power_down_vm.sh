#!/bin/bash

# Halt (power down) a Windows VM.

set -eou pipefail

echo "Powering down the VM"
vagrant halt
