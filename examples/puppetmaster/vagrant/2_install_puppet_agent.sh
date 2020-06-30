#!/bin/bash

# Download the Microsoft Install (MSI) file for a given version of Puppet
# agent (if necessary) and install it on a Windows VM

set -eou pipefail

source utils.sh

# Download MSI file if it doesn't exist in the current directory.
msi_file="puppet-agent-$PUPPET_AGENT_VERSION-x64.msi"

echo "Checking for file $msi_file in current directory"
if [ ! -f $msi_file ]; then

    echo "File $msi_file is not found"
    major_version="$(semver_major_version $PUPPET_AGENT_VERSION)"

    echo "Extracted major version of $major_version"
    msi_download="https://downloads.puppetlabs.com/windows/puppet$major_version/$msi_file"

    echo "Downloading $msi_download"
    wget $msi_download
fi

echo "Installing Puppet Agent version $PUPPET_AGENT_VERSION in Windows VM"
vagrant powershell -e -c "/vagrant/install_puppet_agent.ps1 $msi_file"
