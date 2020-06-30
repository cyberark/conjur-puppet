#!/bin/bash

# Start up a Windows VM.
#
# To use Windows2012, set the following environment variables:
#      export VAGRANT_CWD="windows2012"
# To use Windows2016, set the following environment variables:
#      export VAGRANT_CWD="windows2016"

set -eou pipefail

echo "Start up the Windows VM"
vagrant up
