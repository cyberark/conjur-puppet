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

This module provides a `conjur::secret` function that can be used to retrieve secrets from Conjur. Given a Conjur variable identifier, `conjur::secret` uses the node’s Conjur identity to resolve and return the variable’s value.

    $dbpass = conjur::secret('production/postgres/password')

Hiera attributes can also be used to inform which secret should be fetched, depending on the node running the Conjur module. For example, if `hiera('domain')` returns `app1.example.com` and a Conjur variable named `domains/app1.example.com/ssl-cert` exists, the SSL certificate can be retrieved and written to a file like so:

    file { '/etc/ssl/cert.pem':
      content => conjur::secret("domains/%{hiera('domain')}/ssl-cert"),
      ensure => file
      show_diff => false # only required for Puppet < 4.6
      # diff will automatically get redacted in 4.6 if content is Sensitive
    }

#### Sensitive data type (Puppet >= 4.6)

Note in Puppet >= 4.6 `conjur::secret` returns values wrapped
in a `Sensitive` data type. In some contexts, such as string interpolation,
it might cause surprising results (interpolating to `Sensitive [value redacted]`).
This is intentional, as it makes it harder to accidentally mishandle secrets.

To use a secret as a string, you need to explicitly request it using the
`unwrap` function; the result of the processing should be again wrapped in
a `Sensitive` value.

In particular, you should not pass unwrapped secrets as resource parameters
if you can avoid it. Many resource types support `Sensitive` data type and
handle it correctly. If a resource you're using does not, file a bug.

    $dbpass = conjur::secret('production/postgres/password')

    # In Puppet 4.6, use Sensitive data type to handle anything sensitive
    $db_yaml = Sensitive("password: ${dbpass.unwrap}")

    file { '/etc/someservice/db.yaml':
      content => $db_yaml, # this correctly handles both Sensitive and String
      ensure => file,
      mode => '0600', # remember to limit reading
    }

## Usage

This module provides the `conjur::secret` function, described above, and the `conjur` class, which can be configured to establish Conjur host identity on the node running Puppet.

### Conjur host identity with Host Factory

We recommend bootstrapping Conjur host identity using a Host Factory token. Nodes inherit the permissions of the layer for which the Host Factory token was generated.

To use a Host Factory token with this module, set variables `authn_login` and `host_factory_token`. Do not set the variable `authn_api_key` when using `host_factory_token`; it is not required. `authn_login` should have a `host/` prefix; the part after the slash will be used as the node’s name in Conjur.

    class { conjur:
      account         => 'mycompany',
      appliance_url   => 'https://conjur.mycompany.com/api',
      authn_login     => 'host/redis001',
      host_factory_token => Sensitive('3zt94bb200p69nanj64v9sdn1e15rjqqt12kf68x1d6gb7z33vfskx'),
      ssl_certificate => @(EOT)
        -----BEGIN CERTIFICATE-----
        …
        -----END CERTIFICATE-----
        |-EOT
    }

By default, all nodes using this Puppet module to bootstrap identity with host_factory_token will have the following annotation set:

    puppet: true

### Conjur host identity with API key

For one-off hosts or test environments it may be preferable to create a host in Conjur and then directly assign its Conjur identity in this module.

    class { conjur:
      appliance_url => 'https://conjur.mycompany.com/api',
      authn_login => 'host/redis001',
      authn_api_key => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
      ssl_certificate => file('conjur-ca.pem')
    }

## Reference

### Classes

#### Public Classes

* `::conjur`

### Functions

#### Public Functions

* `conjur::secret`

### `::conjur`

This class establishes Conjur host identity on the node so that secrets can be fetched from Conjur. Two files are written to the filesystem on the Puppet node when this class is used, conjur.conf and conjur.identity. These files allow the conjur::secret function to authenticate and authorize with Conjur.

#### Note

Several parameters (ie. API keys) are of `Sensitive` data type on Puppet >= 4.6.
To pass a normal string, you need to wrap it using `Sensitive("example")`.

#### Parameters

##### `appliance_url`
A Conjur endpoint with trailing `/api`.

##### `authn_login`
User username or host name (prefixed with `host/`).

##### `authn_api_key`
API key for a user or host. Must be `Sensitive` if supported.

##### `ssl_certificate`
X509 certificate of the root CA of Conjur, PEM formatted.

##### `host_factory_token`
You can use a host factory token to obtain a host identity. Must be `Sensitive` if supported.
Simply use this parameter to set it. The host record will be created in Conjur.

##### `authn_token`
Raw (unencoded) Conjur token. This is usually only useful for testing.
Must be `Sensitive` if supported.

#### Example

    class { conjur:
      appliance_url => 'https://conjur.mycompany.com/api',
      authn_login => 'host/redis001',
      authn_api_key => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
      ssl_certificate => file('conjur-ca.pem')
    }

### `conjur::secret`

This function uses the node’s Conjur host identity to authenticate with Conjur and retrieve a secret that the node is authorized to fetch. The output of this function is a string that contains the value of the variable parameter. If the secret cannot be fetched an error is thrown.

The returned value is `Sensitive` data type if supported (see notes above).

#### Parameters

##### `variable`
The identifier of a Conjur variable to retrieve.

#### Example

    dbpass = conjur::secret('production/postgres/password')

## Limitations

See metadata.json for supported platforms

## Development

Open an issue or fork this project and open a Pull Request.

### Running a Conjur server locally

Run a preconfigured Conjur instance with `docker-compose up -d`.
Username is 'admin', password is 'secret'. The HTTPS endpoint is mapped to port `9443`.
Once the server is running, view the UI at [localhost:9443/ui](https://localhost:9443/ui).
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

1. docker-compose creates the `puppet_default` network by default. The agent needs to connect to this
   network to be able to see the Puppet master.
2. The default command for these agent images is `agent --verbose --one-time --no-daemonize --summarize`.
   The default entrypoint is `/opt/puppetlabs/bin/puppet `.
   This can easily be overridden for your purposes, e.g.

   ```sh-session
   $ docker run --rm --net puppet_default \
     puppet/puppet-agent-ubuntu apply --modulepath=$PWD examples/init.pp
   ```

   Note that if you want to run manifests directly then need to be mounted into the container.

