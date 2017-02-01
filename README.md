# conjur

#### Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with conjur](#setup)
    * [What conjur affects](#what-conjur-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with conjur](#beginning-with-conjur)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

This is the official Puppet module for [Conjur](https://conjur.com), a robust identity and access management platform. This module simplifies the operations of establishing Conjur host identity and allows authorized Puppet nodes to fetch secrets from Conjur.

## Setup

### Setup Requirements

This module requires that you have a Conjur endpoint available to the Puppet nodes using this module.

### Beginning with conjur

This module provides a `conjur_secret` function that can be used to retrieve secrets from Conjur. Given a Conjur variable identifier, `conjur_secret` uses the node’s Conjur identity to resolve and return the variable’s value.

    dbpass = conjur_secret('production/postgres/password')

Hiera attributes can also be used to inform which secret should be fetched, depending on the node running the Conjur module. For example, if `hiera('domain')` returns `app1.example.com` and a Conjur variable named `domains/app1.example.com/ssl-cert` exists, the SSL certificate can be retrieved and written to a file like so:

    file { '/etc/ssl/cert.pem':
      content => conjur_secret("domains/%{hiera('domain')}/ssl-cert"),
      ensure => file,
      show_diff => false  # don't log file content!
    }

## Usage

This module provides the `conjur_secret` function, described above, and the `conjur` class, which can be configured to establish Conjur host identity on the node running Puppet.

### Conjur host identity with API key

For one-off hosts or test environments it may be preferable to create a host in Conjur and then directly assign its Conjur identity in this module.

    class { conjur:
      appliance_url   => 'https://conjur.mycompany.com/api',
      authn_login     => 'host/redis001',
      authn_api_key   => 'f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3',
    }

## Reference

### Classes

#### Public Classes

* `::conjur`

### Functions

#### Public Functions

* `conjur_secret`

### `::conjur`

This class establishes Conjur host identity on the node so that secrets can be fetched from Conjur. Two files are written to the filesystem on the Puppet node when this class is used, conjur.conf and conjur.identity. These files allow the conjur_secret function to authenticate and authorize with Conjur.

#### Parameters

##### `appliance_url`
A Conjur endpoint with trailing `/api`.

##### `authn_login`
User username or host name (prefixed with `host/`).

##### `authn_api_key`
API key for a user or host.

##### `authn_token`
Raw (unencoded) Conjur token. This is usually only useful for testing.

#### Example

    class { conjur:
      appliance_url   => 'https://conjur.mycompany.com/api',
      authn_login     => 'host/redis001',
      authn_api_key   => 'f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3',
    }

### `conjur_secret`

This function uses the node’s Conjur host identity to authenticate with Conjur and retrieve a secret that the node is authorized to fetch. The output of this function is a string that contains the value of the variable parameter. If the secret cannot be fetched an error is thrown.

#### Parameters

##### `variable`
The identifier of a Conjur variable to retrieve.

#### Example

    dbpass = conjur_secret('production/postgres/password')

## Limitations

See metadata.json for supported platforms

## Development

Open an issue or fork this project and open a Pull Request.

### Running a Conjur server locally

Run a preconfigured Conjur instance with `docker-compose up -d`.
Username is 'admin', password is 'secret'. The HTTPS endpoint is mapped to port `9443`.
Once the server is running, view the UI at [localhost:9443](https://localhost:9443).
You can ignore the cert warning; a self-signed cert is used.

### Running a Puppet master locally

Run a Puppet master with `./puppet-master.sh`. This script wraps running `docker-compose.puppet.yml`, where
all services needed to run the master are defined. The `code` directory in this project is mounted
onto the master at `/etc/puppetlabs/code/`. Open [localhost:8080](http://localhost:8080) to view the Puppet Dashboard.
You can stop and remove all services with `docker-compose -f docker-compose.puppet.yml down`.

### Running a Puppet node locally

Puppet [provides Docker images](https://github.com/puppetlabs/puppet-in-docker#description)
that make running ephemral Puppet agents pretty easy.

For example, once the Puppet master is up you can run this to converge an agent:

```sh-session
$ docker run --rm --net puppet_default puppet/puppet-agent-ubuntu
```

You will see Puppet converge on the node.

A couple notes:

1. docker-compose creates the `puppet_default` by default. The agent needs to connect to this
   network to be able to see the Puppet master.
2. The default command for these agent images is `agent --verbose --one-time --no-daemonize --summarize`.
   The default entrypoint is `/opt/puppetlabs/bin/puppet `.
   This can easily be overridden for your purposes, e.g.

   ```sh-session
   $ docker run --rm --net puppet_default \
     puppet/puppet-agent-ubuntu apply --modulepath=$PWD examples/init.pp
   ```

   Note that if you want to run manifests directly then need to be mounted into the container.

