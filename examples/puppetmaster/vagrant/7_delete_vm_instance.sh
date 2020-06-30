#!/bin/bash

# Destroy a VM. (Note: The Vagrant box image associated with the VM will be
# retained for the next 'vagrant up').

set -eou pipefail

echo "Deleting the VM instance"
vagrant destroy -f
