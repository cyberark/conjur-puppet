# Vagrant/VirtualBox-Based Development Environment for Testing Puppet Agent on Windows

#### Table of Contents

- [Overview](#overview)
  * [Reusing "Long-Standing" VMs](#reusing--long-standing--vms)
  * [No Windows Desktop Interaction Required](#no-windows-desktop-interaction-required)
- [Setting Up](#setting-up)
  * [Setup Requirements](#setup-requirements)
  * [Clone this Repository](#clone-this-repository)
  * [Setting up VirtualBox](#setting-up-virtualbox)
    + [Install VirtualBox](#install-virtualbox)
  * [Setting Up Vagrant](#setting-up-vagrant)
    + [Install Vagrant](#install-vagrant)
    + [Install the Vagrant Reload Provisioner Plugin](#install-the-vagrant-reload-provisioner-plugin)
- [Running the Installation and Test Scripts](#running-the-installation-and-test-scripts)
  * [Set Environment Variables](#set-environment-variables)
  * [Create Puppet and Conjur Server Containers](#create-puppet-and-conjur-server-containers)
  * [Create or Power Up Windows VM](#create-or-power-up-windows-vm)
  * [Install Puppet Agent on the Windows VM](#install-puppet-agent-on-the-windows-vm)
  * [Clear Previous Provisioning Results (if Necessary)](#clear-previous-provisioning-results--if-necessary-)
  * [Run Puppet Agent and Confirm Provisioning Results](#run-puppet-agent-and-confirm-provisioning-results)
  * [Power Down the VM](#power-down-the-vm)
  * [Delete the VM Instance](#delete-the-vm-instance)
  * [Delete the Vagrant Box Image](#delete-the-vagrant-box-image)
  * [Delete the Puppet Server and Conjur Server](#delete-the-puppet-server-and-conjur-server)

## Overview

This directory contains Vagrantfiles, Bash scripts, and PowerShell scripts
that can be used to create a Vagrant/VirtualBox-based development and test
environment for testing the Conjur Puppet module with Puppet Agents running
on Windows2016 or Windows2012.

The Vagrantfiles and scripts can be used to:

- Spin up a containerized Puppet Server and Conjur server via docker-compose.
- Create a Windows2016 or Windows2012 VM.
- Dynamically install the desired version of Puppet Agent on the VM.
- Run Puppet Agent on the VM to install a Puppet catalog.
- Confirm that Puppet has been provisioned according to the configured
  Puppet manifest on the Puppet master.

### Reusing "Long-Standing" VMs

The scripts in this directory can be used to dynamically install or re-install
(overwrite) different versions of Puppet Agent on an existing Windows VM.
Developers can therefore create a "long-standing" VM for each version of
Windows being tested (kept in the powered-down state when not
in use), and then power up and re-use the VMs as needed. This saves time
in test iterations, since VM creation can take several minutes to create
from scratch.

### No Windows Desktop Interaction Required

Using this Vagrant-based development environment does not require any
user interaction with the Windows Desktop. The scripts are designed to
be completely driven from the host. (Of course, the Windows Desktop is
available via VirtualBox console if you should need it for any reason).

The connection mechanisms between the host and the Windows VM that allow
this host-driven testing are as follows:

- PowerShell scripts in this directory are synced to /vagrant on the VM.
- The `vagrant powershell` command is used from the host to execute
  powershell commands or scripts remotely on the VM guest. (The `vagrant
  powershell` command makes use of Windows Remote Management, or WinRM,
  running on the VM. SSH is not enabled on Windows VMs by default).
- The services for the Puppet server and Conjur server are exposed 
  to the Windows VM via random host ports.

## Setting Up

### Setup Requirements

- Oracle VirtualBox, Version 6.0 or later (see the
  [Setting Up VirtualBox](#setting-up-virtualbox) section below).
- Vagrant, Version 2.2.9 or later (see the
  [Setting Up Vagrant](#setting-up-vagrant) section below).
- 60 GB of free disk space on your development server for each version of
  Windows VM with that you would like to test.

### Clone this Repository

Make a local copy of this repository as follows:

```sh-session
    git clone https://github.com/cyberark/conjur-puppet
    cd examples/puppetmaster/vagrant
```

### Setting up VirtualBox

#### Install VirtualBox

This development environment requires that you have VirtualBox, Version 6.0
or later. To install, follow installation instructions
[here](https://docs.oracle.com/en/virtualization/virtualbox/6.1/user/installation.html).

### Setting Up Vagrant

#### Install Vagrant

This development environment requires that you have Vagrant, Version 2.2.9
or later. To install, follow installation instructions
[here](https://www.vagrantup.com/docs/installation).

#### Install the Vagrant Reload Provisioner Plugin

The [Vagrant Reload Provisioner](#https://github.com/aidanns/vagrant-reload)
plugin can be used to conveniently reload a VM after a provisioning step
has been done that requires a system reboot.

To install the Vagrant Reload Provisioner plugin:

```sh-session
    vagrant plugin install vagrant-reload
```

## Running the Installation and Test Scripts

### Set Environment Variables

The installation and test scripts in this directory require that the
following environment variables be set and exported:

- `COMPOSE_PROJECT_NAME`: Docker-compose project name to use for creating
  Puppet and Conjur server containers.
- `PUPPET_AGENT_VERSION`: Version of Puppet Agent to install in Windows VM.
  Available versions can be found here (for Puppet Versions 5 and 6
  respectively):
  - https://downloads.puppetlabs.com/windows/puppet5/
  - https://downloads.puppetlabs.com/windows/puppet6/
- `VAGRANT_CWD`: Subdirectory that contains the Vagrantfile for the
  desired version of Windows. Valid choices are:
  - `windows2012`
  - `windows2016`

For example:

```sh-session

    # Example environment for testing Puppet Agent v5.5.8 on Windows2012
    export COMPOSE_PROJECT_NAME="puppetmaster_$(openssl rand -hex 3)"
    export PUPPET_AGENT_VERSION="5.5.8"
    export VAGRANT_CWD="windows2012"
```

Alternatively, you can modify the environment settings in `set_env.sh`,
and then run:

```sh-session
    source set_env.sh
```

### Create Puppet and Conjur Server Containers

To create Puppet and Conjur server containers, run:

```sh-session
    ./0_start_puppet_conjur_servers.sh
```

### Create or Power Up Windows VM

To create a Windows VM or power up an existing Windows VM, run:

```sh-session
    ./1_create_or_power_up_vm.sh
```

After a few minutes and a few system reboots, you should see a Windows
desktop running.

_**NOTE: To log into the Windows VM Desktop from a Mac host, press
`Command`-`Delete`, rather than `Ctrl`-`Alt`-`Delete`.**_

_**NOTE: The user/password for logging into the Windows VM is either
`Vagrant`/`vagrant` or `Admin`/`vagrant`. (Either combination will work).**_

### Install Puppet Agent on the Windows VM

To install Puppet Agent on the Windows VM, run:

```sh-session
    ./2_install_puppet_agent.sh
```

### Clear Previous Provisioning Results (if Necessary)

If prior runs of Puppet Agent have been made on this VM instance,
then clear the previous provisioning results:

```sh-session
    ./3_clear_puppet_artifacts.sh
```

### Run Puppet Agent and Confirm Provisioning Results

To run Puppet Agent on the Windows VM and confirm that the VM has
been properly provisioned, run:

```sh-session
    ./4_run_puppet_agent.sh
    ./5_get_puppet_artifacts.sh
```

If provisioning is successful, the last command should show that the file
`C:\tmp\test.pem` on the VM contains the string `supersecretpassword`.

For example, the last command should result in the following output:

```sh-session
    $ ./5_get_puppet_artifacts.sh
    Getting C:\tmp\test.pem from Windows VM
    1 COMMIT_EDITMSG
        default: supersecretpassword
        default:
    ==> default: Command: cat \tmp\test.pem executed successfully with output code 0.
    $
```

### Power Down the VM

To halt (power down) the VM, run:

```sh-session
    ./6_power_down_vm.sh
```

### Delete the VM Instance

To delete the VM instance from your host, run:

```sh-session
    ./7_delete_vm_instance.sh
```

_NOTE: `vagrant destroy` will delete the VM **instance**. However, this
 command will not delete the Vagrant "box" (i.e. base) image that was used to
 create the VM instance. Retaining the Vagrant box image will save downloading
 time for the next time that that version of VM needs to be created. See the
 following section for steps to delete the Vagrant box image._

### Delete the Vagrant Box Image

To delete the Vagrant box (i.e. base) image that was used to create the VM
instance, run:

```sh-session
    vagrant box list
```

to list Vagrant box images that have been saved, and then run:

```sh-session
    vagrant box remove <box-image>
```

### Delete the Puppet Server and Conjur Server

To delete the Puppet server and Conjur server and their associated
containers, run:


```sh-session
    docker-compose down -v
```
