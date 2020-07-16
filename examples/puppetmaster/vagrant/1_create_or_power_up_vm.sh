#!/bin/bash

# Start up a Windows VM.
#
# To use Windows2012, set the following environment variables:
#      export VAGRANT_CWD="windows2012"
# To use Windows2016, set the following environment variables:
#      export VAGRANT_CWD="windows2016"

set -eou pipefail

source utils.sh

echo "Restoring base snapshot (if available)..."
if ! vagrant snapshot restore "$BASE_SNAPSHOT_NAME"; then
  echo "Base snapshot not found - creating it..."

  echo "Starting up the Windows VM"
  vagrant up

  echo "Enabling time sync service..."
  vagrant powershell -e -c "net start w32time"

  echo "Creating snapshot '$BASE_SNAPSHOT_NAME'"
  vagrant snapshot save "$BASE_SNAPSHOT_NAME"
fi

echo "VM base is ready"
