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


### Setup Requirements **OPTIONAL**

This module requires that you have a Conjur endpoint available to the Puppet nodes using this module.

### Beginning with conjur

The simplest use case is to use the configuration provided by `/etc/conjur.conf` and `/etc/conjur.identity`. These files can be written as part of the node’s bootstrap process, [exchanging a Host Factory token for Conjur machine identity](https://developer.conjur.net/reference/services/host_factory/#bootstrapping). This module will check for the existence of these files. If they are present, the non-secret data in these files will be loaded as Puppet facts and used as default configuration for the conjur class. Enable the module by simply including the class:

    include ::conjur

This module provides a `conjur_secret` function that can be used to retrieve secrets from Conjur. Given a Conjur variable identifier, `conjur_secret` uses the node’s Conjur identity to resolve and return the variable’s value.

    dbpass = conjur_secret('production/postgres/password')

Hiera attributes can also be used to inform which secret should be fetched, depending on the node running the Conjur module. For example, if `hiera('domain')` returns `app1.example.com` and a Conjur variable named `domains/app1.example.com/ssl-cert` exists, the SSL certificate can be retrieved and written to a file like so:

    file { '/etc/ssl/cert.pem':
      content => conjur_secret("domains/%{hiera('domain')}/ssl-cert"),
      ensure => file,
      show_diff => false  # don't log file content!
    }

## Usage

This module provides the conjur_secret function, described above, and the conjur class, which can be configured to establish Conjur host identity on the node running Puppet.

### Conjur host identity with Host Factory

We recommend bootstrapping Conjur host identity using a Host Factory token. Nodes inherit the permissions of the layer for which the Host Factory token was generated.

To use a Host Factory token with this module, set variables `authn_login` and `host_factory_token`. Do not set the variable `authn_api_key` when using `host_factory_token`; it is not required. The value of variable `authn_login` will be used as the node’s name in Conjur.

    include ::conjur

    class { '::conjur':
      account         => 'mycompany',
      appliance_url   => 'https://conjur.mycompany.com/api',
      authn_login     => 'host/redis001',
      cidr            => '192.168.0.15/24',
      host_factory_token => '3zt94bb200p69nanj64v9sdn1e15rjqqt12kf68x1d6gb7z33vfskx',
      annotations     => {:sox => true, :region => 'us-east-1'},
      ssl_certificate => '-----BEGIN CERTIFICATE----- … -----END CERTIFICATE-----'
    }

Note the optional `annotations` variable. When the node is bootstrapped with `host_factory_token`, this hash will be passed to Host Factory and these annotations will be set on the host in Conjur. Setting annotations makes it easier to find groups of hosts managed by Puppet in Conjur. By default, all nodes using this Puppet module to bootstrap identity with `host_factory_token` will have the following annotations set:

- `puppet`: true
- `puppet/environment`: Puppet environment of the node.
- `puppet/master-host`: Hostname of the Puppet master.

### Conjur host identity with API key

For one-off hosts or test environments it may be preferable to create a host in Conjur and then directly assign its Conjur identity in this module.

    include ::conjur

    class { ‘::conjur’:
      account         => ‘mycompany’,
      appliance_url   => ‘https://conjur.mycompany.com/api’,
      authn_login     => ‘host/redis001’,
      authn_api_key   => ‘f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3’,
      ssl_certificate_file => ‘/etc/conjur-mycompany.pem’
    }

annotations cannot be used when directly assigning the host identity.

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

##### `account`
Organization name, given during Conjur initialization.

##### `appliance_url`
A Conjur endpoint with trailing /api.

##### `authn_login`
User username or host name (prefixed with host/').

##### `authn_api_key`
API key for a user or host.

##### `host_factory_token`
A valid Host Factory token used to bootstrap node’s Conjur identity.

##### `annotations`
Hash of annotations to add to the node when bootstrapping with Host Factory.

##### `ssl_certificate`
Content of the public SSL cert (given at conjur init).

##### `ssl_certificate_file`
Absolute file path of the public SSL cert (given at conjur init).

##### `token`
Raw (unencoded) Conjur token. This is usually only useful for testing.

##### `conjur_conf_file`
Absolute file path of the Conjur configuration file. Default ‘/etc/conjur.conf’.

##### `conjur_identity_file`
Absolute file path of the Conjur identity file. Default ‘/etc/conjur.identity’.

#### Example

    include ::conjur

    class { ‘::conjur’:
      account         => ‘mycompany’,
      appliance_url   => ‘https://conjur.mycompany.com/api’,
      authn_login     => ‘host/redis001’,
      authn_api_key   => ‘f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3’,
      host_factory_token => ‘3zt94bb200p69nanj64v9sdn1e15rjqqt12kf68x1d6gb7z33vfskx’,
      annotations => {:sox => true, :region => ‘us-east-1’},
      ssl_certificate => ‘-----BEGIN CERTIFICATE-----...’,
      ssl_certificate_file => ‘/etc/conjur-mycompany.pem’,
      conjur_conf_file = > ‘/opt/conjur.conf’,
      conjur_identity_file => ‘/opt/conjur.identity’
    }

### `conjur_secret`

This function uses the node’s Conjur host identity to authenticate with Conjur and retrieve a secret that the node is authorized to fetch. The output of this function is a string that contains the value of the variable parameter. If the secret cannot be fetched an error is thrown.

#### Parameters

##### `variable`
The identifier of a Conjur variable to retrieve.

#### Example

    dbpass = conjur_secret(‘production/postgres/password’)

## Limitations

See metadata.json for supported platforms

## Development

Open an issue or fork this project and open a Pull Request.
