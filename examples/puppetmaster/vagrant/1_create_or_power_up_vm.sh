#!/bin/bash

# Start up a Windows VM.
#
# To use Windows2012, set the following environment variables:
#      export VAGRANT_CWD="windows2012"
# To use Windows2016, set the following environment variables:
#      export VAGRANT_CWD="windows2016"

set -eou pipefail

base_snapshot_name="base-install"

echo "Restoring base snapshot (if available)..."
if ! vagrant snapshot restore "$base_snapshot_name"; then
  echo "Base snapshot not found - creating it..."

  echo "Starting up the Windows VM"
  vagrant up

  vagrant snapshot save "$base_snapshot_name"
fi

echo "VM base is ready"
